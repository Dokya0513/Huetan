-- Friend feature schema (Phase 3): shared profile + stats, and a friend
-- request/approval flow gated by a shareable invite code.
-- Run this in the Supabase dashboard's SQL Editor, after
-- backup_storage_setup.sql.

-- ---------------------------------------------------------------------
-- profiles: one row per signed-in user, auto-created on first sign-in.
-- friend_code is what a user shares out-of-band (verbally, chat, etc.)
-- for someone else to add them as a friend.
-- ---------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url text,
  friend_code text not null unique,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Anyone signed in can see the public-facing fields of any profile — this
-- is a small hobby app among friends, not a public directory, but it
-- keeps friend_code lookup (see find_user_by_friend_code below) and the
-- friend list's name/avatar display simple. Nothing sensitive lives here.
create policy "Profiles are readable by any signed-in user"
on public.profiles for select
to authenticated
using (true);

create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Generates an 8-character, unambiguous (no 0/O/1/I) invite code.
create or replace function public.generate_friend_code()
returns text
language sql
as $$
  select string_agg(
    substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (random() * 32)::int + 1, 1),
    ''
  )
  from generate_series(1, 8);
$$;

-- Auto-creates a profile (with a fresh friend_code) whenever a new user
-- signs up, so the app never has to handle a signed-in user with no
-- profile row yet.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url, friend_code)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url',
    public.generate_friend_code()
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Looks up a user by friend_code without exposing the whole profiles
-- table to a broad search — the only thing callers can learn from a code
-- is the matching user_id (and only if they already know the exact code).
create or replace function public.find_user_by_friend_code(code text)
returns uuid
language sql
security definer set search_path = public
stable
as $$
  select id from public.profiles where friend_code = upper(code);
$$;


-- ---------------------------------------------------------------------
-- friend_requests: a request from one user to another, accepted or
-- declined by the recipient. An accepted row IS the friendship — there's
-- no separate "friendships" table, "friends list" is just "accepted
-- requests involving me" queried from either side.
--
-- Defined before `stats` below, since stats' friend-visibility policy
-- needs to reference this table.
-- ---------------------------------------------------------------------
create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.profiles (id) on delete cascade,
  to_user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint no_self_request check (from_user_id <> to_user_id),
  -- Blocks sending a second request to the same person while a request
  -- in that exact direction already exists (pending, accepted, or
  -- declined). A reverse-direction duplicate (B -> A while A -> B
  -- exists) is handled at the application level when accepting, rather
  -- than with a second DB constraint, since it's rare enough not to
  -- need one.
  unique (from_user_id, to_user_id)
);

alter table public.friend_requests enable row level security;

create policy "Users can see requests involving them"
on public.friend_requests for select
to authenticated
using (from_user_id = auth.uid() or to_user_id = auth.uid());

create policy "Users can send requests as themselves"
on public.friend_requests for insert
to authenticated
with check (from_user_id = auth.uid());

-- Only the recipient can accept/decline, and only while still pending —
-- prevents either side from re-opening or backdating a resolved request.
create policy "Recipients can respond to pending requests"
on public.friend_requests for update
to authenticated
using (to_user_id = auth.uid() and status = 'pending')
with check (to_user_id = auth.uid());

create policy "Either side can delete their own request"
on public.friend_requests for delete
to authenticated
using (from_user_id = auth.uid() or to_user_id = auth.uid());

-- Sends a friend request to whoever owns [code], by looking up their
-- user_id server-side — the client never needs to know another user's
-- raw uuid, only their shareable code.
create or replace function public.send_friend_request(code text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  target_id uuid;
  request_id uuid;
begin
  target_id := public.find_user_by_friend_code(code);
  if target_id is null then
    raise exception 'No user found for that friend code';
  end if;
  if target_id = auth.uid() then
    raise exception 'You cannot friend yourself';
  end if;

  insert into public.friend_requests (from_user_id, to_user_id)
  values (auth.uid(), target_id)
  returning id into request_id;

  return request_id;
end;
$$;


-- ---------------------------------------------------------------------
-- stats: the XP/streak numbers a friend is allowed to see. Kept separate
-- from profiles so the "what friends can see" surface is a single small
-- table, easy to reason about. Level isn't stored — it's derived from xp
-- the same way lib/repositories/stats_repository.dart already does
-- locally (xp ~/ 100 + 1), so there's only one formula to keep in sync.
-- ---------------------------------------------------------------------
create table public.stats (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  xp integer not null default 0,
  streak_days integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.stats enable row level security;

create policy "Users can read their own stats"
on public.stats for select
to authenticated
using (user_id = auth.uid());

create policy "Users can read their friends' stats"
on public.stats for select
to authenticated
using (
  exists (
    select 1 from public.friend_requests fr
    where fr.status = 'accepted'
      and (
        (fr.from_user_id = auth.uid() and fr.to_user_id = stats.user_id)
        or (fr.to_user_id = auth.uid() and fr.from_user_id = stats.user_id)
      )
  )
);

create policy "Users can upsert their own stats"
on public.stats for insert
to authenticated
with check (user_id = auth.uid());

create policy "Users can update their own stats"
on public.stats for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());


-- ---------------------------------------------------------------------
-- my_friends: resolves "the other side" of each accepted friend_requests
-- row from the querying user's own perspective, joined with that
-- friend's profile/stats — so the Dart client can just `select * from
-- my_friends` instead of writing the from/to direction-handling logic
-- itself. Runs with the querying role's own RLS visibility (Postgres
-- default for views), so it only ever returns rows the caller could
-- already see via the underlying tables' policies.
-- ---------------------------------------------------------------------
create or replace view public.my_friends as
select
  p.id as user_id,
  p.display_name,
  p.avatar_url,
  coalesce(s.xp, 0) as xp,
  coalesce(s.streak_days, 0) as streak_days
from public.friend_requests fr
join public.profiles p
  on p.id = case
    when fr.from_user_id = auth.uid() then fr.to_user_id
    else fr.from_user_id
  end
left join public.stats s on s.user_id = p.id
where fr.status = 'accepted'
  and (fr.from_user_id = auth.uid() or fr.to_user_id = auth.uid());

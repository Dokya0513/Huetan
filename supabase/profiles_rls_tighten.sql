-- Tightens profiles' SELECT policy. The original "readable by any
-- signed-in user" (using (true)) let anyone with an account list every
-- profile's friend_code/display_name/avatar_url directly, which defeats
-- the point of the code being something you only share out of band —
-- friend_code lookup doesn't actually need this, since
-- find_user_by_friend_code()/send_friend_request() are already
-- security-definer functions that bypass RLS on their own.
--
-- Run this once in the SQL Editor, after friends_setup.sql and
-- friends_grants_fix.sql.

drop policy "Profiles are readable by any signed-in user" on public.profiles;

create policy "Users can read their own profile"
on public.profiles for select
to authenticated
using (id = auth.uid());

create policy "Users can read accepted friends' profiles"
on public.profiles for select
to authenticated
using (
  exists (
    select 1 from public.friend_requests fr
    where fr.status = 'accepted'
      and (
        (fr.from_user_id = auth.uid() and fr.to_user_id = profiles.id)
        or (fr.to_user_id = auth.uid() and fr.from_user_id = profiles.id)
      )
  )
);

-- Needed so the incoming-requests list can show who sent each pending
-- request, before it's been accepted.
create policy "Users can read profiles of people with a pending request to them"
on public.profiles for select
to authenticated
using (
  exists (
    select 1 from public.friend_requests fr
    where fr.status = 'pending'
      and fr.from_user_id = profiles.id
      and fr.to_user_id = auth.uid()
  )
);

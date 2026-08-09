-- Allows re-sending a friend request after it was declined. The
-- unique(from_user_id, to_user_id) constraint from friends_setup.sql
-- stays as-is (still correctly prevents duplicate pending/accepted
-- requests for the same pair) — this just teaches send_friend_request to
-- revive a previously-declined row back to 'pending' instead of failing
-- outright, since "declined by mistake, try again" is an expected real
-- usage pattern, not an edge case worth blocking.
--
-- Run this once in the SQL Editor, after friends_setup.sql.

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

  insert into public.friend_requests (from_user_id, to_user_id, status, responded_at)
  values (auth.uid(), target_id, 'pending', null)
  on conflict (from_user_id, to_user_id) do update
    set status = 'pending', created_at = now(), responded_at = null
    where friend_requests.status = 'declined'
  returning id into request_id;

  if request_id is null then
    raise exception 'A request already exists for this user';
  end if;

  return request_id;
end;
$$;

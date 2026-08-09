-- Fix: friends_setup.sql created RLS policies but never explicitly
-- GRANTed table-level API access to the `authenticated` role. RLS only
-- controls which ROWS a role can see once it's already allowed to query
-- the table at all — with "Automatically expose new tables" turned off
-- for this project, that base-level access was never granted, so every
-- query against these tables/view/functions was failing outright (not a
-- permissions-per-row issue, a "can't query this at all" issue).
-- Run this once in the SQL Editor.

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.stats to authenticated;
grant select, insert, update, delete on public.friend_requests to authenticated;
grant select on public.my_friends to authenticated;
grant execute on function public.find_user_by_friend_code(text) to authenticated;
grant execute on function public.send_friend_request(text) to authenticated;

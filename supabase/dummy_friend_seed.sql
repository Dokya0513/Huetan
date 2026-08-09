-- One-off manual test data — NOT part of the app's schema. Seeds a fake
-- pending friend request from the dummy user created via the dashboard
-- ("Authentication > Users > Add user") to dokya9777@gmail.com, so the
-- real friends UI (incoming request -> accept -> friends list with
-- XP/level/streak) can be exercised without a second real login.

update public.profiles
set display_name = 'テスト太郎'
where id = '4214a99f-96e9-4570-ab50-04a9a603f850';

insert into public.stats (user_id, xp, streak_days)
values ('4214a99f-96e9-4570-ab50-04a9a603f850', 250, 12)
on conflict (user_id) do update
  set xp = excluded.xp, streak_days = excluded.streak_days;

insert into public.friend_requests (from_user_id, to_user_id, status)
select '4214a99f-96e9-4570-ab50-04a9a603f850', id, 'pending'
from auth.users
where email = 'dokya9777@gmail.com';

-- Verify
select fr.id, fr.status, p.display_name as from_name
from public.friend_requests fr
join public.profiles p on p.id = fr.from_user_id;

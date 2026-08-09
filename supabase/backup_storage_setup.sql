-- One-time setup for cloud backup storage (Phase 1: manual backup/restore).
-- Run this in the Supabase dashboard's SQL Editor.
--
-- Each user's backup is stored at "{user_id}/backup.json" in the private
-- "backups" bucket, overwritten on every backup. RLS policies below
-- restrict every operation to the file living under the caller's own
-- auth.uid() folder, so no user can read or write another user's backup
-- even though the anon/publishable key is public.

insert into storage.buckets (id, name, public)
values ('backups', 'backups', false)
on conflict (id) do nothing;

create policy "Users can read their own backup"
on storage.objects for select
to authenticated
using (
  bucket_id = 'backups'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can upload their own backup"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'backups'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can overwrite their own backup"
on storage.objects for update
to authenticated
using (
  bucket_id = 'backups'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'backups'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete their own backup"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'backups'
  and (storage.foldername(name))[1] = auth.uid()::text
);

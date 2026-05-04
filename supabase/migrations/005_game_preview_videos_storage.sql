-- Preview videos for game detail + page section videos. Run in SQL Editor if not using CLI migrations.

alter table site_games add column if not exists preview_video_url text;

insert into storage.buckets (id, name, public, file_size_limit)
values ('game-videos', 'game-videos', true, 104857600)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

drop policy if exists "game_videos_public_read" on storage.objects;
drop policy if exists "game_videos_admin_insert" on storage.objects;
drop policy if exists "game_videos_admin_update" on storage.objects;
drop policy if exists "game_videos_admin_delete" on storage.objects;

create policy "game_videos_public_read"
on storage.objects for select
using (bucket_id = 'game-videos');

create policy "game_videos_admin_insert"
on storage.objects for insert
to authenticated
with check (bucket_id = 'game-videos' and public.is_site_admin());

create policy "game_videos_admin_update"
on storage.objects for update
to authenticated
using (bucket_id = 'game-videos' and public.is_site_admin());

create policy "game_videos_admin_delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'game-videos' and public.is_site_admin());

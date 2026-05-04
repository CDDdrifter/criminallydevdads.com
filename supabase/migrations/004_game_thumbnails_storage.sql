-- Admin-uploaded cover images for games (JPG/PNG/etc.). Run in SQL Editor if not using full schema.sql refresh.

insert into storage.buckets (id, name, public, file_size_limit)
values ('game-thumbnails', 'game-thumbnails', true, 5242880)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

drop policy if exists "game_thumbnails_public_read" on storage.objects;
drop policy if exists "game_thumbnails_admin_insert" on storage.objects;
drop policy if exists "game_thumbnails_admin_update" on storage.objects;
drop policy if exists "game_thumbnails_admin_delete" on storage.objects;

create policy "game_thumbnails_public_read"
on storage.objects for select
using (bucket_id = 'game-thumbnails');

create policy "game_thumbnails_admin_insert"
on storage.objects for insert
to authenticated
with check (bucket_id = 'game-thumbnails' and public.is_site_admin());

create policy "game_thumbnails_admin_update"
on storage.objects for update
to authenticated
using (bucket_id = 'game-thumbnails' and public.is_site_admin());

create policy "game_thumbnails_admin_delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'game-thumbnails' and public.is_site_admin());

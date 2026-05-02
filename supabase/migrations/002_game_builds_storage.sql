-- itch-style HTML5 uploads (ZIP → public Storage). Run once in Supabase SQL editor.

alter table site_games add column if not exists storage_slug text;

insert into storage.buckets (id, name, public, file_size_limit)
values ('game-builds', 'game-builds', true, 524288000)
on conflict (id) do update set public = excluded.public;

drop policy if exists "game_builds_public_read" on storage.objects;
drop policy if exists "game_builds_admin_insert" on storage.objects;
drop policy if exists "game_builds_admin_update" on storage.objects;
drop policy if exists "game_builds_admin_delete" on storage.objects;

create policy "game_builds_public_read"
on storage.objects for select
using (bucket_id = 'game-builds');

create policy "game_builds_admin_insert"
on storage.objects for insert
to authenticated
with check (bucket_id = 'game-builds' and public.is_site_admin());

create policy "game_builds_admin_update"
on storage.objects for update
to authenticated
using (bucket_id = 'game-builds' and public.is_site_admin());

create policy "game_builds_admin_delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'game-builds' and public.is_site_admin());

-- Run in Supabase SQL editor (PostgreSQL).
-- Enable Google auth in Dashboard → Authentication → Providers first.

-- Domains that may use the editor UI (matches Google Workspace / site email).
create table if not exists site_admin_domains (
  domain text primary key
);

insert into site_admin_domains (domain)
values ('criminallydevdads.com')
on conflict (domain) do nothing;

-- Optional extra allowlisted emails (personal Gmail, etc.).
create table if not exists site_admin_emails (
  email text primary key
);

-- Games catalog (replaces hand-edited games.json when populated).
create table if not exists site_games (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  type text not null default 'game',
  description text,
  details text,
  thumbnail_url text,
  preview_video_url text,
  external_url text,
  local_folder text,
  storage_slug text,
  /** Path inside the last uploaded ZIP to the playable index.html (e.g. Build/index.html); null = auto-detect. */
  storage_entry_in_zip text,
  sort_order int not null default 0,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists site_pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  body text not null default '',
  sections jsonb not null default '[]'::jsonb,
  show_in_nav boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists site_nav_items (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  href text not null,
  external boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists site_dev_logs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  body text not null default '',
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists site_settings (
  id int primary key default 1 check (id = 1),
  hero_title text,
  hero_subtitle text,
  support_title text,
  support_body text,
  support_page_href text,
  stripe_donation_url text,
  support_buttons jsonb not null default '[]'::jsonb,
  footer_text text
);

insert into site_settings (id)
values (1)
on conflict (id) do nothing;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    auth.jwt() ->> 'email' is not null
    and (
      exists (
        select 1
        from site_admin_emails e
        where lower(e.email) = lower(auth.jwt() ->> 'email')
      )
      or exists (
        select 1
        from site_admin_domains d
        where lower(d.domain) = lower(split_part(auth.jwt() ->> 'email', '@', 2))
      )
    ),
    false
  );
$$;

-- Editor UI: same rules as RLS (no drift from VITE_* env).
grant execute on function public.is_site_admin() to authenticated;

create or replace function public.can_request_editor_login(check_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    check_email is not null
    and trim(check_email) <> ''
    and (
      exists (
        select 1
        from site_admin_emails e
        where lower(e.email) = lower(trim(check_email))
      )
      or exists (
        select 1
        from site_admin_domains d
        where lower(d.domain) = lower(split_part(trim(check_email), '@', 2))
      )
    ),
    false
  );
$$;

grant execute on function public.can_request_editor_login(text) to anon, authenticated;

alter table site_games enable row level security;
alter table site_pages enable row level security;
alter table site_nav_items enable row level security;
alter table site_dev_logs enable row level security;
alter table site_settings enable row level security;
alter table site_admin_domains enable row level security;
alter table site_admin_emails enable row level security;

-- Public read published games
create policy site_games_public_read on site_games
  for select using (published = true or is_site_admin());

create policy site_games_admin_write on site_games
  for all using (is_site_admin()) with check (is_site_admin());

create policy site_pages_public_read on site_pages
  for select using (true);

create policy site_pages_admin_write on site_pages
  for all using (is_site_admin()) with check (is_site_admin());

create policy site_nav_public_read on site_nav_items
  for select using (true);

create policy site_nav_admin_write on site_nav_items
  for all using (is_site_admin()) with check (is_site_admin());

create policy site_dev_logs_public_read on site_dev_logs
  for select using (true);

create policy site_dev_logs_admin_write on site_dev_logs
  for all using (is_site_admin()) with check (is_site_admin());

create policy site_settings_public_read on site_settings
  for select using (true);

create policy site_settings_admin_write on site_settings
  for all using (is_site_admin()) with check (is_site_admin());

-- Lock down allowlist tables to admins only
create policy site_admin_domains_admin on site_admin_domains
  for all using (is_site_admin()) with check (is_site_admin());

create policy site_admin_emails_admin on site_admin_emails
  for all using (is_site_admin()) with check (is_site_admin());

-- Public bucket for HTML5 ZIP uploads (Admin → Games). Safe to re-run with DROP IF EXISTS below.
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

-- Public bucket for game cover images (Admin → Games → upload thumbnail).
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

-- Preview / page section videos (MP4 WebM MOV, up to ~100 MB).
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

-- If site_games already existed without this column:
alter table site_games add column if not exists preview_video_url text;

alter table site_games add column if not exists storage_entry_in_zip text;

alter table site_games add column if not exists sections jsonb not null default '[]'::jsonb;
alter table site_games add column if not exists visual_preset text;
alter table site_games add column if not exists price_cents int;
alter table site_games add column if not exists purchase_url text;
alter table site_games add column if not exists stripe_price_id text;
alter table site_settings add column if not exists support_page_href text;
alter table site_settings add column if not exists stripe_donation_url text;
alter table site_settings add column if not exists support_buttons jsonb not null default '[]'::jsonb;

-- Commerce (Stripe Checkout via Edge Function). See docs/STRIPE_CHECKOUT.md.
-- VITE_SUPABASE_URL (GitHub) is NOT the same as Edge secret SITE_URL (public hub for redirects).
alter table site_games add column if not exists pricing_model text not null default 'free';
alter table site_games add column if not exists pwyw_min_cents int;
alter table site_games add column if not exists pwyw_suggested_cents int;
alter table site_games add column if not exists donation_presets_cents jsonb not null default '[]'::jsonb;

update site_games
set pricing_model = 'fixed'
where coalesce(price_cents, 0) > 0
  and pricing_model = 'free';

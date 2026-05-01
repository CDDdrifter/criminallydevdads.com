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
  external_url text,
  local_folder text,
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

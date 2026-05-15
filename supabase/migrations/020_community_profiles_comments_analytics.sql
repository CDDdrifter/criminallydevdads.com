-- Public players: profiles, comments, cloud game saves, first-party analytics.
-- Run after 019. Enable Google provider in Supabase → Authentication → Providers.

-- ---------------------------------------------------------------------------
-- Profiles (auto-created on sign-up via trigger)
-- ---------------------------------------------------------------------------
create table if not exists site_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_site_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.site_profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, 'player'), '@', 1)
    ),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture', '')
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    avatar_url = excluded.avatar_url,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_site_profile on auth.users;
create trigger on_auth_user_created_site_profile
  after insert on auth.users
  for each row execute function public.handle_new_site_profile();

-- Backfill profiles for existing auth users (safe to re-run).
insert into public.site_profiles (id, display_name, avatar_url)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', split_part(coalesce(u.email, 'player'), '@', 1)),
  coalesce(u.raw_user_meta_data ->> 'avatar_url', u.raw_user_meta_data ->> 'picture', '')
from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Comments (games, CMS pages, dev logs)
-- ---------------------------------------------------------------------------
create table if not exists site_comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  target_type text not null check (target_type in ('game', 'page', 'devlog')),
  target_key text not null,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists site_comments_target_idx
  on site_comments (target_type, target_key, created_at desc);

-- ---------------------------------------------------------------------------
-- Per-user game save blobs (JSON) — sync across devices when signed in
-- ---------------------------------------------------------------------------
create table if not exists site_game_saves (
  user_id uuid not null references auth.users (id) on delete cascade,
  game_slug text not null,
  save_data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, game_slug)
);

create index if not exists site_game_saves_slug_idx on site_game_saves (game_slug);

-- ---------------------------------------------------------------------------
-- First-party analytics (page views, game plays, sign-ins)
-- ---------------------------------------------------------------------------
create table if not exists site_analytics_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (
    event_type in ('page_view', 'game_play', 'sign_in', 'comment_post', 'app_open')
  ),
  path text not null default '',
  target_key text not null default '',
  session_id text not null default '',
  user_id uuid references auth.users (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists site_analytics_events_created_idx
  on site_analytics_events (created_at desc);

create index if not exists site_analytics_events_type_created_idx
  on site_analytics_events (event_type, created_at desc);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table site_profiles enable row level security;
alter table site_comments enable row level security;
alter table site_game_saves enable row level security;
alter table site_analytics_events enable row level security;

drop policy if exists site_profiles_public_read on site_profiles;
create policy site_profiles_public_read on site_profiles
  for select using (true);

drop policy if exists site_profiles_self_update on site_profiles;
create policy site_profiles_self_update on site_profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists site_profiles_self_insert on site_profiles;
create policy site_profiles_self_insert on site_profiles
  for insert with check (auth.uid() = id);

drop policy if exists site_comments_public_read on site_comments;
create policy site_comments_public_read on site_comments
  for select using (true);

drop policy if exists site_comments_auth_insert on site_comments;
create policy site_comments_auth_insert on site_comments
  for insert with check (auth.uid() = user_id);

drop policy if exists site_comments_auth_update on site_comments;
create policy site_comments_auth_update on site_comments
  for update using (auth.uid() = user_id or is_site_admin())
  with check (auth.uid() = user_id or is_site_admin());

drop policy if exists site_comments_auth_delete on site_comments;
create policy site_comments_auth_delete on site_comments
  for delete using (auth.uid() = user_id or is_site_admin());

drop policy if exists site_game_saves_owner on site_game_saves;
create policy site_game_saves_owner on site_game_saves
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists site_analytics_insert on site_analytics_events;
create policy site_analytics_insert on site_analytics_events
  for insert with check (true);

drop policy if exists site_analytics_admin_read on site_analytics_events;
create policy site_analytics_admin_read on site_analytics_events
  for select using (is_site_admin());

-- ---------------------------------------------------------------------------
-- Admin analytics summary (Studio dashboard)
-- ---------------------------------------------------------------------------
create or replace function public.get_site_analytics_summary(days_back int default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(days_back, 30), 365)));
  result jsonb;
begin
  if not is_site_admin() then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'since', since,
    'days_back', greatest(1, least(coalesce(days_back, 30), 365)),
    'total_events', (select count(*)::int from site_analytics_events where created_at >= since),
    'page_views', (select count(*)::int from site_analytics_events where created_at >= since and event_type = 'page_view'),
    'game_plays', (select count(*)::int from site_analytics_events where created_at >= since and event_type = 'game_play'),
    'sign_ins', (select count(*)::int from site_analytics_events where created_at >= since and event_type = 'sign_in'),
    'unique_sessions', (select count(distinct session_id)::int from site_analytics_events where created_at >= since and session_id <> ''),
    'signed_in_users', (select count(distinct user_id)::int from site_analytics_events where created_at >= since and user_id is not null),
    'comments_posted', (select count(*)::int from site_comments where created_at >= since),
    'registered_profiles', (select count(*)::int from site_profiles),
    'top_paths', coalesce((
      select jsonb_agg(row_to_json(t)::jsonb)
      from (
        select path, count(*)::int as views
        from site_analytics_events
        where created_at >= since and event_type = 'page_view' and path <> ''
        group by path
        order by views desc
        limit 15
      ) t
    ), '[]'::jsonb),
    'top_games', coalesce((
      select jsonb_agg(row_to_json(t)::jsonb)
      from (
        select target_key as game_slug, count(*)::int as plays
        from site_analytics_events
        where created_at >= since and event_type = 'game_play' and target_key <> ''
        group by target_key
        order by plays desc
        limit 15
      ) t
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

grant execute on function public.get_site_analytics_summary(int) to authenticated;

grant insert on table public.site_analytics_events to anon, authenticated;
grant select on table public.site_profiles to anon, authenticated;
grant insert, update on table public.site_profiles to authenticated;
grant select on table public.site_comments to anon, authenticated;
grant insert, update, delete on table public.site_comments to authenticated;
grant select, insert, update, delete on table public.site_game_saves to authenticated;

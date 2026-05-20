-- Admin comment/profile lists + per-game analytics in summary RPC.
-- Run after 021. No new secrets.

create or replace function public.admin_list_comments(
  p_limit integer default 200,
  days_back integer default 365
)
returns table (
  id uuid,
  user_id uuid,
  target_type text,
  target_key text,
  body text,
  created_at timestamptz,
  display_name text,
  username text,
  author_email text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(days_back, 365), 3650)));
  lim integer := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if not is_site_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    c.id,
    c.user_id,
    c.target_type::text,
    c.target_key,
    c.body,
    c.created_at,
    coalesce(p.display_name, 'Player') as display_name,
    coalesce(p.username, '') as username,
    coalesce(u.email::text, '') as author_email
  from site_comments c
  left join site_profiles p on p.id = c.user_id
  left join auth.users u on u.id = c.user_id
  where c.created_at >= since
  order by c.created_at desc
  limit lim;
end;
$$;

grant execute on function public.admin_list_comments(integer, integer) to authenticated;

create or replace function public.admin_list_recent_profiles(p_limit integer default 200)
returns table (
  id uuid,
  email text,
  display_name text,
  username text,
  mailing_list_opt_in boolean,
  mailing_list_opted_in_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  lim integer := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if not is_site_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    p.id,
    coalesce(u.email::text, '') as email,
    p.display_name,
    p.username,
    p.mailing_list_opt_in,
    p.mailing_list_opted_in_at,
    p.created_at
  from site_profiles p
  left join auth.users u on u.id = p.id
  order by p.created_at desc
  limit lim;
end;
$$;

grant execute on function public.admin_list_recent_profiles(integer) to authenticated;

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
    'events_by_type', coalesce((
      select jsonb_object_agg(event_type, cnt)
      from (
        select event_type, count(*)::int as cnt
        from site_analytics_events
        where created_at >= since
        group by event_type
      ) et
    ), '{}'::jsonb),
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
    ), '[]'::jsonb),
    'top_app_opens', coalesce((
      select jsonb_agg(row_to_json(t)::jsonb)
      from (
        select
          coalesce(nullif(trim(target_key), ''), nullif(trim(path), ''), '(unknown)') as app_key,
          count(*)::int as opens
        from site_analytics_events
        where created_at >= since and event_type = 'app_open'
        group by 1
        order by opens desc
        limit 15
      ) t
    ), '[]'::jsonb),
    'game_analytics', coalesce((
      select jsonb_agg(row_to_json(t)::jsonb order by t.plays desc nulls last)
      from (
        select
          g.slug as game_slug,
          g.title as game_title,
          coalesce((
            select count(*)::int
            from site_analytics_events e
            where e.created_at >= since and e.event_type = 'game_play' and e.target_key = g.slug
          ), 0) as plays,
          coalesce((
            select count(*)::int
            from site_analytics_events e
            where e.created_at >= since
              and e.event_type = 'page_view'
              and (e.path like '%/game/' || g.slug || '%' or e.path like '%/play/' || g.slug || '%')
          ), 0) as page_views,
          coalesce((
            select count(*)::int
            from site_comments c
            where c.created_at >= since and c.target_type = 'game' and c.target_key = g.slug
          ), 0) as comments,
          coalesce((
            select count(distinct e.session_id)::int
            from site_analytics_events e
            where e.created_at >= since and e.event_type = 'game_play' and e.target_key = g.slug and e.session_id <> ''
          ), 0) as unique_sessions
        from site_games g
        where g.published = true
      ) t
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

grant execute on function public.get_site_analytics_summary(int) to authenticated;

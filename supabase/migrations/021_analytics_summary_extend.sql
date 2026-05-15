-- Extend admin analytics summary: per-event-type counts + top HTML app opens.
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
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

grant execute on function public.get_site_analytics_summary(int) to authenticated;

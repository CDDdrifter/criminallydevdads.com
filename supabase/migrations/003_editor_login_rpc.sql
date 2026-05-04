-- Editor UI calls these so client admin state matches RLS (site_admin_domains / site_admin_emails).

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

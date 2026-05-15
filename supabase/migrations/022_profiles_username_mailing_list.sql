-- Unique public usernames + mailing-list opt-in on profiles.
-- After 021. Deploy Edge Function `mailing-broadcast` and set Resend secrets (see function README).

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------
alter table public.site_profiles
  add column if not exists username text,
  add column if not exists mailing_list_opt_in boolean not null default false,
  add column if not exists mailing_list_opted_in_at timestamptz;

-- Stable handle: 3–32 chars, lowercase letter first, then [a-z0-9_].
alter table public.site_profiles
  drop constraint if exists site_profiles_username_format;

alter table public.site_profiles
  add constraint site_profiles_username_format check (
    username is null
    or (
      char_length(username) between 3 and 32
      and username ~ '^[a-z][a-z0-9_]{2,31}$'
    )
  );

-- Case-insensitive uniqueness (NULL allowed only during legacy backfill; then NOT NULL).
create unique index if not exists site_profiles_username_lower_uidx
  on public.site_profiles (lower(username))
  where username is not null and trim(username) <> '';

-- ---------------------------------------------------------------------------
-- Username generation (new signups + backfill)
-- ---------------------------------------------------------------------------
create or replace function public.generate_site_username(p_user_id uuid, p_email text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  local_part text;
  base text;
begin
  local_part := split_part(coalesce(nullif(trim(lower(p_email)), ''), 'player@local'), '@', 1);
  base := trim(both '_' from regexp_replace(local_part, '[^a-z0-9]+', '_', 'g'));
  if base is null or base = '' then
    base := 'player';
  end if;
  if base !~ '^[a-z]' then
    base := 'u' || base;
  end if;
  base := left(base, 20);
  if char_length(base) < 3 then
    base := rpad(base, 3, 'x');
  end if;
  return left(base || '_' || substr(replace(p_user_id::text, '-', ''), 1, 10), 32);
end;
$$;

-- ---------------------------------------------------------------------------
-- Auth trigger: assign username on first profile row
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_site_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uname text;
begin
  uname := public.generate_site_username(new.id, new.email);

  insert into public.site_profiles (id, display_name, avatar_url, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, 'player'), '@', 1)
    ),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture', ''),
    uname
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    avatar_url = excluded.avatar_url,
    updated_at = now();
  -- Do not overwrite username on conflict so manual picks survive OAuth refresh.
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Backfill existing rows
-- ---------------------------------------------------------------------------
update public.site_profiles p
set username = public.generate_site_username(p.id, u.email)
from auth.users u
where p.id = u.id
  and (p.username is null or trim(p.username) = '');

alter table public.site_profiles
  alter column username set not null;

alter table public.site_profiles drop constraint if exists site_profiles_username_format;

alter table public.site_profiles
  add constraint site_profiles_username_format check (
    char_length(username) between 3 and 32
    and username ~ '^[a-z][a-z0-9_]{2,31}$'
  );

-- Client insert path if trigger row is missing (race): same shape as generate_site_username.
create or replace function public.bootstrap_my_username()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  e text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  select u.email into e from auth.users u where u.id = auth.uid();
  return public.generate_site_username(auth.uid(), coalesce(e, ''));
end;
$$;

grant execute on function public.bootstrap_my_username() to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: username availability (for account form)
-- ---------------------------------------------------------------------------
create or replace function public.is_username_available(p_username text, p_for_user_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(trim(p_username), '') <> ''
    and char_length(trim(p_username)) between 3 and 32
    and trim(lower(p_username)) ~ '^[a-z][a-z0-9_]{2,31}$'
    and not exists (
      select 1
      from public.site_profiles s
      where lower(s.username) = lower(trim(p_username))
        and (p_for_user_id is null or s.id <> p_for_user_id)
    );
$$;

grant execute on function public.is_username_available(text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: admin mailing list (uses auth.users via security definer)
-- ---------------------------------------------------------------------------
create or replace function public.admin_mailing_list_count()
returns integer
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (select public.is_site_admin()) then
    raise exception 'not authorized';
  end if;
  return (
    select count(*)::int
    from public.site_profiles p
    where p.mailing_list_opt_in = true
  );
end;
$$;

grant execute on function public.admin_mailing_list_count() to authenticated;

create or replace function public.admin_mailing_list_preview(p_limit integer default 80)
returns table (
  email text,
  display_name text,
  username text,
  opted_in_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (select public.is_site_admin()) then
    raise exception 'not authorized';
  end if;
  return query
  select
    u.email::text as email,
    p.display_name::text,
    p.username::text,
    p.mailing_list_opted_in_at
  from public.site_profiles p
  join auth.users u on u.id = p.id
  where p.mailing_list_opt_in = true
  order by p.mailing_list_opted_in_at desc nulls last, p.created_at desc
  limit least(coalesce(p_limit, 80), 200);
end;
$$;

grant execute on function public.admin_mailing_list_preview(integer) to authenticated;

-- Service role only: full recipient list for Edge Function sends (never grant to anon/authenticated).
create or replace function public.admin_mailing_recipients(p_limit integer default 20000)
returns table (email text)
language sql
security definer
set search_path = public
as $$
  select u.email::text
  from public.site_profiles p
  join auth.users u on u.id = p.id
  where p.mailing_list_opt_in = true
    and u.email is not null
    and trim(u.email) <> ''
  order by p.mailing_list_opted_in_at desc nulls last
  limit least(coalesce(p_limit, 20000), 20000);
$$;

revoke all on function public.admin_mailing_recipients(integer) from public;
grant execute on function public.admin_mailing_recipients(integer) to service_role;

comment on column public.site_profiles.username is 'Unique public handle (lowercase a-z, digits, underscore; 3–32 chars).';
comment on column public.site_profiles.mailing_list_opt_in is 'User opted in to site owner emails.';
comment on column public.site_profiles.mailing_list_opted_in_at is 'When the user last opted in; cleared when opting out.';

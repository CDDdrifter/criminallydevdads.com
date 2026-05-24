-- Sellable services & gigs (Fiverr-style): demos, builds, tips, merch, commissions.
-- Stripe via extended create-checkout-session (service_slug). Run after 009/015.

create table if not exists public.site_services (
  slug text primary key,
  title text not null,
  tagline text not null default '',
  description text not null default '',
  category text not null default 'other',
  kind text not null default 'service',
  icon_emoji text not null default '✨',
  image_url text not null default '',
  features jsonb not null default '[]'::jsonb,
  deliverables text not null default '',
  turnaround text not null default '',
  pricing_model text not null default 'quote',
  price_cents int,
  stripe_price_id text,
  purchase_url text,
  gumroad_url text,
  pwyw_min_cents int,
  pwyw_suggested_cents int,
  donation_presets_cents jsonb not null default '[]'::jsonb,
  cta_label text not null default 'Get started',
  request_only boolean not null default false,
  request_form_enabled boolean not null default true,
  published boolean not null default true,
  show_on_services_hub boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists site_services_hub_idx
  on public.site_services (published, show_on_services_hub, sort_order);

alter table public.site_services enable row level security;

drop policy if exists site_services_public_read on public.site_services;
create policy site_services_public_read on public.site_services
  for select using (published = true);

drop policy if exists site_services_admin_all on public.site_services;
create policy site_services_admin_all on public.site_services
  for all to authenticated
  using (is_site_admin())
  with check (is_site_admin());

-- Customer inquiries (email / brief) — stored for admin follow-up.
create table if not exists public.site_service_requests (
  id uuid primary key default gen_random_uuid(),
  service_slug text references public.site_services (slug) on delete set null,
  contact_name text not null default '',
  contact_email text not null,
  message text not null,
  budget_note text not null default '',
  user_id uuid references auth.users (id) on delete set null,
  status text not null default 'new',
  created_at timestamptz not null default now()
);

create index if not exists site_service_requests_created_idx
  on public.site_service_requests (created_at desc);

alter table public.site_service_requests enable row level security;

drop policy if exists site_service_requests_public_insert on public.site_service_requests;
create policy site_service_requests_public_insert on public.site_service_requests
  for insert to anon, authenticated
  with check (
    length(trim(contact_email)) >= 5
    and position('@' in trim(contact_email)) > 1
    and length(trim(message)) >= 10
  );

drop policy if exists site_service_requests_admin_read on public.site_service_requests;
create policy site_service_requests_admin_read on public.site_service_requests
  for select to authenticated
  using (is_site_admin());

drop policy if exists site_service_requests_admin_update on public.site_service_requests;
create policy site_service_requests_admin_update on public.site_service_requests
  for update to authenticated
  using (is_site_admin())
  with check (is_site_admin());

grant select on table public.site_services to anon, authenticated;
grant insert, update, delete on table public.site_services to authenticated;
grant insert on table public.site_service_requests to anon, authenticated;
grant select, update on table public.site_service_requests to authenticated;

-- Admin inbox
create or replace function public.admin_list_service_requests(p_limit integer default 100)
returns table (
  id uuid,
  service_slug text,
  service_title text,
  contact_name text,
  contact_email text,
  message text,
  budget_note text,
  status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  lim integer := greatest(1, least(coalesce(p_limit, 100), 500));
begin
  if not is_site_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    r.id,
    r.service_slug,
    coalesce(s.title, '') as service_title,
    r.contact_name,
    r.contact_email,
    r.message,
    r.budget_note,
    r.status,
    r.created_at
  from site_service_requests r
  left join site_services s on s.slug = r.service_slug
  order by r.created_at desc
  limit lim;
end;
$$;

grant execute on function public.admin_list_service_requests(integer) to authenticated;

-- Starter catalog (edit in Admin → Services)
insert into public.site_services (
  slug, title, tagline, description, category, kind, icon_emoji,
  features, deliverables, turnaround, pricing_model, price_cents,
  pwyw_min_cents, pwyw_suggested_cents, donation_presets_cents,
  cta_label, request_only, request_form_enabled, sort_order
) values
(
  'buy-me-a-coffee',
  'Buy me a coffee',
  'Quick support — thank you!',
  'One-time tip to fuel late-night Godot sessions and server costs. Pick an amount or enter your own.',
  'support', 'tip', '☕',
  '["Instant Stripe checkout","Receipt by email","Helps keep games free to try"]'::jsonb,
  'Our gratitude + good vibes',
  'Instant',
  'donation', null, 50, null, '[300,500,1000,2000]'::jsonb,
  'Send a tip', false, false, 10
),
(
  'custom-tip',
  'Custom tip',
  'Choose any amount (USD)',
  'Pay what you want — for support, shout-outs, or just because.',
  'support', 'tip', '💝',
  '["You pick the amount","Min $0.50 USD"]'::jsonb,
  'Thank-you',
  'Instant',
  'pwyw', null, 50, 500, '[]'::jsonb,
  'Pay custom amount', false, false, 20
),
(
  'game-demo-prototype',
  'Game demo / prototype',
  'Playable vertical slice in Godot (web export)',
  'We scope a small playable demo: core loop, one level, basic UI. Perfect before full production.',
  'game_dev', 'service', '🎮',
  '["Godot 4 web build","1–2 week typical scope","You own the source after delivery"]'::jsonb,
  'Playable web build + source handoff',
  '1–3 weeks (scope dependent)',
  'quote', null, null, null, '[]'::jsonb,
  'Request a quote', true, true, 30
),
(
  'full-game-production',
  'Full game production',
  'From concept to shipped web/desktop build',
  'End-to-end game dev: design, art direction, implementation, polish, and deploy to this hub or stores.',
  'game_dev', 'service', '🏆',
  '["Godot or web stack","Milestones + playtests","Store / itch ready"]'::jsonb,
  'Milestone builds + final deliverables',
  'Project-based',
  'quote', null, null, null, '[]'::jsonb,
  'Start a project', true, true, 40
),
(
  'asset-commission',
  'Custom assets & art pack',
  'Sprites, UI, tiles, audio direction',
  'Commission art or asset packs sized for your game — consistent style with your brand.',
  'asset', 'service', '🎨',
  '["Sprites / UI / tiles","Source files where applicable","Hub-ready uploads"]'::jsonb,
  'Asset files + usage notes',
  '3–14 days typical',
  'quote', null, null, null, '[]'::jsonb,
  'Commission assets', true, true, 50
),
(
  'website-creation',
  'Website creation',
  'Marketing sites, hubs, and landing pages',
  'Fast, distinctive sites — like this hub — with CMS, auth, games, and Stripe when you are ready.',
  'web', 'service', '🌐',
  '["React + Supabase option","GitHub Pages deploy","SEO + analytics hooks"]'::jsonb,
  'Deployed site + repo access',
  '2–8 weeks',
  'quote', null, null, null, '[]'::jsonb,
  'Build my site', true, true, 60
),
(
  'app-creation',
  'App & tool creation',
  'HTML apps, internal tools, sandboxes',
  'Interactive tools and mini-apps hosted on the Apps lab or embedded in your stack.',
  'app', 'service', '⚡',
  '["Sandboxed HTML apps","Admin CMS blocks","Optional Supabase backend"]'::jsonb,
  'Hosted app + handoff',
  '1–6 weeks',
  'quote', null, null, null, '[]'::jsonb,
  'Build an app', true, true, 70
),
(
  'merch',
  'Merch & physical goods',
  'Shirts, stickers, prints (external fulfillment)',
  'Link your Printful / Gumroad / Stripe product — we surface it here with your copy.',
  'merch', 'product', '👕',
  '["External checkout","You control fulfillment"]'::jsonb,
  'Per your store',
  'Ships from your provider',
  'fixed', null, null, null, '[]'::jsonb,
  'Shop merch', false, false, 80
)
on conflict (slug) do nothing;

comment on table public.site_services is 'Sellable gigs/services — tips, demos, builds, merch (Admin → Services).';
comment on table public.site_service_requests is 'Inbound project requests from /#/services forms.';

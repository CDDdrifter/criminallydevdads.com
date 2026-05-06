-- Per-game pricing: fixed, pay-what-you-want, donation (Stripe Checkout via Edge Function).
alter table site_games add column if not exists pricing_model text not null default 'free';
alter table site_games add column if not exists pwyw_min_cents int;
alter table site_games add column if not exists pwyw_suggested_cents int;
alter table site_games add column if not exists donation_presets_cents jsonb not null default '[]'::jsonb;

update site_games
set pricing_model = 'fixed'
where coalesce(price_cents, 0) > 0
  and pricing_model = 'free';

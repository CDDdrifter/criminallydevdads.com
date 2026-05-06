-- Per-game pricing for built-in Stripe Checkout (create-checkout-session Edge Function).
-- pricing_model: free | fixed | pwyw | donation (enforced in app + Edge; no DB CHECK for easier rollbacks).
-- Backfill: rows that already had price_cents > 0 from commerce migration 008 become 'fixed'.
-- See docs/STRIPE_CHECKOUT.md and docs/SUPABASE_COPY_THESE_TWO_VALUES.md (Supabase dashboard URL layout).
alter table site_games add column if not exists pricing_model text not null default 'free';
alter table site_games add column if not exists pwyw_min_cents int;
alter table site_games add column if not exists pwyw_suggested_cents int;
alter table site_games add column if not exists donation_presets_cents jsonb not null default '[]'::jsonb;

update site_games
set pricing_model = 'fixed'
where coalesce(price_cents, 0) > 0
  and pricing_model = 'free';

-- Stripe-ready commerce fields + admin-managed support buttons.
alter table site_games add column if not exists price_cents int;
alter table site_games add column if not exists purchase_url text;
alter table site_games add column if not exists stripe_price_id text;

alter table site_settings add column if not exists support_page_href text;
alter table site_settings add column if not exists stripe_donation_url text;
alter table site_settings add column if not exists support_buttons jsonb not null default '[]'::jsonb;

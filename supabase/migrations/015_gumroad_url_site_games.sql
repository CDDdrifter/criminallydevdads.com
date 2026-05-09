-- Buy / download on Gumroad (separate from generic purchase_url + future Stripe Checkout).
alter table site_games add column if not exists gumroad_url text;

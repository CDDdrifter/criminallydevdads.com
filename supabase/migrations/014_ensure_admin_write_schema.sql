-- Safety net: all columns the SPA admin may write. Idempotent — run in SQL Editor if saves fail
-- with "column does not exist" after partial migrations.

-- site_pages
alter table site_pages add column if not exists sections jsonb not null default '[]'::jsonb;
alter table site_pages add column if not exists visual_preset text;
alter table site_pages add column if not exists immersive_layout boolean not null default false;
alter table site_pages add column if not exists custom_mood_css text not null default '';

-- site_games
alter table site_games add column if not exists storage_slug text;
alter table site_games add column if not exists preview_video_url text;
alter table site_games add column if not exists storage_entry_in_zip text;
alter table site_games add column if not exists sections jsonb not null default '[]'::jsonb;
alter table site_games add column if not exists visual_preset text;
alter table site_games add column if not exists price_cents int;
alter table site_games add column if not exists purchase_url text;
alter table site_games add column if not exists stripe_price_id text;
alter table site_games add column if not exists pricing_model text not null default 'free';
alter table site_games add column if not exists pwyw_min_cents int;
alter table site_games add column if not exists pwyw_suggested_cents int;
alter table site_games add column if not exists donation_presets_cents jsonb not null default '[]'::jsonb;
alter table site_games add column if not exists in_vault boolean not null default false;
alter table site_games add column if not exists immersive_layout boolean not null default false;
alter table site_games add column if not exists custom_mood_css text not null default '';

-- site_settings
alter table site_settings add column if not exists support_page_href text;
alter table site_settings add column if not exists stripe_donation_url text;
alter table site_settings add column if not exists support_buttons jsonb not null default '[]'::jsonb;
alter table site_settings add column if not exists site_visual_preset text;
alter table site_settings add column if not exists fx_scanlines boolean not null default true;
alter table site_settings add column if not exists fx_noise boolean not null default true;
alter table site_settings add column if not exists fx_vignette boolean not null default true;
alter table site_settings add column if not exists fx_hue_shift boolean not null default true;
alter table site_settings add column if not exists fx_cursor_spotlight boolean not null default true;
alter table site_settings add column if not exists promo_events jsonb not null default '[]'::jsonb;
alter table site_settings add column if not exists custom_css text not null default '';
alter table site_settings add column if not exists fx_intensity text not null default 'normal';

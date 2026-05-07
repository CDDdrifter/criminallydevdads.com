-- Site-wide visual FX (matches src/index.css layers + html[data-visual-preset]).
-- Per-game mood still uses site_games.visual_preset on /game/:slug only.
alter table site_settings add column if not exists site_visual_preset text;
alter table site_settings add column if not exists fx_scanlines boolean not null default true;
alter table site_settings add column if not exists fx_noise boolean not null default true;
alter table site_settings add column if not exists fx_vignette boolean not null default true;
alter table site_settings add column if not exists fx_hue_shift boolean not null default true;
alter table site_settings add column if not exists fx_cursor_spotlight boolean not null default true;

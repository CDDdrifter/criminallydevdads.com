-- Per-CMS-page visual mood (same keys as site_games.visual_preset / site_settings.site_visual_preset).
alter table site_pages add column if not exists visual_preset text;

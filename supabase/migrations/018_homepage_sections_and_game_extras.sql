-- ---------------------------------------------------------------------------
-- Migration 018 — admin-driven homepage + game-page enrichment.
--
-- 1. site_settings.homepage_sections (JSONB array of PageSection blocks)
-- 2. site_settings.homepage_layout_mode ('append' | 'prepend' | 'replace')
-- 3. site_games gains per-game metadata columns so the game detail page can
--    render rich panels (tags, release date, platforms, screenshots, key
--    features, controls, credits, version changelog, system requirements).
--
-- All columns are additive with defaults so the upgrade is non-breaking.
-- The frontend uses column-tolerant saves (`unknownColumnFromPostgrestMessage`)
-- so dropping any one of them mid-rollout still works.
-- ---------------------------------------------------------------------------

-- Homepage layout -----------------------------------------------------------
alter table site_settings
  add column if not exists homepage_sections jsonb not null default '[]'::jsonb;

alter table site_settings
  add column if not exists homepage_layout_mode text not null default 'append';

-- Game-page enrichment ------------------------------------------------------
alter table site_games
  add column if not exists tags jsonb not null default '[]'::jsonb;

alter table site_games
  add column if not exists release_date text not null default '';

alter table site_games
  add column if not exists platforms jsonb not null default '[]'::jsonb;

alter table site_games
  add column if not exists screenshots jsonb not null default '[]'::jsonb;

alter table site_games
  add column if not exists features jsonb not null default '[]'::jsonb;

alter table site_games
  add column if not exists controls jsonb not null default '[]'::jsonb;

alter table site_games
  add column if not exists credits jsonb not null default '[]'::jsonb;

alter table site_games
  add column if not exists changelog jsonb not null default '[]'::jsonb;

alter table site_games
  add column if not exists system_requirements jsonb not null default '[]'::jsonb;

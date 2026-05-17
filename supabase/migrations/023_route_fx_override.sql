-- Per-game / per-page FX overrides (inherit | on | off per layer).
-- Requires migration 014+ (site_games / site_pages).

alter table site_games add column if not exists route_fx jsonb not null default '{}'::jsonb;
alter table site_pages add column if not exists route_fx jsonb not null default '{}'::jsonb;

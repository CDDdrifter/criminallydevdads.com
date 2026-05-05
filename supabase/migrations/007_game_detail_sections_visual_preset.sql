-- Rich game detail page (blocks under embed) + optional global visual preset per game.
alter table site_games add column if not exists sections jsonb not null default '[]'::jsonb;
alter table site_games add column if not exists visual_preset text;

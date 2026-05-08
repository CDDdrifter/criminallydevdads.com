-- Vault catalog: games listable at /#/vault without being on the main hub (published may be false).
-- Immersive layout + per-route CSS for a distinct look vs the main hub.
alter table site_games add column if not exists in_vault boolean not null default false;
alter table site_games add column if not exists immersive_layout boolean not null default false;
alter table site_games add column if not exists custom_mood_css text not null default '';

alter table site_pages add column if not exists immersive_layout boolean not null default false;
alter table site_pages add column if not exists custom_mood_css text not null default '';

-- Public may read hub games (published) OR vault-listed games (share link / vault page). Drafts: both false.
drop policy if exists site_games_public_read on site_games;
create policy site_games_public_read on site_games
  for select using (
    published = true
    or coalesce(in_vault, false) = true
    or is_site_admin()
  );

-- ===========================================================================
-- 017_admin_studio_expansion.sql
-- ---------------------------------------------------------------------------
-- Second wave of Admin Studio knobs. Adds ten more JSONB columns on
-- `site_settings` so admins can repaint / re-tune *almost everything* the
-- site does at runtime.
--
-- These map to nested config objects in `src/types.ts`. Defaults come from
-- `src/lib/themeDefaults.ts`. Every column is additive and tolerant — the
-- save path in `cmsData.saveSiteSettings()` strips unknown columns on retry
-- so the front end keeps working even if this migration is run later.
-- ===========================================================================

-- Animation library + per-element assignments (entrance, hover, transitions).
alter table site_settings add column if not exists animations jsonb not null default '{}'::jsonb;

-- Background music, hover sound, ambient loop, master volume + mute.
alter table site_settings add column if not exists audio jsonb not null default '{}'::jsonb;

-- Custom cursor — image / emoji / reticle, trail, click ripple.
alter table site_settings add column if not exists cursor jsonb not null default '{}'::jsonb;

-- Floating particle layer — stars / snow / sparks / matrix / fireflies.
alter table site_settings add column if not exists particles jsonb not null default '{}'::jsonb;

-- Social links bar (header / footer toggle, icon style, list of links).
alter table site_settings add column if not exists social jsonb not null default '{}'::jsonb;

-- Hero section knobs — logo image, CTA buttons, badges, scroll indicator.
alter table site_settings add column if not exists hero jsonb not null default '{}'::jsonb;

-- Game card display options — what to show, ribbons, NEW badge window.
alter table site_settings add column if not exists game_cards jsonb not null default '{}'::jsonb;

-- Brand info — site name, logo, copyright template, watermark.
alter table site_settings add column if not exists branding jsonb not null default '{}'::jsonb;

-- Performance + a11y opt-outs — global animation off, backdrop-filter off.
alter table site_settings add column if not exists performance jsonb not null default '{}'::jsonb;

-- Accessibility — focus ring, font scale, dyslexia font, high contrast.
alter table site_settings add column if not exists accessibility jsonb not null default '{}'::jsonb;

-- Share button block per game (twitter / reddit / copy link).
alter table site_settings add column if not exists sharing jsonb not null default '{}'::jsonb;

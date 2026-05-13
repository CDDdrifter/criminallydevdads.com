-- ============================================================================
-- 016_admin_overhaul.sql
-- ----------------------------------------------------------------------------
-- Adds the "Studio" admin layer: rich theme, effects, typography, layout,
-- components, behavior and SEO configuration is now persisted in JSONB columns
-- on `site_settings`. All columns are nullable / default to an empty JSON
-- object so this migration is fully additive and safe to run multiple times.
--
-- The frontend (`src/lib/themeApply.ts`) and admin Studio tabs read these
-- columns through `cmsData.fetchSiteSettings()` and write them back via
-- `cmsData.saveSiteSettings()`. The save path uses a column-tolerant retry
-- loop, so the site keeps working even when this migration hasn't been run
-- yet — it just hides the new admin controls until the columns exist.
-- ============================================================================

-- --------------------------------------------------------------------------
-- Theme configuration (colors, gradients, body background).
-- See `ThemeConfig` in `src/types.ts` and `themeDefaults.ts` for the shape.
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists theme jsonb not null default '{}'::jsonb;

-- --------------------------------------------------------------------------
-- Fine-grained effects config (opacity, color, speed for each FX layer).
-- Coarse on/off lives in legacy `fx_*` boolean columns from migration 010.
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists effects jsonb not null default '{}'::jsonb;

-- --------------------------------------------------------------------------
-- Typography: fonts, sizes, weights, spacing, link styling.
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists typography jsonb not null default '{}'::jsonb;

-- --------------------------------------------------------------------------
-- Layout: container width, paddings, card grid, header / nav / footer.
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists layout jsonb not null default '{}'::jsonb;

-- --------------------------------------------------------------------------
-- Component styling: buttons, cards, panels, modals.
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists components jsonb not null default '{}'::jsonb;

-- --------------------------------------------------------------------------
-- Behavior: feature flags, maintenance mode, default filters, hover effects.
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists behavior jsonb not null default '{}'::jsonb;

-- --------------------------------------------------------------------------
-- SEO + analytics: title template, OG image, favicon, analytics provider.
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists seo jsonb not null default '{}'::jsonb;

-- --------------------------------------------------------------------------
-- Custom HTML head snippet (advanced — trusted admin content).
-- Injected into <head> by SiteThemeApply (after the Vite bundle attaches).
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists custom_head_html text not null default '';

-- --------------------------------------------------------------------------
-- User-saved theme presets so admins can A/B between palettes.
-- Shape: [{ id, name, description, theme: ThemeConfig }, ...]
-- Built-in presets ship in `src/lib/themePresets.ts`; user presets append.
-- --------------------------------------------------------------------------
alter table site_settings
  add column if not exists theme_presets jsonb not null default '[]'::jsonb;

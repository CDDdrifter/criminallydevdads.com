-- Editable built-in pages + rich dev-log posts.
--
-- 1. site_settings.prebuilt_pages: per-route (services/vault/apps/devlog)
--    editable eyebrow/heading/subtitle + intro/outro PageSection block zones.
-- 2. site_dev_logs.sections: rich block content (same engine as CMS pages),
--    rendered instead of the legacy plain-text body when present.

ALTER TABLE public.site_settings
  ADD COLUMN IF NOT EXISTS prebuilt_pages jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.site_settings.prebuilt_pages IS
  'Per-route header + block zones for built-in pages: { services|vault|apps|devlog: {eyebrow,heading,subtitle,intro_sections[],outro_sections[]} }.';

ALTER TABLE public.site_dev_logs
  ADD COLUMN IF NOT EXISTS sections jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.site_dev_logs.sections IS
  'Ordered PageSection blocks; rendered in place of the plain-text body when non-empty.';

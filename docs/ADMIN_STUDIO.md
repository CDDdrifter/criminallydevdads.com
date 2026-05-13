# Admin Studio

The **Studio** layer of the admin page (`#/admin`) lets editors repaint and
re-tune almost every visible aspect of the site without redeploying. It
ships with migration **016** (`supabase/migrations/016_admin_overhaul.sql`)
and adds these tabs alongside the original CMS tabs:

| Tab          | Edits…                                                            |
|--------------|-------------------------------------------------------------------|
| Theme        | Every colour token, body gradient, radial accent, background image, header glow. Includes 14 built-in palette presets (Synthwave, Cyberpunk, Matrix, Paper light-mode, etc.) and per-team saved presets. |
| Effects      | Scanlines, noise, vignette, hue-shift wash, cursor spotlight, title glitch, card-in animation, card-hover lift / glow / shine, edge sweep, scroll jitter, reduced-motion honouring, custom CSS appended after the generated rules. |
| Typography   | Font families (preset stacks **or** any Google Fonts URL), heading + body sizes, weights, letter-spacing, link-underline behaviour, heading text-shadow. |
| Layout       | Container max-width, paddings, border-radii, card grid (min width / forced columns / gap / thumbnail height), header padding + alignment, top-nav alignment + gap + sticky mode, footer alignment + padding. |
| Components   | Card shadows + padding, button paddings + font size + text-transform + hover translate, panel blur + border width, modal backdrop blur + color + max width, promo card flags. |
| Behavior     | Maintenance mode (with admin bypass), show / hide for Vault / Dev log / filter buttons / support section / footer / admin nav link, default filter, card hover effect, hover-autoplay previews, click-sound URL + volume, optional HTML banner above the hero. |
| SEO + Head   | Title template, default meta description, OG image, Twitter handle, favicon, browser theme colour, analytics provider (Plausible / Umami / GA4 / custom), and a free-form `<head>` HTML block. |

## How it works

`SiteSettings` carries seven JSONB columns added in migration 016:

```
theme, effects, typography, layout, components, behavior, seo
```

(plus `custom_head_html` and `theme_presets`).

- **`lib/themeDefaults.ts`** is the canonical source of defaults for every
  field. Studio tabs hold edits in React state and pass them to
  `cmsData.saveSiteSettings()` which merges them onto the row.
- **`lib/themeApply.ts`** converts the settings into:
  - CSS custom properties on `<html style="…">` (e.g. `--accent`,
    `--card-bg-a`)
  - a generated stylesheet (`<style id="site-studio-css">`) emitting
    gradient backgrounds, FX opacities, layout sizes, hover variants and
    typography overrides
  - side-effect tags: a Google Fonts `<link>`, an analytics `<script>`, a
    `<head>` HTML wrapper, a favicon `<link>` and a `theme-color` meta.
- **`components/SiteThemeApply.tsx`** runs the applier on every settings
  change, so the studio previews live as the admin types.
- **`components/MaintenanceGate.tsx`** renders a maintenance card for non-
  admin visitors when `behavior.maintenance_mode.enabled` is true.

## Saving

Each Studio tab shares the same sticky **Save studio settings** button at
the bottom of the panel. Saving calls `saveSiteSettings(settings)` which is
*column-tolerant*: if migration 016 hasn't been run yet, unknown columns
are silently dropped and the rest of the row still saves, so upgrading
without breakage is just:

```bash
# In Supabase SQL Editor:
# Paste supabase/migrations/016_admin_overhaul.sql and Run.
```

The schema.sql also includes the same `add column if not exists` lines for
fresh setups.

## Permission model

All columns live on `site_settings` which is protected by the existing
`site_settings_admin_write` RLS policy — only allow-listed admins can
write. Public reads stay open so the front end can still render the theme
for unauthenticated visitors.

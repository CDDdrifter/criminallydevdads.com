# CMS snapshots (optional static bundle)

After you run **Admin → Overview → Push pages/layout snapshot** (or **Push everything**), this folder is populated in Git with JSON exports from Supabase:

- `site-settings.json`
- `site-pages.json`
- `site-nav.json`
- `site-devlogs.json`
- `site-content.snapshot.json` (combined)

The production build copies `cms/` → `dist/cms/`. The site loads these files **first** when present, so hero text, pages, and nav appear with the initial paint instead of “popping in” after Supabase responds.

If this folder is empty, the site falls back to live Supabase reads (when configured).

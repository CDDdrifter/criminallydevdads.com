# CMS snapshots (`cms/*.json`)

These JSON files ship with GitHub Pages (`scripts/copy-cms.mjs` copies `cms/` → `dist/cms/`). The live site reads them on first paint.

| File | What it is |
|------|------------|
| `site-settings.json` | Theme, hero, footer, studio settings |
| `site-pages.json` | Custom pages (`/p/<slug>`) |
| `site-nav.json` | Extra header links |
| `site-devlogs.json` | Dev log posts |
| `admin-config.json` | Who can open `/admin` (`admin_emails` / `admin_domains`) |
| `firebase-config.json` | Google sign-in keys (public web config) |

**Edit from Admin:** sign in at `/admin`, change Pages / studio, then **Overview → Push pages/layout snapshot** (needs GitHub token). That commits these files to `main`.

**Edit on GitHub:** open the file → pencil → commit to `main` → wait for deploy.

**Add an admin:** put the exact Google email in `admin-config.json` `admin_emails`, commit, wait for Pages.

Day-to-day: [`docs/HOW_TO_UPDATE.md`](../docs/HOW_TO_UPDATE.md).

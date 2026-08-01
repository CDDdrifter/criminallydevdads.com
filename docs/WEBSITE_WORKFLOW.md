# How to actually run and change this website

**Full step-by-step guide:** **[`NO_SUPABASE_SETUP.md`](NO_SUPABASE_SETUP.md)** — games, Firebase auth, admin, pages, URLs.

Supabase is **no longer required**. Everything runs from files in GitHub.

---

## Path A — Edit in the repo (recommended)

### Games on the hub

1. Open **`games.json`**. Each entry needs **`id`**, **`title`**, **`type`**, **`description`**.
2. Put the web build under **`games/<id>/`** (e.g. `games/fortfury/index.html`).
3. Commit and push. GitHub Actions deploys to Pages.

For large games, set **`url`** in JSON to an external host (itch.io, etc.) — see **`NO_SUPABASE_SETUP.md`**.

### Site settings, pages, nav

Edit JSON files in **`cms/`** directly, or use **`/admin`** (Google sign-in + GitHub token).

### Deploy

- GitHub: **Settings → Pages → Source: GitHub Actions**
- Add **Firebase** secrets — see **`NO_SUPABASE_SETUP.md` Part 2**

---

## Path B — Browser admin

1. Set up Firebase (Google sign-in)
2. Add your email to **`cms/admin-config.json`**
3. Open **`/admin`** → sign in → enter GitHub PAT in **System** tab
4. Edits save to JSON files in the repo via GitHub API

---

## Quick reference

| Goal | How |
|------|-----|
| Add / change games | Edit **`games.json`** + **`games/<slug>/`** |
| Change hero, theme, footer | **`cms/site-settings.json`** or **`/admin`** |
| Add a CMS page | **`cms/site-pages.json`** or **`/admin`** → Pages |
| Google sign-in | Firebase — **`NO_SUPABASE_SETUP.md` Part 2** |
| Real URLs (not `#/`) | Already enabled — use `/game/slug`, `/admin`, etc. |

See **`docs/SITE_MANUAL.md`** for additional detail on game exports and GitHub size limits.

# How to actually run and change this website

**Full step-by-step (games, pages, nav, GitHub size limits):** **[`SITE_MANUAL.md`](SITE_MANUAL.md)**

There are **two valid ways** to work. You do **not** need Supabase to ship games or edit the site. Supabase is **optional** for a browser-based admin later.

---

## Path A — Edit in the repo (works today, no cloud setup)

Use this if you are tired of dashboards, secrets, and SQL. Everything is files in Git.

### Games on the hub

1. Open **`games.json`**. Each entry needs at least an **`id`** (slug), **`title`**, **`type`** (`game` or `asset`), **`description`**, and usually **`filename`** (zip name) or a playable folder.
2. Put the **web build** for each game under **`games/<id>/`** (e.g. `games/fortfury/index.html` plus Godot export files).
3. Commit and push. Your **GitHub Pages** deploy (or local `npm run build`) copies `games/` and `games.json` into **`dist/`**.

**Default catalog behavior:** The site uses **`VITE_GAME_CATALOG=auto`** (default). If Supabase is configured but **`site_games` is empty** or unreachable, the hub **falls back to `games.json`**. So unfinished Supabase setup does **not** wipe your games list anymore.

To **never** read the database for games (100% files):

```env
VITE_GAME_CATALOG=legacy
```

### Look, layout, and React “components”

- **Global styles:** `src/index.css`
- **Pages / screens:** `src/pages/*.tsx`
- **Shared UI:** `src/components/*.tsx`
- **Routing:** `src/App.tsx`

Edit like any React project; run **`npm run dev`** locally, then push.

### Deploy without Supabase

- In GitHub: **Settings → Pages → Source: GitHub Actions** (use the repo workflow).
- You **do not** have to add `VITE_SUPABASE_*` secrets. If those secrets are missing, the build still works: **legacy catalog + file-based games**.

---

## Path B — Browser admin (optional, later)

Use this when you want non-programmers to add games or ZIPs **without** touching Git.

1. Create a Supabase project and run **`supabase/schema.sql`** once.
2. Configure auth and redirect URLs (see **`docs/SUPABASE_FIRST_TIME_SETUP.md`**).
3. Add GitHub Actions secrets **`VITE_SUPABASE_URL`** and **`VITE_SUPABASE_ANON_KEY`**.
4. Allowlist emails in **`site_admin_domains`** / **`site_admin_emails`**.
5. Open **`/#/admin`** → **Team login**.

When the database has **published** rows in **`site_games`**, **`auto`** mode will **prefer that catalog** over `games.json`. If you have fully moved to the cloud and want **only** the database (no file fallback):

```env
VITE_GAME_CATALOG=cms
```

---

## Quick reference

| Goal | Path A (repo) | Path B (admin) |
|------|----------------|----------------|
| Add / change games on the hub | Edit **`games.json`**, add files under **`games/<slug>/`** | Supabase + **`/#/admin`** |
| Change hero, footer, support text | Defaults in code / types; or DB **`site_settings`** if Supabase on | **`/#/admin`** → Settings |
| Change layout / components | Edit **`src/**/*.tsx`**, **`src/index.css`** | Same — admin does not replace React layout |
| Deploy | Push branch; Actions build | Same, with secrets set |

---

## What went wrong before (plain language)

- The site was built so that **as soon as** Supabase env vars were present, the **only** game list was the **database**. If the DB was empty or login was not finished, you saw **no games** and **could not edit** anything useful.
- **Fix:** **`auto`** mode (default) uses the database **only when it actually has games**; otherwise it keeps using **`games.json`**.

---

## One-line “make it work” checklist (Path A only)

1. Clone repo → `npm ci` → `npm run dev` → confirm games appear.
2. Edit **`games.json`** and **`games/<slug>/`** as needed.
3. Push to the branch that deploys Pages; **omit** Supabase secrets if you do not want cloud admin yet.

That is enough to **manipulate the website and add games** from code and files, with no Supabase required.

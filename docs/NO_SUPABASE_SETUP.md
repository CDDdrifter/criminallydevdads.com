# Criminally Dev Dads — Site guide (no Supabase)

This site runs entirely from **files in GitHub** — no cloud database, no game storage bills. Games live in `games.json` and the `games/` folder. Google sign-in uses **Firebase Auth** (free tier). Admin saves go to GitHub via a Personal Access Token.

---

## Quick start checklist

1. Clone the repo → `npm ci` → `npm run dev` → open `http://localhost:5173`
2. Games appear from `games.json` + `games/<slug>/` automatically
3. Set up Firebase (below) for Google sign-in and `/admin`
4. Push to `main` — GitHub Actions deploys to Pages

---

## Part 1 — Adding a game (step by step)

### Option A: Game files in the repo (recommended for smaller builds)

1. **Export your game as HTML5** (Godot: Project → Export → Web)
2. **Create a folder** named after your game slug:
   ```
   games/my-game-slug/
     index.html
     index.js
     index.wasm
     index.pck
     … (other export files)
   ```
3. **Add an entry to `games.json`** at the repo root:

```json
{
  "id": "my-game-slug",
  "title": "My Game Title",
  "type": "game",
  "description": "One-line description shown on the hub card.",
  "details": "Longer description on the game detail page.",
  "thumbnail": "https://example.com/thumbnail.png",
  "filename": "my-game-slug.zip"
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Yes | URL slug — used in `/game/my-game-slug` and `/play/my-game-slug` |
| `title` | Yes | Display name |
| `type` | Yes | `"game"` or `"asset"` |
| `description` | Yes | Short card text |
| `details` | No | Longer text on detail page |
| `thumbnail` | No | Image URL, or auto-detected from `games/<id>/index.png` |
| `filename` | No | Legacy zip name; helps slug fallback |
| `url` | No | External play URL (see Option B) |
| `purchase_url` | No | Stripe/Gumroad/itch purchase link |
| `visual_preset` | No | Theme preset id (`ember`, `aurora`, etc.) |

4. **Commit and push.** The deploy copies `games/` and `games.json` into the live site.

5. **Verify:** open `/game/my-game-slug` (detail) and `/play/my-game-slug` (play).

### Option B: Host the build elsewhere (large games)

GitHub limits repo size (~25 MB per file, discourages huge repos). For big Godot WASM exports:

1. Upload your HTML5 build to **itch.io**, **Netlify Drop**, or **Cloudflare Pages**
2. In `games.json`, set `url` to the **https** link of the playable page:

```json
{
  "id": "my-big-game",
  "title": "My Big Game",
  "type": "game",
  "description": "Hosted externally — no giant repo upload.",
  "url": "https://myname.itch.io/my-big-game"
}
```

You do **not** need a `games/my-big-game/` folder when `url` is set.

---

## Part 2 — Firebase setup (Google sign-in)

**Simple step-by-step:** see **[`FIREBASE_SETUP.md`](FIREBASE_SETUP.md)** (start here).

Summary:
- **Any Google account** can sign in to play
- **Admins:** `@criminallydevdads.com` or emails in `cms/admin-config.json`
- Copy 4 Firebase values into `.env.local` and GitHub Actions secrets

### GitHub token (required to save changes)

Admin saves write JSON files to GitHub. You need a **Personal Access Token**:

1. GitHub → Settings → Developer settings → Personal access tokens → **Tokens (classic)**
2. Generate new token → check **`repo`** scope
3. Open `/admin` → sign in with Google → **System** tab → paste token under **GitHub sync**

The token is stored in your browser session only (not in the repo or build).

### What admin can edit

| Tab | Saves to |
|-----|----------|
| Games | `games.json` |
| Settings / Theme / etc. | `cms/site-settings.json` |
| Pages | `cms/site-pages.json` |
| Nav | `cms/site-nav.json` |
| Dev logs | `cms/site-devlogs.json` |

After each save, GitHub Actions redeploys the site (usually within 2–3 minutes).

---

## Part 4 — Real page URLs (no more `#/`)

The site now uses **real URLs**:

| Old (hash) | New (path) |
|------------|------------|
| `/#/` | `/` |
| `/#/game/terracraft` | `/game/terracraft` |
| `/#/play/terracraft` | `/play/terracraft` |
| `/#/admin` | `/admin` |
| `/#/p/support` | `/p/support` |
| `/#/devlog` | `/devlog` |
| `/#/vault` | `/vault` |
| `/#/services` | `/services` |

GitHub Pages serves `404.html` (= `index.html`) for unknown paths, so refresh and direct links work.

---

## Part 5 — Adding a new page

### CMS page (no code)

1. `/admin` → **Pages** tab → create a page with slug e.g. `about-us`
2. Public URL: `/p/about-us`
3. Optionally check **Show in nav**

### React page (custom code)

1. Create `src/pages/AboutPage.tsx`
2. Add route in `src/App.tsx`:
   ```tsx
   <Route path="/about" element={<AboutPage />} />
   ```
3. Add nav link in `src/components/SiteChrome.tsx` or via CMS nav

---

## Part 6 — Stripe (optional)

Stripe dynamic checkout previously used Supabase Edge Functions. Without Supabase:

- **Payment Links** still work — set `purchase_url` or `stripe_donation_url` in game JSON or site settings
- **Built-in checkout** (`GamePurchaseBlock`) requires a backend — use external Payment Links for now

See `docs/STRIPE_SETUP.md` for Payment Link setup.

---

## Part 7 — What changed from Supabase

| Feature | Before (Supabase) | Now |
|---------|-------------------|-----|
| Game hosting | Supabase Storage | `games/` folder or external `url` |
| Game catalog | `site_games` table | `games.json` |
| Google sign-in | Supabase Auth | Firebase Auth |
| Admin saves | Supabase DB | GitHub API → JSON files |
| Cloud saves | Postgres | Browser localStorage |
| Comments | Postgres | Disabled (no backend) |
| URLs | `/#/game/...` | `/game/...` |

---

## Troubleshooting

**Games don't show on hub**
- Check `games.json` syntax (valid JSON array)
- Each entry needs `id`, `title`, `type`, `description`
- Run `npm run dev` locally to test

**Game detail/play page is empty**
- Confirm `id` in JSON matches folder name under `games/`
- Or set `url` for external hosting

**Google sign-in fails**
- Check Firebase authorized domains include your live domain
- Confirm `VITE_FIREBASE_*` secrets are set in GitHub Actions
- Hard-refresh after redeploy

**Admin save fails**
- Enter GitHub PAT in Admin → System → GitHub sync
- Token needs `repo` scope on the correct repository

**Old `/#/` links**
- Still work briefly via browser history, but update bookmarks to path URLs

---

## File reference

```
games.json              ← game catalog (titles, descriptions, URLs)
games/<slug>/           ← HTML5 game builds
cms/site-settings.json  ← hero, theme, behavior, footer
cms/site-pages.json     ← CMS pages at /p/:slug
cms/site-nav.json       ← navigation links
cms/site-devlogs.json   ← dev log posts
cms/admin-config.json   ← who can access /admin
src/App.tsx             ← route definitions
src/pages/              ← page components
docs/NO_SUPABASE_SETUP.md ← this file
```

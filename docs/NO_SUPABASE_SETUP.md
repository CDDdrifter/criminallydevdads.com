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

## Part 2 — Admin setup (Google sign-in + GitHub saves)

**Simple Firebase Auth guide:** [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) — only needed for `/admin` sign-in (not for storing games).

### GitHub token (required to save from `/admin`)

Admin saves write **JSON files in this repo** via the GitHub API. You need a **Personal Access Token**:

1. GitHub → Settings → Developer settings → Personal access tokens → **Tokens (classic)**
2. Generate new token → check **`repo`** scope
3. Open `/admin` → sign in with Google → **System** tab → paste token under **GitHub sync**

The token stays in your browser session only (not in the repo).

### What admin can edit (all saves → repo JSON → auto deploy)

| Tab | Saves to | Live after |
|-----|----------|------------|
| Games (metadata) | `games.json` | ~2–3 min (GitHub Actions) |
| Site copy / Theme / Layout / Effects | `cms/site-settings.json` | ~2–3 min |
| Pages (blocks, images, layouts) | `cms/site-pages.json` | ~2–3 min |
| Nav | `cms/site-nav.json` | ~2–3 min |
| Dev logs | `cms/site-devlogs.json` | ~2–3 min |

**Game files** (`games/<slug>/`) **can** be uploaded from Admin → Games (ZIP) if you pasted a GitHub PAT in System. You can also add them with git, or host externally and set `url` in JSON.

See **[`HOW_TO_UPDATE.md`](HOW_TO_UPDATE.md)** for the full playbook.

**Images:** use image URLs in page blocks and game thumbnails, or upload via Admin (uses Firebase Storage — optional). External URLs (imgur, itch, your CDN) work without Storage.

After each admin save, wait for **Deploy to GitHub Pages** (Actions tab) to finish, then hard-refresh the site.

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

## Part 7 — Architecture (Firebase + GitHub)

| Feature | Backend |
|---------|---------|
| Game hosting | `games/` folder or external `url` |
| Game catalog | `games.json` |
| Google sign-in | Firebase Auth |
| Admin CMS (settings, pages, nav, devlogs, services) | Firebase Firestore |
| Branding uploads (thumbnails, videos) | Firebase Storage |
| Cloud saves, comments, profiles, analytics | Firebase Firestore |
| Stripe checkout (built-in) | Payment Links until Cloud Functions |
| URLs | `/game/...` (real paths, not hash) |

Full Firebase setup: [`FIREBASE_MIGRATION.md`](FIREBASE_MIGRATION.md)

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

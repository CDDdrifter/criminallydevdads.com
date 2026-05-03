# Site manual — add games, pages, and links without guesswork

This hub is a **React (Vite)** app. You can ship it **without Supabase**. Supabase only adds a browser admin (`/#/admin`); it is optional.

---

## Table of contents

1. [Why GitHub “won’t take” your game](#1-why-github-wont-take-your-game)
2. [Add a game (recommended: host big files elsewhere)](#2-add-a-game-recommended-host-big-files-elsewhere)
3. [Add a game (small build inside the repo)](#3-add-a-game-small-build-inside-the-repo)
4. [Add a game (push large files with Git on your computer)](#4-add-a-game-push-large-files-with-git-on-your-computer)
5. [How `games.json` fields work](#5-how-gamesjson-fields-work)
6. [Add a new page (React route)](#6-add-a-new-page-react-route)
7. [Add a “custom” page from the database (optional)](#7-add-a-custom-page-from-the-database-optional)
8. [Add a header link (extension to the nav)](#8-add-a-header-link-extension-to-the-nav)
9. [Troubleshooting](#9-troubleshooting)
10. [Fullscreen while playing](#10-fullscreen-while-playing)
11. [Admin / “Team login” in the header](#11-admin--team-login-in-the-header)

---

## 1. Why GitHub “won’t take” your game

| Limit | What it means |
|--------|----------------|
| **Website upload ~25 MB** | Uploading files in the **browser** on github.com is capped. Big Godot HTML5 exports often exceed this. |
| **Single file ~100 MB** | `git push` **rejects** any blob larger than 100 MB unless you use **Git LFS** (extra setup). |
| **Huge folders** | Even if each file is small, a massive export is painful in Git. Prefer hosting the **playable URL** elsewhere. |

**Practical rule:** big Web build → put **`url`** in `games.json` (itch.io, Netlify Drop, etc.). Tiny demo → optional folder under `games/<slug>/`.

---

## 2. Add a game (recommended: host big files elsewhere)

You only commit **text** (`games.json`). The **binary** lives on a host that allows large static sites.

### Step A — Export HTML5 from Godot (or your engine)

- Export for **Web**, get a folder with **`index.html`** plus `.wasm`, `.pck`/`.js`, etc.

### Step B — Upload that folder somewhere public

**Option 1 — itch.io (common for indies)**  
1. Create/upload your project on itch.io.  
2. Upload the **HTML5** zip or files so the game **runs in the browser**.  
3. Open the game page; use the URL that actually loads the game in an iframe or full page (often the page you get from “Embed” / “Run game” in browser).  
4. Copy the **https://…** URL.

**Option 2 — Netlify Drop**  
1. Go to [Netlify Drop](https://app.netlify.com/drop) (or similar).  
2. Drag the **folder** containing `index.html`.  
3. Netlify gives you a URL like `https://random-name.netlify.app/` — that is your **`url`**.

**Option 3 — Any static host**  
Cloudflare Pages, your own server, S3+CloudFront, etc. The **`url`** must work in a browser and ideally in an **iframe** (some hosts send headers that block iframes; if Play shows a blank frame, try another host or itch).

### Step C — Edit `games.json` in this repo

Add or update an object (see **`docs/games.json.example`**):

- **`id`** — required stable slug: `fort-fury`, `my-game` (used in `/#/play/fort-fury`).  
- **`title`**, **`type`** (`game` or `asset`), **`description`**, **`details`**, **`thumbnail`** (https image URL is fine).  
- **`url`** **or** **`external_url`** — the **https** playable page from step B.

Commit and push. After deploy, the card should show **Play Now** and the iframe should load your host.

You **do not** need a `games/<id>/` folder in Git for that entry.

---

## 3. Add a game (small build inside the repo)

Use this only when the total size is small enough for Git and GitHub.

1. Create **`games/<same-id-as-in-json>/`** (example: `games/terracraft/`).  
2. Put **`index.html`** and all export files inside that folder.  
3. In **`games.json`**, set **`id`** to that folder name (and metadata).  
4. You may omit **`url`**; the hub will try `games/<id>/index.html` on your live site.

**Deploy note:** `npm run build` runs `scripts/copy-games.mjs`, which copies **`games/`** and **`games.json`** into **`dist/`**. Whatever is **committed** in the repo is what ships (for local folders).

---

## 4. Add a game (push large files with Git on your computer)

If the build is **under 100 MB per file** but too big for the GitHub **web** UI:

1. Install [Git](https://git-scm.com/) and clone your repo.  
2. Copy files into `games/<slug>/`.  
3. In a terminal at the repo root:

```bash
git add games/<slug> games.json
git commit -m "Add web build for <slug>"
git push
```

If Git says a file exceeds **100 MB**, you must either shrink the build, split assets, use **Git LFS**, or use **section 2** (`url` host) instead.

---

## 5. How `games.json` fields work

| Field | Required | Purpose |
|--------|----------|---------|
| **`id`** | Strongly recommended | Slug in URLs; should match folder name if you use `games/<id>/`. |
| **`slug`** | No | Alias for `id` if you prefer that name. |
| **`title`** | Recommended | Shown on cards. |
| **`type`** | Recommended | `game` or `asset` (filters on home). |
| **`description`** | Recommended | Short text on card. |
| **`details`** | Optional | Longer copy for the “Info” modal. |
| **`thumbnail`** | Optional | Image URL or path resolved like other static assets. |
| **`filename`** | Optional | Legacy; used to guess `id` from `something.zip` if `id` missing. |
| **`url`** or **`external_url`** | Optional | If set, **play** opens this https URL (host your big build here). |

**Derived id:** If you forget `id` but set **`url`** and **`title`**, the code derives a slug from the title (see `deriveId` in `src/lib/legacyGames.ts`). Prefer setting **`id`** yourself to avoid surprises.

**Discovery:** The live site also lists **folders** under `games/` via the **GitHub API** (`VITE_GITHUB_REPO_OWNER`, `VITE_GITHUB_REPO_NAME`). If that API fails (wrong repo name, rate limit), you still get every row from **`games.json`**; folder-only games might not appear until the API works or you add a matching `games.json` row with **`url`**.

---

## 6. Add a new page (React route)

**Files involved:** `src/App.tsx`, new file under `src/pages/`.

1. Copy `src/pages/DevLogListPage.tsx` (or another simple page) to `src/pages/MyPage.tsx`.  
2. Change the component name and the JSX content.  
3. In **`src/App.tsx`**, import your page and add:

```tsx
<Route path="/my-page" element={<MyPage />} />
```

4. Link to it: `/#/my-page` from anywhere (`<Link to="/my-page">`).

Layout chrome: wrap content with **`<SiteChrome>`** like other pages if you want the header.

---

## 7. Add a “custom” page from the database (optional)

If Supabase is set up and you use **`/#/admin`** → **Pages**, you can create a page with slug `about` and open **`/#/p/about`**. That uses **`StaticPage`** and CMS content — no new React file.

Code path: `src/pages/StaticPage.tsx`, data from `src/lib/cmsData.ts`.

---

## 8. Add a header link (“extension” to the nav)

**Without Supabase:** edit **`src/components/SiteChrome.tsx`**, array **`coreNav`**, add `{ label: 'My link', href: '/my-page', external: false }`.

**With Supabase:** Admin → **Navigation** (or pages flagged **show in nav**).

---

## 9. Troubleshooting

| Problem | What to check |
|---------|----------------|
| Card shows **Setup Needed** | No reachable `index.html` under `games/<slug>/` and no **`url`** in `games.json`. Add **`url`** or fix the folder + deploy. |
| Blank iframe | Host may block embedding. Try itch embed URL or a host that allows iframes. |
| Game missing on live site | **`id`** in JSON must be unique; run build so `games.json` is in `dist/`; check GitHub API env vars if you rely on folder discovery only. |
| **25 MB** upload error on github.com | Use **Git** on your PC or use **`url`** hosting (section 2). |

### Code map (commented)

| Area | File |
|------|------|
| Game list (files + JSON) | `src/lib/legacyGames.ts` |
| CMS vs file catalog switch | `src/lib/gameCatalog.ts`, `src/hooks/useGames.ts` |
| Play iframe + fullscreen | `src/pages/PlayPage.tsx`, `src/components/GamePlayerEmbed.tsx` |
| Asset URLs / base path | `src/lib/paths.ts` |
| Routes | `src/App.tsx` |
| Top nav | `src/components/SiteChrome.tsx` |
| Optional: show admin link in nav | `src/lib/envPublic.ts` (`VITE_SHOW_ADMIN_NAV`) |

---

## 10. Fullscreen while playing

On **`/#/play/<slug>`**, each game shows a **Fullscreen** control at the **bottom-right** of the player frame.

- The site requests fullscreen on the **player wrapper** (the area around the iframe). That works for **every** game URL (your `games/` folder or an external `url`), including cross-origin embeds where the game’s own fullscreen API is not available to the parent page.
- Use **Exit fullscreen** (same button) or the browser’s usual escape / F11 behavior to leave.
- Some mobile browsers limit fullscreen; the button hides if the browser reports no fullscreen support.

---

## 11. Admin / “Team login” in the header

By default the **top nav does not show** “Team login” or “Admin”, so visitors don’t see operator links.

- **Open the admin UI anytime:** go to **`/#/admin`** (bookmark it).
- **Show the link in the header** (local or CI build): set  
  **`VITE_SHOW_ADMIN_NAV=true`**  
  in `.env.local` or add it as a variable to your GitHub Actions workflow `env` next to the other `VITE_*` keys.

Supabase setup for signing in is still described in **`docs/SUPABASE_FIRST_TIME_SETUP.md`**.

---

## Quick copy: itch.io + `games.json`

```json
{
  "id": "my-game",
  "title": "My Game",
  "type": "game",
  "description": "One-line pitch.",
  "details": "Longer description for the Info button.",
  "thumbnail": "https://your-cdn.com/cover.png",
  "url": "https://YOUR-ITCH-USER.itch.io/my-game"
}
```

Replace the `url` with the exact page that runs your HTML5 build in the browser.

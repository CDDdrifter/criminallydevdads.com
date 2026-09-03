# How to actually run and change this website

**Start here:** **[`HOW_TO_UPDATE.md`](HOW_TO_UPDATE.md)** — add games, replace builds, add pages, GitHub token, Pages deploy.

Supabase is **not required**. Games are files in GitHub. Google sign-in is Firebase.

---

## Path A — Edit in the repo (always works)

### Games on the hub

1. Open **`games.json`**. Each entry needs **`id`**, **`title`**, **`type`**, **`description`**.
2. Put the web build under **`games/<id>/`** (e.g. `games/fortfury/index.html`), **or** set **`url`** to itch.io / Netlify.
3. Commit and push **`main`**. GitHub Actions deploys to Pages.

Large `.wasm` / `.pck` files use Git LFS (see `.gitattributes`). Prefer Admin ZIP or `git lfs` from your PC rather than the GitHub website upload for those.

### Site settings, pages, nav

Edit JSON in **`cms/`**, or use **`/admin`**.

### Deploy

- GitHub: **Settings → Pages → Source: GitHub Actions**
- Firebase keys live in **`cms/firebase-config.json`** — [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md)

---

## Path B — Browser admin

1. Sign in at **https://criminallydevdads.com/admin** with Google (allowlisted email — [`ADMIN_LOGIN_ONE_PAGE.md`](ADMIN_LOGIN_ONE_PAGE.md))
2. **System** → paste a GitHub PAT with **`repo`** (needed for game ZIPs)
3. **Games** / **Pages** / studio tabs → Save
4. Wait for **Actions → Deploy to GitHub Pages**, then hard-refresh

---

## Quick reference

| Goal | How |
|------|-----|
| Add / change a playable build | Admin → Games ZIP, or `games/<slug>/` + push |
| Change hero, theme, footer | `/admin` studio tabs, then Push `cms/` snapshot |
| Add a CMS page | `/admin` → Pages → `/p/your-slug` |
| Google sign-in | [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) |
| Real URLs | `/game/slug`, `/play/slug`, `/admin`, `/p/slug` |

See **`docs/SITE_MANUAL.md`** for GitHub size limits and itch.io `url` hosting.

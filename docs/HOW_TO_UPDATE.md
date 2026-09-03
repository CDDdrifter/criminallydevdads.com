# How you update this site yourself

You do **not** need Cursor or anyone else after this is set up once.

There are two ways to change the live site. Both end the same way: a commit lands on **`main`**, GitHub Actions builds, GitHub Pages goes live in a few minutes.

| Job | Use this |
|-----|----------|
| Add / update a **playable HTML5 build** | **Admin → Games** (ZIP) **or** Git: replace files under `games/<slug>/` |
| Title, description, cover, itch URL | **Admin → Games** (save) **or** edit `games.json` on GitHub |
| New **content page** (`/p/about`) | **Admin → Pages** |
| Header links | **Admin → Navigation** |
| Theme, hero, footer | **Admin** studio tabs, then **Save** |
| Custom coded route (`/my-page`) | Git: add a file in `src/pages/` + a route in `src/App.tsx` |

Live site: **https://criminallydevdads.com**  
Admin: **https://criminallydevdads.com/admin**  
Repo: **https://github.com/CDDdrifter/criminallydevdads.com**  
Deploys: **https://github.com/CDDdrifter/criminallydevdads.com/actions**

---

## One-time setup (do this once)

### 1. GitHub Pages is already wired

Repo → **Settings → Pages → Build and deployment → Source: GitHub Actions**.

Pushes to **`main`** run **Deploy to GitHub Pages**. Wait for the green check, then hard-refresh (**Ctrl+Shift+R**).

### 2. Who can open `/admin`

Sign in with **Google**. Admin is allowed if:

- the Google email ends in **`@criminallydevdads.com`**, or
- the email is listed in **`cms/admin-config.json`** → `admin_emails`

To add a Gmail (or any other address): on GitHub, edit `cms/admin-config.json`:

```json
{
  "admin_emails": ["you@gmail.com"],
  "admin_domains": ["criminallydevdads.com"]
}
```

Commit on **`main`**, wait for deploy, then sign in at `/admin`.

Firebase Google sign-in is already in **`cms/firebase-config.json`**. Full click-through: [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md).

### 3. GitHub token (needed to put game files in the repo from the browser)

HTML5 builds live in this GitHub repo under `games/<slug>/`. The admin ZIP uploader writes those files with **your** token.

1. GitHub (your account) → **Settings** → **Developer settings** → **Personal access tokens**
2. **Tokens (classic)** → **Generate new token (classic)**
3. Note: `cdd-site-admin` · Expiration: your choice · Scope: check **`repo`**
4. Generate → **copy the token once** (`ghp_…`)
5. Open **https://criminallydevdads.com/admin** → **System** tab → paste under **GitHub sync** → leave branch **`main`**

The token stays in **this browser** (not in the repo). If you clear site data, paste it again.

Fine-grained token instead: this repo only, **Contents: Read and write**. Classic `repo` is simpler.

---

## Add a new game (Admin)

1. Export **Web / HTML5** from Godot (or your engine). Zip the **whole folder** that contains `index.html`.
2. `/admin` → **Games**
3. **Title** (required). Slug is built from the title unless you type one (`my-game`).
4. Under **HTML5 build**, choose that `.zip`. Keep the tab open until it finishes.
5. Click **Save**.
6. Watch **Actions** until **Deploy to GitHub Pages** is green (~2–5 min).
7. Hard-refresh. Play at `/play/my-game` and the card at `/game/my-game`.

**Large files:** `.wasm` / `.pck` use Git LFS automatically. Do not close the tab during upload.

**No ZIP (itch.io / Netlify):** skip the zip. Paste the public **https** play URL in **External play URL**, then Save. You do not need a `games/` folder for that title.

**Download what is live:** on the game page (signed in as admin) or Admin → Games, use **Download posted files**. That zips `games/<slug>/` as the site serves it.

---

## Update a game that is already on the site

Same as adding: **Games** tab → pick the existing title from the list → upload a **new ZIP** (same slug) → Save → wait for deploy → hard-refresh.

Or on your PC (no admin ZIP):

```bash
# overwrite games/novadrop/ (or fortfury, etc.) with the new Web export
git add games/novadrop games.json
git commit -m "Update NovaDrop web build"
git push origin main
```

If only the build changed, you can skip `games.json`.

---

## Add a page (no code)

1. `/admin` → **Pages**
2. **Slug** e.g. `about` → public URL **`/p/about`**
3. Add blocks (or paste an HTML app)
4. Optional: **Show in top nav**
5. **Save page**
6. Optional: **Overview → Push pages/layout snapshot** so `cms/site-pages.json` is committed (needs the GitHub token). Firestore already has the live edit; the snapshot is what the next Pages build ships.

### Header-only link (Discord, itch, etc.)

**Navigation** tab → new item → URL. That is not a page; it is only a button.

### Coded page (React)

1. Copy a file in `src/pages/` to `src/pages/MyPage.tsx`
2. In `src/App.tsx` add `<Route path="/my-page" element={<MyPage />} />`
3. Commit and push `main`

---

## Edit via GitHub.com (no Admin)

1. Open the repo → the file (`games.json`, `cms/site-pages.json`, `cms/admin-config.json`, …)
2. Pencil → edit → **Commit changes** to **`main`**
3. For a game folder: open `games/<slug>/` → **Add file → Upload files** (small files). Big `.wasm` / `.pck` are easier as **Admin ZIP** or `git push` from a computer with Git LFS.

`games.json` fields: [`games.json.example`](games.json.example). `id` must match the folder name if the build is in the repo.

---

## After every publish

1. GitHub → **Actions** → latest **Deploy to GitHub Pages** = green
2. Hard-refresh the site (or wait a minute)
3. If a game is blank: confirm `games/<id>/index.html` exists **or** `url` is a working https page

---

## What lives where

| Thing | Stored in | How it goes live |
|-------|-----------|------------------|
| Playable HTML5 files | `games/<slug>/` in GitHub (LFS for big binaries) | Pages build copies `games/` |
| Hub catalog | `games.json` + optional Firestore | Admin save writes both when you have a token + Google sign-in |
| Pages, nav, theme | Firestore (immediate) + `cms/*.json` (next deploy if you Push snapshot) | |
| Covers / clips | Firebase Storage | Immediate on the live site |
| Google sign-in | Firebase Auth | `cms/firebase-config.json` |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `/admin` says not on the allow list | Add your exact Google email to `cms/admin-config.json` `admin_emails`, push, wait for deploy |
| ZIP upload fails / “No GitHub token” | **System → GitHub sync** → classic PAT with **`repo`**, branch `main` |
| Token error 403 | Token is for a different GitHub user, missing `repo`, or expired |
| Save works but play is old | Wait for Actions; hard-refresh; confirm you overwrote the same `games/<slug>/` |
| File too big for GitHub web UI | Use Admin ZIP or Git LFS from your PC (`.gitattributes` already tracks `.pck` / `.wasm`) |
| Google popup blocked | Allow popups for criminallydevdads.com |
| Theme/pages revert after deploy | **Overview → Push pages/layout snapshot** (or Push everything) so `cms/` in Git matches Admin |

More detail: [`WEBSITE_WORKFLOW.md`](WEBSITE_WORKFLOW.md), [`SITE_MANUAL.md`](SITE_MANUAL.md), [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md).

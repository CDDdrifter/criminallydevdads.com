# Git sync from Admin — do this first (no SQL required for sync)

## The one thing that confuses everyone

**Pushing CMS content to GitHub does not use the Supabase SQL Editor.**

- **SQL / migrations** = change your **database tables** (columns, policies). You only run those when we add new fields or you’re setting up the project the first time.
- **Git sync** = an **Edge Function** talks to the **GitHub API** and commits JSON files. That uses **Supabase secrets** + **deploying the function**, not random SQL.

If the Admin buttons say “Deploy the function” or “Forbidden” or GitHub errors, fix **secrets + deploy** below — not SQL.

---

## Part A — One-time setup (do once per project)

### 1) GitHub: create a token

1. GitHub → **Settings** → **Developer settings** → **Personal access tokens**.
2. Create a token that can **read/write repo contents** for `criminallydevdads.com`:
   - Fine-grained: **Repository access** = this repo → **Contents: Read and write**
   - Or classic: scope **`repo`**
3. Copy the token (you won’t see it again).

### 2) Supabase: store secrets (not SQL)

Use the **Supabase CLI** on your PC (recommended — copy/paste as one block, edit values):

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

`YOUR_PROJECT_REF` is the short id in your Supabase URL: `https://YOUR_PROJECT_REF.supabase.co`

Then:

```bash
supabase secrets set ^
  GITHUB_TOKEN=paste_your_github_token_here ^
  GITHUB_OWNER=CDDdrifter ^
  GITHUB_REPO=criminallydevdads.com ^
  GITHUB_BRANCH=main
```

(On Mac/Linux use `\` line continuations instead of `^`.)

**Dashboard alternative:** Supabase → **Project Settings** → **Edge Functions** → **Secrets** (if your plan shows it) — add the same names/values.

### 3) Deploy the Edge Function (required after every change to `supabase/functions/`)

From your **repo root** (same folder as `package.json`):

```bash
supabase functions deploy sync-repo-to-github
```

Wait until it finishes with no error.

**If you skip this step, the Admin buttons will never work** — the browser is calling a function that doesn’t exist or is still the old version.

---

## Part B — Every time you want Git to match Admin

1. Edit the site in **`/#/admin`** (saves to Supabase).
2. Go to **Admin → Overview**.
3. Click one of:
   - **Push games.json** — catalog only  
   - **Push pages/layout snapshot** — `cms/site-*.json` (hero, pages, nav, dev logs)  
   - **Push everything** — both  
4. Pull the new commit locally (or let GitHub Actions deploy from `main`).
5. Run your normal deploy so **`cms/`** gets copied into **`dist/cms/`** (the build already runs `scripts/copy-cms.mjs` when `cms/` exists in the repo).

---

## Part C — When you *do* use SQL (migrations)

Only when **we added new database columns** or you’re doing a **fresh** database.

1. Supabase → **SQL Editor** → **New query**.
2. Open the file from this repo: `supabase/migrations/00X_whatever.sql` (run them in order if you’re catching up).
3. Paste → **Run**.

**Not** for Git sync. **Yes** for “Save game failed: column … does not exist”.

---

## Quick troubleshooting

| Symptom | Fix |
|--------|-----|
| **“Edge Function returned a non-2xx status code”** (generic) | Deploy the latest function, then try again: `supabase functions deploy sync-repo-to-github`. After the next site deploy, Admin will show the **real** error text from the function (e.g. missing token, GitHub 403). |
| “Deploy the function…” / 404 / failed to send | Run `supabase functions deploy sync-repo-to-github` |
| “Server missing GITHUB_TOKEN…” | Run `supabase secrets set …` again |
| “Forbidden — not a site admin” | Your login email must be allowed (`site_admin_emails` / `site_admin_domains` in SQL from `schema.sql`) |
| GitHub 403/422 on write | Token lacks **Contents: write** on the correct repo |
| Push works but site still “pops” content | Commit includes `cms/` → redeploy static site so `dist/cms/` exists |

---

## Why it feels “hard”

GitHub will not let a **browser** commit to your repo with your password. So the pattern is: **browser → Supabase (with your login) → Edge Function (with GitHub token secret) → GitHub API**. That’s standard. The SQL editor was never the missing piece for Git.

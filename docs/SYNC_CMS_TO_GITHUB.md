# Sync CMS edits to GitHub

**Start here if you’re lost:** [GIT_SYNC_DO_THIS_FIRST.md](./GIT_SYNC_DO_THIS_FIRST.md) — exact Supabase/GitHub steps (**no SQL** for Git sync).

Browser admin writes to **Supabase**. This project can also **commit JSON snapshots** into the Git repo via the **`sync-repo-to-github`** Edge Function (GitHub token stays server-side only).

## What gets synced

Request body: `{ "scope": "games" | "content" | "all" }` (default: `games`).

| Scope | Files written |
|-------|----------------|
| `games` | Root `games.json` (published `site_games` only, legacy hub format) |
| `content` | `cms/site-settings.json`, `cms/site-pages.json`, `cms/site-nav.json`, `cms/site-devlogs.json`, `cms/site-content.snapshot.json` |
| `all` | Everything above |

**Not committed:** ZIP builds under Storage, raw `games/<slug>/` binaries (still use Storage or normal git for those).

## Why `cms/*.json` exists

Production builds run `scripts/copy-cms.mjs`, which copies repo `cms/` → `dist/cms/`. The app **loads `/cms/*.json` first** when those files exist, so hero text, custom pages, nav, and dev logs render with the first paint instead of waiting on Supabase.

Workflow:

1. Edit in Admin (Supabase).
2. **Overview → Push pages/layout snapshot** (or **Push everything**).
3. Pull / merge the commit, then deploy — the new JSON ships with the static site.

## One-time setup

1. **GitHub token**  
   Fine-grained PAT: **Repository contents: Read and write** on this repo, or classic PAT with `repo`.

2. **Supabase CLI**: `supabase login`, then `supabase link --project-ref YOUR_PROJECT_REF`

3. **Secrets**

   ```bash
   supabase secrets set \
     GITHUB_TOKEN=github_pat_xxxxxxxx \
     GITHUB_OWNER=CDDdrifter \
     GITHUB_REPO=criminallydevdads.com \
     GITHUB_BRANCH=main
   ```

4. **Deploy / redeploy** the function after code changes:

   ```bash
   supabase functions deploy sync-repo-to-github
   ```

## Using it (Admin)

Sign in to `/#/admin` → **Overview**:

- **Push games.json** — catalog fallback for `games.json` + `games/` mode
- **Push pages/layout snapshot** — settings, pages, nav, dev logs → `cms/`
- **Push everything** — both

If the function isn’t deployed or secrets are missing, the UI shows the error from the Edge Function.

## Warnings

- Sync **replaces** the target files on GitHub. Treat **Supabase as source of truth** for live editing; Git snapshots are for deploys and backups.
- **`games.json`**: unpublished games disappear from the exported file (by design).

## Security

- Only callers who pass **`is_site_admin`** can invoke the function.
- `GITHUB_TOKEN` never ships to the browser.

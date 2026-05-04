# Sync CMS edits to GitHub (`games.json`)

Browser admin writes to **Supabase**. The Git repo still has **`games.json`** for file-only / backup / CI. This project includes an optional **Edge Function** that **commits `games.json`** from published `site_games` rows using the **GitHub API** (a **server-side token** — never put that in the React app).

## What gets synced

- **Only** rows in `site_games` with **`published = true`**
- Written to repo root **`games.json`** on the branch you configure (default **`main`**)
- Includes `external_url` for itch / Storage-hosted builds (derived from `storage_slug` when needed)

**Not synced automatically:** pages, nav, dev logs, site settings, or binary files under `games/`. Those stay in Supabase until you add more export steps or copy manually.

**Warning:** Running sync **replaces** `games.json` with the CMS export. Games that exist only in the old JSON and **not** in Supabase (published) will disappear from the file. Treat **Supabase as source of truth** after you adopt sync.

## One-time setup

1. **GitHub token**  
   - Fine-grained PAT: **Repository contents: Read and write** on this repo, or classic PAT with `repo` scope.  
   - Store it only as a Supabase secret (below).

2. **Supabase CLI** (local): [Install](https://supabase.com/docs/guides/cli), then `supabase login` and link the project:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

3. **Secrets** (replace values):
   ```bash
   supabase secrets set \
     GITHUB_TOKEN=github_pat_xxxxxxxx \
     GITHUB_OWNER=CDDdrifter \
     GITHUB_REPO=criminallydevdads.com \
     GITHUB_BRANCH=main
   ```

4. **Deploy the function** (from repo root):
   ```bash
   supabase functions deploy sync-repo-to-github
   ```

5. **Dashboard**  
   Supabase → **Edge Functions** → confirm `sync-repo-to-github` is listed.

## Using it

1. Sign in to **`/#/admin`**.
2. **Overview** → **Sync `games.json` to GitHub**.
3. Wait for success; open GitHub to see the new commit on your branch.

If the function isn’t deployed or secrets are missing, the button shows the error message from the function.

## Security

- Only users who pass **`is_site_admin`** (same as editor allowlist) can trigger the function.
- `GITHUB_TOKEN` never ships to the browser.

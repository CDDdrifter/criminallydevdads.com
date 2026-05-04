# Plug Supabase into the **live** site (GitHub)

`.env.local` is **only for your PC** when you run `npm run dev`.  
The **public website** gets keys from **GitHub Actions secrets** when the workflow runs `npm run build`.

---

## 1. Open the right place (most common mistake)

1. On **github.com**, open **your repository** (the one that deploys the hub — e.g. `criminallydevdads.com`).
2. Click **Settings** (the repo’s Settings tab, **not** your profile Settings).
3. Left sidebar: **Secrets and variables** → **Actions**.
4. You will see two tabs: **Secrets** and **Variables**.

You must use **Secrets** — **not** Variables.

- **Secrets** → `secrets.VITE_*` in the workflow ✅  
- **Variables** → `vars.VITE_*` — our workflow does **not** read these ❌

If you added `VITE_SUPABASE_URL` under **Variables**, the build will see **empty** values and admin will say Supabase isn’t configured.

---

## 2. Create exactly two repository secrets

Still on **Actions** → **Secrets** tab:

1. **New repository secret**
   - **Name:** `VITE_SUPABASE_URL` (copy this line — spelling matters)
   - **Value:** your Supabase **Project URL** only, e.g. `https://abcdefgh.supabase.co`  
     No quotes. No spaces before/after.

2. **New repository secret** again
   - **Name:** `VITE_SUPABASE_ANON_KEY`
   - **Value:** the long **anon** / **public** key from Supabase → Project Settings → API.

Save each.

**Optional 4th secret** (only if magic links open the wrong site or auth loops):  
`VITE_AUTH_REDIRECT_URL` = your real public root, e.g. `https://criminallydevdads.com/` (same string in Supabase → Redirect URLs). Redeploy after adding.

Where to copy from: **`docs/SUPABASE_COPY_THESE_TWO_VALUES.md`**.

---

## 3. Redeploy

1. **Actions** tab → **Deploy to GitHub Pages** → open the latest run → **Re-run all jobs**  
   **or** push any commit to **`main`** or **`fixing.fortfury`** (the branches in `.github/workflows/deploy-pages.yml`).

2. Wait for the green checkmark.

3. Open **`https://YOUR_SITE/#/admin`**.  
   If keys were picked up, you should see the **Team login** screen (not the “doesn’t include Supabase keys” message).

---

## 4. If it still fails, check the workflow log

Open the latest **Deploy to GitHub Pages** run → **deploy** job.

There is a step that prints **warnings** if `VITE_SUPABASE_URL` or `VITE_SUPABASE_ANON_KEY` is **empty** (it does **not** print your secrets).

- If you see those warnings → secrets are missing, misnamed, or in **Variables** instead of **Secrets**.

---

## 5. Forks

Secrets live on **each** repo. If the site builds from a **fork**, add the secrets on **that fork’s** Settings, not only the upstream repo.

# Supabase setup (first time, click by click)

**You can skip this entire document** if you only want to edit the site in Git: use **`docs/WEBSITE_WORKFLOW.md` Path A** (`games.json`, `games/<slug>/`, `src/`). Supabase is optional.

You only do this **once per website** if you want **`/#/admin`**. I cannot run these steps for you (they use **your** Supabase and GitHub logins), but if you follow the order below, **Team login** / admin will work.

**Ultra-literal “which two strings to copy”:** **[`SUPABASE_COPY_THESE_TWO_VALUES.md`](SUPABASE_COPY_THESE_TWO_VALUES.md)** (same as the hints on **`/#/admin`** after deploy).

---

## Part A — Create the database

1. Open **[supabase.com](https://supabase.com)** and sign in (or create an account).
2. Click **New project**.
3. Pick an **organization**, **name** (e.g. `criminallydevdads`), **database password** (save it somewhere safe), **region** (closest to you), then **Create new project**.
4. Wait until the dashboard says the project is ready (usually 1–2 minutes).

---

## Part B — Run the site’s SQL (tables + login rules)

1. In the left sidebar, click **SQL Editor**.
2. Click **New query**.
3. On your computer, open the repo file **`supabase/schema.sql`**, select **all** text, copy it.
4. Paste into the Supabase SQL editor.
5. Click **Run** (bottom right).

- If you see errors like **“policy … already exists”**, you’re on a project that was partially set up before. Easiest fix: create a **new** Supabase project and run `schema.sql` once on that empty project, **or** ask in chat with the **full error text** so someone can give you a small “drop policy” fix script.

---

## Part C — Turn on sign-in methods (Email + optional Google)

1. Left sidebar: **Authentication** → **Providers**.
2. **Email** — turn **Enable Email provider** **ON**.  
   - For testing, you can turn **Confirm email** OFF so magic links work faster (turn it back ON for production if you want stricter security).
3. **Google** (optional but nice for team Google accounts):
   - Turn **Enable Google provider** **ON**.
   - You’ll need a **Client ID** and **Client Secret** from [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials → Create OAuth client ID (Web application).  
   - In Google’s OAuth settings, add **Authorized redirect URI**:  
     `https://<YOUR_PROJECT_REF>.supabase.co/auth/v1/callback`  
     (replace `<YOUR_PROJECT_REF>` with the ref shown in Supabase **Project Settings** → **API** — it’s the subdomain of your project URL.)

---

## Part D — Tell Supabase which website URLs are allowed (important)

Magic links and OAuth return the user to your **real** site URL. Supabase blocks unknown URLs.

1. Left sidebar: **Authentication** → **URL Configuration**.
2. **Site URL** — set to the main URL people use to open the site, for example:
   - Local test: `http://localhost:5173`
   - GitHub Pages: `https://<your-username>.github.io/<repo-name>/`  
     (include the trailing slash if that’s how you always open the site.)
3. **Redirect URLs** — click **Add URL** and add **every** place you open the app, for example:
   - `http://localhost:5173`
   - `http://localhost:5173/**` (if Supabase accepts wildcards in your version; if not, add the exact paths you use.)
   - Your GitHub Pages URL, e.g. `https://<username>.github.io/<repo>/`
   - Same with `http://` if you ever use it.

Save. If login redirects to Supabase but then fails with “redirect URL mismatch”, come back here and add the **exact** URL shown in the browser address bar (without the `#/...` hash part is usually enough for the allowlist).

---

## Part E — Put keys in GitHub (so the live site can talk to Supabase)

1. In Supabase: **Project Settings** (gear) → **API**.
2. Copy:
   - **Project URL** → this is `VITE_SUPABASE_URL`
   - **anon public** key → this is `VITE_SUPABASE_ANON_KEY`
3. Open your repo on **GitHub** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
4. Create two secrets with those exact names:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
5. **Settings** → **Pages** → under **Build and deployment**, set **Source** to **GitHub Actions** (not “Deploy from a branch”) so the workflow that injects these keys into the build actually runs.

Push a commit to **`main`** or **`fixing.fortfury`** (your workflow branches) and wait for the green check on **Actions** → **Deploy to GitHub Pages**.

---

## Part F — Who is allowed to open Admin?

Editors are allowlisted **only in the database**, not in Git code.

- **Everyone with an email on a domain** (e.g. your studio):

  ```sql
  insert into site_admin_domains (domain) values ('criminallydevdads.com')
  on conflict (domain) do nothing;
  ```

  (That line is already in `schema.sql` once; change the domain if yours is different.)

- **One specific address** (e.g. personal Gmail):

  ```sql
  insert into site_admin_emails (email) values ('you@gmail.com')
  on conflict (email) do nothing;
  ```

Run those in **SQL Editor** → **New query** → **Run**.

---

## Part G — Google & email don’t work (troubleshooting)

Work through these in order. Most failures are **Supabase dashboard** settings, not the React code.

### 1. Confirm the site actually uses Supabase

- Open **`/#/admin`**. If you see a message about adding `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`, the **build has no keys**.  
  - **Local:** create `.env.local` with both variables (Project Settings → API in Supabase) and run `npm run dev` again.  
  - **GitHub Pages:** add the same two names as **Actions secrets** and redeploy (see Part E).

### 2. Redirect URLs (fixes “redirect URL mismatch” / OAuth loop / magic link dead end)

Supabase only allows redirects you list explicitly.

1. **Authentication** → **URL Configuration**.
2. **Site URL** — set to the URL you actually open (examples below).
3. **Redirect URLs** — add **every** variant you use, one per line. Common GitHub Pages patterns:

   - `https://YOUR_USER.github.io/YOUR_REPO/`
   - `https://YOUR_USER.github.io/YOUR_REPO/index.html`

   Local dev:

   - `http://localhost:5173`
   - `http://127.0.0.1:5173`

4. Save, wait a minute, try again.

If the error mentions **redirect**, copy the **exact** URL from the error (or from the address bar right before it fails) and add it here.

### 3. Email magic link

1. **Authentication** → **Providers** → **Email** → **enabled**.
2. For testing, set **Confirm email** to **OFF** (fewer steps; turn ON later for production).
3. **Allow-listed email:** magic link only sends if your address passes **`can_request_editor_login`**. That means either:
   - your domain is in **`site_admin_domains`**, or  
   - your exact address is in **`site_admin_emails`** (Part F).  
   If not allow-listed, the app shows an error *before* sending — that is expected.
4. If the RPC is missing, SQL never ran: run **`supabase/schema.sql`** (or at least migration **`003_editor_login_rpc.sql`**).
5. Check **spam** for the message. Supabase’s default mail can be slow or filtered.

### 4. Google sign-in

1. **Authentication** → **Providers** → **Google** → **enabled**.
2. **Client ID** and **Client Secret** must come from [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **Credentials** → **OAuth 2.0 Client ID** (type **Web application**).
3. Under that OAuth client, **Authorized redirect URIs** must include **exactly**:

   `https://<YOUR_PROJECT_REF>.supabase.co/auth/v1/callback`

   (`YOUR_PROJECT_REF` is the subdomain of your Supabase URL, e.g. `abcdxyzcompany` from `https://abcdxyzcompany.supabase.co`.)

4. Google **OAuth consent screen** must be configured (app name, your email as test user if the app is in **Testing** mode — only listed test users can sign in).
5. Browser error **redirect_uri_mismatch** → the Supabase callback URL is missing or wrong in Google Cloud (step 3).

### 5. After login: “Access denied”

That means auth **worked** but the email is not an editor in the database. Add your domain or exact email (Part F).

### 6. Browser console

On **`/#/admin`**, press **F12** → **Console**. Try Google or email again.

- **`can_request_editor_login`** / **`is_site_admin`** errors → run full **`supabase/schema.sql`** (or migration **003**) in the SQL Editor.
- **Invalid API key** → wrong `VITE_SUPABASE_ANON_KEY` in env or an old deploy.

---

## Check that it worked

1. Open your deployed site (or `http://localhost:5173` with `.env.local` containing the same two `VITE_*` values).
2. Go to **`/#/admin`** (the header link is optional unless you set `VITE_SHOW_ADMIN_NAV=true` — see **`docs/SITE_MANUAL.md`** §11).
3. Use **Continue with Google** or **Send login link** with an allowlisted email.
4. You should see **Site admin** with tabs (overview, games, pages, etc.).

If **Access denied** appears after sign-in, the email is not in `site_admin_domains` / `site_admin_emails` — add it in Part F.

If the page stays on “Checking session…” or errors in the browser console mention **`is_site_admin`**, make sure **Part B** ran successfully (full `schema.sql` on a fresh project, or migration `003` if you were told to run it on an older database).

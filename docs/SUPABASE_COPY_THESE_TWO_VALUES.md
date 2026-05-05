# Copy exactly these two values (no guessing)

Use this page together with what **`/#/admin`** shows you after deploy (it prints your **exact** redirect URL and validates your keys).

---

## “General” settings vs “API” (why your link still fails)

- **Project Settings → General** shows **Project ID** (a short ref like `yebnifkynoucfbdhdva`). That is **only part** of the URL — **do not** paste just the ID into GitHub.
- You need the full **Project URL** from **Project Settings → API** (gear → **API**, not General):  
  **`https://<that-same-ref>.supabase.co`**
- The sidebar may say **“Data API”** or show REST docs elsewhere — still, the string you want is the **`https://….supabase.co`** label at the top of the **API** settings page (same page as the **anon** key table).

---

## These are NOT what you need (common mix-ups)

| What people open by mistake | Why it’s wrong |
|------------------------------|----------------|
| **Database** password you chose when creating the project | That’s for Postgres tools, not the website. |
| **Settings → Database** or connection strings | Wrong screen. |
| **Project Settings → API Keys** on some UIs that only show “publishable” in a different layout | You still need the screen that shows **Project URL** + table with **anon** / **service_role**. |
| **`service_role`** key (often labeled **secret**) | **Never** put this in the hub. It bypasses security. |
| The link in your **browser address bar** (`supabase.com/dashboard/project/...`) | That is **not** the Project URL. |
| Supabase **Vault** / unrelated “Secrets” features | Not used for this React app. |

You need **only** the **Project URL** + **anon public** key from **Project Settings → API**.

---

## Where in Supabase (same for both values)

1. Open **[supabase.com](https://supabase.com)** and sign in.
2. Click your **project** (the tile with your project name — not “Organization settings”).
3. Look at the **left sidebar**. Scroll **down** to the **gear icon** **Project Settings** and click it.
4. A **second** menu appears (still on the left). Click **API** — *not* “General”, *not* “Database”, *not* “Auth”.

You stay on this **API** screen to copy both items below.

**If you don’t see “API”:** make sure you clicked **Project Settings** (gear) for **this project**, not your user profile.

---

## ① `VITE_SUPABASE_URL` — “Project URL”

On the **API** page, at the top, you’ll see a box labeled **Project URL**.

- It looks **exactly** like: `https://abcdefghijklmnop.supabase.co`  
  (the letters/numbers before `.supabase.co` are **your** project ref — yours will differ.)
- Copy that **whole** line. **Nothing after** `.supabase.co` (no `/dashboard`, no `/project/...`).

### Wrong (do not use)

- Anything with **`supabase.com/dashboard`** in the address bar of your browser.
- Anything that is **not** `https://something.supabase.co`.

If you paste a dashboard link into GitHub secrets, **Google login can 404** because the app talks to the wrong host.

---

## ② `VITE_SUPABASE_ANON_KEY` — “anon” + “public”

On the **same API** page, scroll to **Project API keys** (or similar).

- Find the row named **`anon`** and labeled **`public`**.
- Click **Reveal** (if needed), then **Copy**.
- That long string is **`VITE_SUPABASE_ANON_KEY`**.

### Wrong (do not use)

- **`service_role`** (secret) — never put this in the website or in `VITE_*` variables.

---

## Where to paste them (this “connects” the live site)

The **website does not read Supabase by itself**. You must put the two strings into **GitHub** so the **build** bakes them in.

### GitHub (production site)

1. Open **your repo on github.com** (e.g. `criminallydevdads.com`).
2. Click the **Settings** tab (**of the repository**, not your GitHub profile).
3. Left sidebar: **Secrets and variables** → **Actions**.
4. **New repository secret** (do this twice):
   - Name: **`VITE_SUPABASE_URL`** → Value: paste the **Project URL** (`https://….supabase.co`).
   - Name: **`VITE_SUPABASE_ANON_KEY`** → Value: paste the **anon public** long key.

Names must match **exactly** (including `VITE_` at the start). No extra spaces.

5. Trigger a new deploy: **Actions** tab → open the last workflow run → **Re-run all jobs**, or push an empty commit.

Until this is done, **`/#/admin`** on the **live** site will act like Supabase isn’t connected.

### Local (testing on your PC)

In the repo folder, create **`.env.local`**:

```env
VITE_SUPABASE_URL=https://YOUR_REF.supabase.co
VITE_SUPABASE_ANON_KEY=paste_anon_key_here
```

Then `npm run dev` and open `http://localhost:5173/#/admin`.

---

## After that: fix Google 404 (redirect URLs)

1. Open your **live** site to **`/#/admin`**.
2. Copy the **exact** “add this URL” line the page shows (your **Redirect URL**).
3. In Supabase: **Authentication** → **URL Configuration**:
   - **Site URL** = that same URL (your site root with trailing slash if shown).
   - **Redirect URLs** = add that **exact** line (and `http://localhost:5173/` for local dev if you test locally).

4. In **Google Cloud Console** → your OAuth **Web client** → **Authorized redirect URIs**, the **only** Supabase callback is:

   `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`

   Replace `YOUR_PROJECT_REF` with the subdomain from your **Project URL** (the part before `.supabase.co`).

---

## Still stuck?

On **`/#/admin`**, open the browser **Console** (F12). The app will also warn if **Project URL** or **anon key** look wrong. See **`docs/SUPABASE_FIRST_TIME_SETUP.md`** Part G.

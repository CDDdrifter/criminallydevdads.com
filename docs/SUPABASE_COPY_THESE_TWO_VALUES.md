# Copy exactly these two values (no guessing)

Use this page together with what **`/#/admin`** shows you after deploy (it prints your **exact** redirect URL and validates your keys).

---

## Where in Supabase (same for both values)

1. Open **[supabase.com](https://supabase.com)** and sign in.
2. Click your **project** (not “Organization settings”).
3. In the **left sidebar**, scroll down and click the **gear: Project Settings**.
4. Click **API** in the submenu (under Project Settings).

You stay on this **one** screen to copy both items below.

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

## Where to paste them

| Where | Names (exact) |
|--------|----------------|
| **GitHub** → repo → **Settings** → **Secrets and variables** → **Actions** | `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` |
| **Local** | `.env.local` in the repo root, same names |

Then **redeploy** (GitHub Actions) or restart `npm run dev`.

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

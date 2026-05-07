# Supabase for beginners (what is actually going on)

This page assumes you **do not** already know Supabase. Your site can run **without** it (Git + `games.json` only). You only need this if you want **`/#/admin`**, cloud game ZIPs, and the database-backed hub.

---

## 1. What Supabase is (one paragraph)

**Supabase** is a hosted **Postgres database** + **Auth** + **file storage** + **serverless functions**, all tied to **one project** in the cloud. Your React site talks to it over HTTPS using:

- **Project URL** — looks like `https://abcdefgh.supabase.co` (this is **not** the website you built; it’s the **API** for your project).
- **Anon (public) key** — safe to put in the **website** build; it only does what **Row Level Security** allows.
- **Service role key** — **secret**; only for **Edge Functions** on the server, never in the browser.

Nothing in Supabase “stays open” like a program. **Closing browser tabs does not stop or undo your database.** The database keeps whatever was already applied.

---

## 2. SQL Editor tabs — you didn’t break anything

In **SQL Editor**:

- A **tab** is just an unsaved/notepad-style window for SQL text.
- **Run** sends that SQL to the database **once**. After it succeeds, the change is **saved in the project**.
- **Closing a tab** does **not** roll back SQL that already ran.
- **Running the same migration again** is usually safe because our SQL uses `IF NOT EXISTS` / `add column if not exists` where it matters. If you get **“already exists”** errors, the thing is already there — you can skip that bit or paste only the part that failed.

If you’re unsure what’s already applied, easiest path: open **Table Editor** → **`site_games`** and see if columns like `pricing_model` or `visual_preset` exist. If they’re missing, run the matching migration (or re-run `schema.sql` on a **new** empty project — see below).

---

## 3. Two ways to apply database structure

### Path A — One big file (simplest for a **new** empty project)

1. Supabase → **SQL Editor** → **New query**.
2. Open your repo file **`supabase/schema.sql`** in VS Code / Notepad.
3. **Select all** → copy → paste into Supabase → **Run**.

That file is maintained to include the same end state as the migrations (tables, policies, storage, commerce columns, FX settings, etc.). Use this when you’re starting fresh or your project was never set up.

**If Run errors** with “policy already exists” / “relation already exists”, your project was **partially** set up. Then either:

- create a **brand-new** Supabase project and run `schema.sql` once, **or**
- use Path B and only run migrations you’re missing (or ask someone with the **full error text**).

### Path B — Numbered migrations (when you already have a live project)

Run **in order** from the repo folder `supabase/migrations/`:

| File | What it adds (short) |
|------|----------------------|
| `001_site_page_sections.sql` | Page `sections` JSON on `site_pages` |
| `002_game_builds_storage.sql` | Storage bucket + policies for game ZIPs |
| `003_editor_login_rpc.sql` | `can_request_editor_login` RPC for auth flow |
| `004_game_thumbnails_storage.sql` | Thumbnail bucket + policies |
| `005_game_preview_videos_storage.sql` | Preview video bucket + policies |
| `006_site_games_storage_entry_in_zip.sql` | `storage_entry_in_zip` on `site_games` |
| `007_game_detail_sections_visual_preset.sql` | `sections` + `visual_preset` on `site_games` |
| `008_commerce_and_support_buttons.sql` | `price_cents`, `purchase_url`, `stripe_price_id`, support fields on `site_settings` |
| `009_game_pricing_models.sql` | `pricing_model`, PWYW/donation columns |
| `010_site_visual_fx_settings.sql` | Site-wide FX toggles + `site_visual_preset` on `site_settings` |

For each file: **New query** → paste **whole file** → **Run**. If it says a column already exists, that migration was probably already applied — move to the next number.

**You do not need 008–010 for “basic admin + games”** if you never plan to use those features yet — but the **website code** expects those columns if you use pricing / FX in Admin. Safest: run everything through **010** so Admin save doesn’t hit “unknown column”.

---

## 4. “Secrets” — three different places (not the same thing)

People say “secrets” and mean different things:

### A) GitHub Actions secrets (your **live website** build)

- Names: **`VITE_SUPABASE_URL`**, **`VITE_SUPABASE_ANON_KEY`**
- Where: GitHub repo → **Settings** → **Secrets and variables** → **Actions**
- Purpose: bake Supabase into the **static site** so `/#/admin` and the hub can talk to your project.

Without these, the deployed site may still work in **legacy** mode (`games.json` only), but **Admin / CMS** won’t connect.

Copy values from: **`docs/SUPABASE_COPY_THESE_TWO_VALUES.md`**.

### B) Supabase Edge Function secrets (**Push to GitHub** from Admin)

- Names: **`GITHUB_TOKEN`**, **`GITHUB_OWNER`**, **`GITHUB_REPO`**, optional **`GITHUB_BRANCH`**, sometimes **`SUPABASE_ANON_KEY`** if auto-inject fails
- Where: **Supabase** → **Project Settings** → **Edge Functions** → **Secrets** (or `supabase secrets set` in CLI)
- Purpose: the **`sync-repo-to-github`** function commits `games.json` / `cms/*.json` to GitHub **for you**.

If you **never** use “Push CMS to GitHub” in Admin, you **don’t** need to set these.

Guide: **`docs/GIT_SYNC_DO_THIS_FIRST.md`**.

### C) Stripe checkout (optional — **selling**)

- Names: **`STRIPE_SECRET_KEY`**, **`SITE_URL`**, **`SUPABASE_SERVICE_ROLE_KEY`**, etc.
- Where: same as (B), but for the function **`create-checkout-session`**
- Purpose: **buy** buttons that go through Stripe.

If you **don’t** have Stripe set up, **ignore this entirely**. No migration forces Stripe; commerce columns can sit unused.

Guide: **`docs/STRIPE_CHECKOUT.md`**.

---

## 5. Game purchase / Stripe — do you need it now?

**No.** It’s optional.

- Migrations **008** and **009** only add **database columns** and settings the Admin form can use.
- Nothing charges a card until you:
  1. Run those migrations (or `schema.sql`),
  2. Deploy the **`create-checkout-session`** Edge Function,
  3. Set Stripe-related **secrets**,
  4. Turn on pricing in Admin.

Until then, leave pricing as **Free** and skip Stripe docs.

---

## 6. Order of operations checklist (practical)

1. Create Supabase project (if you don’t have one).
2. Run **`schema.sql`** **or** migrations **001 → 010** in order.
3. **Authentication** → turn on **Email** (and optional Google) per **`SUPABASE_FIRST_TIME_SETUP.md`**.
4. **Authentication** → **URL Configuration** → add your real site URLs (GitHub Pages / custom domain).
5. Put **`VITE_SUPABASE_URL`** and **`VITE_SUPABASE_ANON_KEY`** in **GitHub Actions** secrets → redeploy site.
6. Open **`/#/admin`**, sign in with an allowlisted email/domain (from `schema.sql`: `site_admin_domains` / `site_admin_emails`).
7. **Only if** you want Git push from Admin: set GitHub secrets on Supabase + deploy **`sync-repo-to-github`** (`docs/GIT_SYNC_DO_THIS_FIRST.md`).
8. **Only if** you want Stripe: follow **`STRIPE_CHECKOUT.md`** after the above works.

---

## 7. Where to go next

- First-time click-through: **`SUPABASE_FIRST_TIME_SETUP.md`**
- Copy/paste the two Vite values: **`SUPABASE_COPY_THESE_TWO_VALUES.md`**
- Git sync from Admin: **`GIT_SYNC_DO_THIS_FIRST.md`**
- Selling: **`STRIPE_CHECKOUT.md`**

You’re not supposed to “just know” this — the dashboard changes often; use **Project ID** → `https://<id>.supabase.co` when the UI hides the URL (explained in **SUPABASE_COPY_THESE_TWO_VALUES.md**).

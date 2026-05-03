# Simple admin login (edit the website)

**What you want:** open **`/#/admin`**, sign in with **your team email**, change games/pages/settings.

**Why it feels hard:** the hub does not run its own password server. **Supabase** (free tier is fine) handles “is this really your email?” via a **magic link**. You connect the hub to Supabase **once**; after that, logging in is just **email → click link**.

**Who can edit:** only emails you allow in the database (by **domain** or **exact address**). This repo’s SQL already allows **`@criminallydevdads.com`**. Other addresses need one SQL line (step 4).

---

## Do these in order (email login first — skip Google until this works)

### 1) Supabase project + database

1. [supabase.com](https://supabase.com) → **New project** → wait until it’s ready.
2. **SQL Editor** → **New query** → paste the **entire** file **`supabase/schema.sql`** from this repo → **Run** (must succeed with no red errors).

### 2) Put two keys in your **GitHub** build

1. Supabase → **Project Settings** (gear) → **API**.
2. Copy **Project URL** and **anon public** key (not `service_role`).
3. GitHub repo → **Settings** → **Secrets and variables** → **Actions** → add:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
4. Push any commit (or re-run **Actions**) so the site **rebuilds**.  
   Literal copy-paste help: **`docs/SUPABASE_COPY_THESE_TWO_VALUES.md`**.

### 3) Turn on **Email** sign-in in Supabase

1. **Authentication** → **Providers** → **Email** → **Enable**.
2. For testing: **Confirm email** → **OFF** (fewer steps; turn ON later if you want stricter security).

### 4) Allow **your** email (if you’re not `@criminallydevdads.com`)

In **SQL Editor**, run (change the address):

```sql
insert into site_admin_emails (email) values ('you@yourdomain.com')
on conflict (email) do nothing;
```

If your whole team uses one domain, you can add a domain instead:

```sql
insert into site_admin_domains (domain) values ('yourdomain.com')
on conflict (domain) do nothing;
```

### 5) Redirect URL (stops loops / 404 after clicking the magic link)

1. Open your **live** site: **`https://…your site…/#/admin`** (after step 2 deployed).
2. The page shows a **green box** with an **exact URL** to copy.
3. Supabase → **Authentication** → **URL Configuration**:
   - **Site URL** = that URL (same as the box).
   - **Redirect URLs** → **Add** → paste that **same** URL.

Save.

---

## Log in (every time after setup)

1. Go to **`/#/admin`**.
2. Type your allowlisted email → **Send login link**.
3. Open your inbox → click the link → you should see **Site admin**.

**Google** is optional. If email works, add Google later using **`docs/SUPABASE_FIRST_TIME_SETUP.md`** Part C + Google Cloud redirect.

---

## If magic link says you’re not allow-listed

Your email isn’t in **`site_admin_domains`** / **`site_admin_emails`**. Do step 4 again with the exact address you typed.

---

## If you still see “add VITE_SUPABASE…” on `/admin`

The live build doesn’t have the secrets yet — redo step 2 and wait for deploy to finish.

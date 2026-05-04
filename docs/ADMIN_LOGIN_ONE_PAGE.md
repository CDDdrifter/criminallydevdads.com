# Log in and edit the site (one page)

Do these **in order**. Skip Google until email works.

1. **Live build has Supabase keys**  
   GitHub repo → **Settings** → **Secrets and variables** → **Actions** → tab **Secrets** (not Variables):  
   `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` → then **Actions** → re-run **Deploy to GitHub Pages**.

2. **Database functions exist**  
   Supabase → **SQL Editor** → paste the **entire** `supabase/schema.sql` from this repo → **Run** (no red errors).

3. **Magic link allowed**  
   Supabase → **Authentication** → **Providers** → **Email** → **Enable**.  
   (Optional while testing: turn **Confirm email** OFF for fewer steps.)

4. **Redirect URL matches your real address**  
   Open the site the **public** uses (custom domain or `https://YOU.github.io/REPO/`). Go to **`/#/admin`**.  
   Copy the URL from the **green box** on that page.  
   Supabase → **Authentication** → **URL Configuration**: set **Site URL** and add that same string under **Redirect URLs**.  
   If the box is wrong (you use a custom domain but opened `github.io` once), add optional GitHub secret **`VITE_AUTH_REDIRECT_URL`** = your canonical site root, e.g. `https://criminallydevdads.com/` — redeploy.

5. **Your email is allowlisted**  
   `schema.sql` already allows **`@criminallydevdads.com`**.  
   For Gmail / another domain, run in SQL Editor:

   ```sql
   insert into site_admin_emails (email) values ('you@example.com')
   on conflict (email) do nothing;
   ```

6. **Sign in**  
   **`/#/admin`** → type email → **Send login link** → inbox → click link → open **`/#/admin`** again if you land on the home page. You should see **Site admin** tabs.

---

| What you see | What it means |
|--------------|----------------|
| “doesn’t include Supabase keys” | Deploy didn’t get the two GitHub **Secrets**; re-run deploy after fixing. |
| “not on the editor allow list” | Step 5 — add your **exact** email (or domain) in SQL. |
| “Can’t verify editor access” + technical error | Step 2 — run full `schema.sql` again; or wrong Supabase project. |
| Magic link doesn’t arrive | Spam folder; or Supabase **Email** provider / project mail limits. |
| Error when clicking link | Step 4 — **Redirect URLs** must match the green box **exactly** (https, path, trailing slash). |

Google sign-in is optional and needs extra OAuth setup — use email first.

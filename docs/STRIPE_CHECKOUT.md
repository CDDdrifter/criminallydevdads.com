# Stripe Checkout — full setup, Supabase alignment, and troubleshooting

This document is the **single source of truth** for selling on the hub with **built-in Stripe Checkout**. Read **`docs/SUPABASE_COPY_THESE_TWO_VALUES.md`** first if you are new to Supabase — the dashboard **UI layout changed** in 2024–2026; URL and keys are split across screens. This guide repeats only what matters for **commerce** so you do not mix up secrets or URLs again.

---

## What the site does

| Piece | Role |
|--------|------|
| **React app (GitHub Pages)** | Game pages, “Buy” UI, calls Supabase Edge Function with the **anon** client. |
| **Supabase `site_games`** | Admin-configured prices, pricing model, optional external checkout URL. |
| **Edge Function `create-checkout-session`** | Validates the game row, talks to **Stripe** with **secret** key, returns Checkout URL. |
| **Stripe** | Hosted payment page, receipts, tax (if you enable it), payouts. |

**Important:** The browser **never** sees your Stripe secret key. Only the Edge Function does.

---

## Two completely different “Supabase” URLs (do not confuse them)

| Variable / secret | Where it lives | What it must be | Used for |
|-------------------|----------------|-------------------|----------|
| **`VITE_SUPABASE_URL`** | GitHub Actions secrets + `.env.local` | `https://<project-ref>.supabase.co` **only** (no path after host) | PostgREST, Auth, Storage, **invoking** Edge Functions from the app |
| **`SITE_URL`** | **Supabase → Edge Functions → Secrets** only | Your **public website** root, e.g. `https://user.github.io/repo` or `https://yourdomain.com` **no trailing slash** | Stripe **success** and **cancel** redirects after payment |

- **`VITE_SUPABASE_URL`** = API host for **this Supabase project** (same rules as in **`supabaseHealth.ts`**: not `app.supabase.com`, not dashboard address bar).
- **`SITE_URL`** = where **players** open **your** hub (must match **hash** routes below).

If `SITE_URL` is wrong, Stripe still charges, but users land on a **404** or wrong site after paying.

---

## Hash router (`#`) — must match production

The app uses **React Router `HashRouter`** (see `src/App.tsx`). Real URLs look like:

- Hub: `https://YOUR_SITE/#/`
- Game: `https://YOUR_SITE/#/game/my-slug`
- Success: `https://YOUR_SITE/#/purchase/success?session_id=...`

The Edge Function builds:

- `success_url` = `{SITE_URL}/#/purchase/success?session_id={CHECKOUT_SESSION_ID}`
- `cancel_url` = `{SITE_URL}/#/game/{slug}`

**`SITE_URL` must be the origin + path prefix** where your **index.html** is served:

- GitHub project site: often `https://<user>.github.io/<repo>` — **include `/repo`** if that is how you open the site.
- Custom domain at apex: `https://criminallydevdads.com`
- **Wrong:** `https://user.github.io` when the SPA actually lives at `https://user.github.io/criminallydevdads.com/`.

Use the **same** URL you put in Supabase **Authentication → URL Configuration → Site URL** as your canonical public entry (see **`docs/SUPABASE_FIRST_TIME_SETUP.md`**). One wrong character here causes “works in dev, broken in prod.”

---

## Supabase dashboard UI (why people broke the site for a week)

Supabase moved **Project URL** and **keys** around. You might only see **API Keys** without an obvious URL field.

**Always do this if confused:**

1. Open **Project Settings (gear) → General → Project ID** (reference string).
2. Build the API URL yourself: `https://` + **Project ID** + `.supabase.co`  
   Example: ID `yebnifkynoucfbdhdva` → `https://yebnifkynoucfbdhdva.supabase.co`

That string is exactly what **`VITE_SUPABASE_URL`** must be (and what **`normalizeSupabaseProjectUrl`** in `src/lib/supabaseHealth.ts` enforces: **strip any accidental path** after `.supabase.co`).

**Full step-by-step with Options A/B/C:** **`docs/SUPABASE_COPY_THESE_TWO_VALUES.md`**.

**Never use:**

- The browser address bar while you are on `supabase.com/dashboard/...`
- `app.supabase.com` as `VITE_SUPABASE_URL` (the admin validates and rejects this)
- **`service_role`** in `VITE_SUPABASE_ANON_KEY` or in any frontend env

---

## Secrets: where each thing goes

### GitHub Actions (Vite build — **public** keys only)

| Secret | Value |
|--------|--------|
| `VITE_SUPABASE_URL` | `https://<ref>.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | **anon** / **public** key |

See **`docs/GITHUB_ACTIONS_SUPABASE_SECRETS.md`** — must be **Secrets**, not **Variables**, with exact names.

### Supabase Edge Function `create-checkout-session` (server — **secret** keys)

Set in **Project Settings → Edge Functions → Secrets** (or `supabase secrets set`):

| Secret | Purpose |
|--------|---------|
| `STRIPE_SECRET_KEY` | `sk_test_...` or `sk_live_...` |
| `SITE_URL` | Public hub base, **no trailing slash** (see above) |
| `SUPABASE_SERVICE_ROLE_KEY` | **service_role** from **Project Settings → API** — **only** here, never in the React bundle |
| `SUPABASE_URL` | Usually auto-injected in hosted Supabase; if the function errors, set explicitly to the same `https://<ref>.supabase.co` as above |

The function **normalizes** `SUPABASE_URL`: if someone pastes a URL with a path after `.supabase.co`, it is stripped to match the JS client (same idea as `normalizeSupabaseProjectUrl`).

### Stripe

- Use **Test mode** until flows are verified end-to-end.
- **Live** keys require completed Stripe account / capabilities for your region.

---

## Database

Apply migration **`009_game_pricing_models.sql`** (or the matching section of `supabase/schema.sql`) so `site_games` has:

- `pricing_model` (`free` | `fixed` | `pwyw` | `donation`)
- `pwyw_min_cents`, `pwyw_suggested_cents`, `donation_presets_cents`

Without these columns, Admin save may retry-drop unknown columns (see `upsertGame` in `src/lib/cmsData.ts`), or checkout validation will not match Admin.

---

## Deploy the function

From repo root (with Supabase CLI linked to this project):

```bash
supabase functions deploy create-checkout-session
```

`supabase/config.toml` sets **`verify_jwt = false`** for this function so **buyers** do not need a hub account. The function still requires a **published** game row and validates amounts server-side.

---

## Admin behavior (aligned with code)

- **External checkout URL** on a game **wins**: the hub opens that link; the Edge Function **refuses** internal checkout for that row (defense in depth).
- **Fixed:** uses `stripe_price_id` if set, else `price_cents` (minimum **$0.50** USD for ad-hoc `price_data` — Stripe rule).
- **PWYW / donation:** customer amount; server enforces `max(admin minimum, $0.50)` and a large upper cap.
- **Minimum $0.50:** enforced in **`src/lib/gamePricing.ts`** (`stripeMinimumUsdCents`) and in the Edge Function — keep them in sync if you change policy.

---

## Fulfillment (not implemented)

Checkout **collects payment**. It does **not** by itself:

- Email Steam keys
- Unlock downloads in Storage
- Write an “owned games” table

That needs **Stripe webhooks** (`checkout.session.completed`) and your own rules. Plan separately.

---

## Troubleshooting matrix

| Symptom | Likely cause | Fix |
|---------|----------------|-----|
| Admin says Supabase not configured | Missing or wrong `VITE_*` in **GitHub Secrets**; build not redeployed | **`docs/SUPABASE_COPY_THESE_TWO_VALUES.md`**, re-run Actions |
| “dashboard” / wrong host in console | Pasted **Supabase UI** URL instead of **Project URL** | Use `https://<ref>.supabase.co` only |
| Google login 404 | Redirect URL mismatch | **`docs/SUPABASE_FIRST_TIME_SETUP.md`** — Site URL + Redirect URLs |
| Buy button errors: “not configured” | No Supabase in build | Same as row 1 |
| “No checkout URL” / invoke fails | Function not deployed or wrong project | Deploy `create-checkout-session`; check Supabase project |
| JSON error body from function | Missing `STRIPE_SECRET_KEY`, `SITE_URL`, or `SUPABASE_SERVICE_ROLE_KEY` | Edge Function secrets |
| Stripe redirect to wrong domain / 404 | **`SITE_URL`** wrong (missing repo path, trailing slash, `http` vs `https`) | Match how users open the live site |
| “amount_cents must be between …” | Below Stripe minimum or below admin minimum | Raise amount or lower admin min (still ≥ 50 cents) |
| “Game not for sale” | `pricing_model` free or unpublished | Admin → Pricing + Published |
| Charges in Test but you expected Live | Using `sk_test_` | Switch to live keys when ready (and rotate secrets) |

---

## Code map (commented sources)

| File | Notes |
|------|--------|
| `supabase/functions/create-checkout-session/index.ts` | Server: Stripe + DB read + URL building |
| `src/lib/stripeCheckout.ts` | Client: `functions.invoke`, error order |
| `src/lib/gamePricing.ts` | Labels, min cents, “should we show internal checkout?” |
| `src/components/GamePurchaseBlock.tsx` | UI: external link vs invoke |
| `src/lib/supabaseHealth.ts` | **Same URL rules** as you should use for `VITE_SUPABASE_URL` |
| `src/pages/AdminPage.tsx` | Pricing fields persisted to `site_games` |
| `docs/SUPABASE_COPY_THESE_TWO_VALUES.md` | Dashboard layout / Project ID → URL |

---

## Legal

- **`/#/purchase/terms`** — short digital-goods copy; not legal advice.
- Business, tax, and refund policies: configure in **Stripe** and your support pages to match reality.

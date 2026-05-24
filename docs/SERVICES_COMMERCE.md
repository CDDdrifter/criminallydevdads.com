# Services, gigs & Stripe — setup guide

Sell tips, game demos, commissions, websites, apps, and merch from **`/#/services`**.

## 1. Run SQL (once)

In Supabase **SQL Editor**, run:

`supabase/migrations/025_site_services_commerce.sql`

This creates:

- `site_services` — your catalog (editable in **Admin → Services**)
- `site_service_requests` — customer emails / project briefs
- Starter rows (coffee, custom tip, game demo, full game, assets, web, app, merch)

Also run **024** if you have not (analytics lists).

## 2. Edit offerings (no code)

**Admin → Services**

- Change **title, tagline, description, features** (exact copy you want)
- **Pricing model:**
  - **Quote only** — request form, no Stripe
  - **Fixed** — one price via Stripe
  - **PWYW / Donation** — customer picks amount (presets for coffee)
  - **External URL** — Stripe Payment Link, Gumroad, Printful store, etc.
- **Request only** — hides checkout, keeps email form
- **Published** + **Show on /services**

Save each row. Public page updates after deploy (CMS is live in Supabase).

## 3. When you set up Stripe

Same secrets as games — see **`docs/STRIPE_CHECKOUT.md`**:

| Secret | Where |
|--------|--------|
| `STRIPE_SECRET_KEY` | Supabase → Edge Functions → Secrets |
| `SITE_URL` | Same (your public hub root, no trailing slash) |
| `SUPABASE_SERVICE_ROLE_KEY` | Same |

Redeploy the Edge Function after code changes:

```bash
supabase functions deploy create-checkout-session
```

The function accepts:

- `{ "game_slug": "…" }` — games (unchanged)
- `{ "service_slug": "…", "amount_cents": 500 }` — services / tips

No new GitHub secrets.

## 4. What customers see

- **Nav:** 💼 Services (toggle in **Behavior** studio)
- **Page:** `https://yourdomain.com/#/services`
- **Quote gigs:** expand card → fill request form → you see it in **Admin → Services → Inbound requests**
- **Paid:** Stripe Checkout → `/#/purchase/success`

## 5. Games + site copy (still available)

| Sell | Where |
|------|--------|
| Playable games | Admin → Games (ZIP + pricing) |
| Homepage donate | Admin → Site copy → Stripe donation URL |
| Custom CMS page | Admin → Pages (or Hire Us template) |
| Block pricing tables | Page block composer |

## 6. Optional: merch row

Edit the **merch** service: set **External checkout URL** to your Stripe Product / Gumroad / Printful link.

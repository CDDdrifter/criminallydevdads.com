# Stripe Setup (Donations now, paid assets later)

This repo is now wired so Admin can store:

- `Site settings → Stripe donation URL`
- `Games → Asset price / checkout URL / stripe price id`

For now, checkout is link-based (Stripe Payment Links). That is the fastest stable path.

## 1) Stripe dashboard steps (your side)

1. Create a Stripe account and complete business verification.
2. In Stripe, create a **Payment Link** for donations:
   - Use "customer chooses amount" if available in your region/account type.
   - Copy the `https://buy.stripe.com/...` URL.
3. (Optional) Create product + price for each asset pack.
   - You can also create one payment link per asset and paste that URL into Admin.

## 2) Website admin steps

1. Open `/#/admin` → `settings`.
2. Paste donation link into **Stripe donation URL**.
3. In **Bottom support buttons**, keep/add a Donate button.
   - If button id is `donate`, the site auto-uses Stripe donation URL.
4. For each paid asset: `admin` → `games`:
   - set type `asset`
   - set `Asset price (USD)`
   - paste `Checkout URL` (Stripe payment link)
   - optional: set `Stripe Price ID` for future API checkout.

## 3) Supabase migration required

Run:

- `supabase/migrations/008_commerce_and_support_buttons.sql`

This adds commerce + support button columns used by the UI.

## 4) Future upgrade path (API checkout)

When you want stronger flows (promo codes, webhooks, entitlements, receipts):

- add a Supabase Edge Function to create Stripe Checkout sessions with secret key
- store `stripe_price_id` per asset
- add webhook endpoint for post-payment fulfillment.

Link-based checkout is good enough now and keeps risk low while you ship games.

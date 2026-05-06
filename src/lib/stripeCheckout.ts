/**
 * Client-side bridge to Supabase Edge Function `create-checkout-session`.
 *
 * FLOW
 * ----
 * 1. User clicks Buy on `GamePurchaseBlock`.
 * 2. We call `supabase.functions.invoke` with the **anon** key (buyers are not logged in).
 * 3. Edge Function validates `site_games` with **service_role**, creates Stripe session, returns `{ url }`.
 * 4. We `window.location.href = url` to Stripe’s hosted checkout.
 *
 * ERROR HANDLING
 * --------------
 * Supabase may return a 4xx body with `{ error: "..." }` in `data` while also setting `error`.
 * We read **`data.error` first** so the user sees the server message (e.g. amount validation),
 * not a generic Functions error.
 *
 * REQUIRES
 * --------
 * - `VITE_SUPABASE_*` baked into this build (same project where the function is deployed).
 * - Function deployed + secrets set — see docs/STRIPE_CHECKOUT.md.
 */
import { supabase, supabaseConfigured } from './supabase';

export async function startGameCheckout(args: { slug: string; amountCents?: number }): Promise<void> {
  if (!supabaseConfigured || !supabase) {
    throw new Error('Supabase is not configured (needed for checkout).');
  }
  const { data, error } = await supabase.functions.invoke<{ url?: string; error?: string }>(
    'create-checkout-session',
    { body: { game_slug: args.slug, amount_cents: args.amountCents } },
  );
  if (data && typeof data.error === 'string' && data.error) {
    throw new Error(data.error);
  }
  if (error) {
    throw new Error(error.message ?? 'Checkout request failed');
  }
  const url = data?.url;
  if (!url || typeof url !== 'string') {
    throw new Error('Checkout did not return a URL. Is create-checkout-session deployed?');
  }
  window.location.href = url;
}

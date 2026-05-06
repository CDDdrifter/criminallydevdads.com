/**
 * Commerce display + gating helpers (no network calls).
 *
 * SOURCE OF TRUTH
 * ---------------
 * Admin + DB: `site_games` columns documented on `GameRecord` / `GameView` in `src/types.ts`.
 * Server enforcement: `supabase/functions/create-checkout-session` (amount floors, published check).
 *
 * STRIPE MINIMUM
 * --------------
 * `stripeMinimumUsdCents()` must match Edge Function `MIN_USD_CENTS` (50) so the UI never suggests
 * an amount the server will reject.
 *
 * EXTERNAL VS INTERNAL CHECKOUT
 * -----------------------------
 * `purchase_url` on a game means “open this link” (itch, Gumroad, Stripe Payment Link). When set,
 * `gameOffersInternalCheckout` is false so we don’t double-offer Stripe.
 */
import type { GamePricingModel, GameView } from '../types';

/** Maps DB/JSON string to enum; infers `fixed` when legacy row has price but model still `free`. */
export function gamePricingModelFromRecord(raw: unknown, priceCents: number): GamePricingModel {
  const m = String(raw ?? 'free').toLowerCase();
  if (m === 'fixed' || m === 'pwyw' || m === 'donation') {
    return m;
  }
  return priceCents > 0 ? 'fixed' : 'free';
}

/** Normalizes jsonb / odd JSON into sorted unique positive cent amounts. */
export function donationPresetsFromUnknown(raw: unknown): number[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out = raw
    .map((x) => Math.round(Number(x)))
    .filter((n) => Number.isFinite(n) && n > 0);
  return [...new Set(out)].sort((a, b) => a - b);
}

/** Subtitle / badge text on game detail and buy buttons (not the Stripe line item name). */
export function formatGamePriceLabel(game: GameView): string {
  switch (game.pricing_model) {
    case 'fixed':
      if (game.price_cents > 0) {
        return `$${(game.price_cents / 100).toFixed(2)}`;
      }
      return game.stripe_price_id ? 'Paid (Stripe)' : 'Free';
    case 'pwyw':
      if (game.pwyw_min_cents > 0) {
        return `Pay what you want ($${(game.pwyw_min_cents / 100).toFixed(2)} min)`;
      }
      return 'Pay what you want';
    case 'donation':
      return 'Donation / support';
    default:
      return game.price_cents > 0 ? `$${(game.price_cents / 100).toFixed(2)}` : 'Free';
  }
}

/**
 * Whether `GamePurchaseBlock` should show built-in checkout (Stripe via Edge Function).
 * Fixed needs either >= $0.50 ad-hoc price or a Dashboard Price ID.
 */
export function gameOffersInternalCheckout(game: GameView): boolean {
  if (game.purchase_url.trim()) {
    return false;
  }
  if (game.pricing_model === 'pwyw' || game.pricing_model === 'donation') {
    return true;
  }
  if (game.pricing_model === 'fixed') {
    return game.price_cents >= 50 || Boolean(game.stripe_price_id.trim());
  }
  return false;
}

export function stripeMinimumUsdCents(): number {
  return 50;
}

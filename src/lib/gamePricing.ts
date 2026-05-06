import type { GamePricingModel, GameView } from '../types';

export function gamePricingModelFromRecord(raw: unknown, priceCents: number): GamePricingModel {
  const m = String(raw ?? 'free').toLowerCase();
  if (m === 'fixed' || m === 'pwyw' || m === 'donation') {
    return m;
  }
  return priceCents > 0 ? 'fixed' : 'free';
}

export function donationPresetsFromUnknown(raw: unknown): number[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out = raw
    .map((x) => Math.round(Number(x)))
    .filter((n) => Number.isFinite(n) && n > 0);
  return [...new Set(out)].sort((a, b) => a - b);
}

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

/** Built-in Stripe Checkout (Edge Function) — not external purchase_url. */
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

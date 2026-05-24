/**
 * Service / gig commerce helpers (mirrors gamePricing.ts).
 */
import type { ServicePricingModel, ServiceView } from '../types';
import { donationPresetsFromUnknown, stripeMinimumUsdCents } from './gamePricing';

export { donationPresetsFromUnknown, stripeMinimumUsdCents };

export function servicePricingModelFromRecord(raw: unknown, priceCents: number): ServicePricingModel {
  const m = String(raw ?? 'quote').toLowerCase();
  if (m === 'quote') return 'quote';
  if (m === 'fixed' || m === 'pwyw' || m === 'donation' || m === 'free') {
    return m;
  }
  return priceCents > 0 ? 'fixed' : 'quote';
}

export function formatServicePriceLabel(service: ServiceView): string {
  switch (service.pricing_model) {
    case 'quote':
      return 'Custom quote';
    case 'fixed':
      if (service.price_cents > 0) {
        return `$${(service.price_cents / 100).toFixed(2)}`;
      }
      return service.stripe_price_id ? 'Paid (Stripe)' : 'Contact for price';
    case 'pwyw':
      if (service.pwyw_min_cents > 0) {
        return `From $${(service.pwyw_min_cents / 100).toFixed(2)}`;
      }
      return 'Pay what you want';
    case 'donation':
      return 'Tip / support';
    default:
      return 'Free';
  }
}

export function serviceOffersInternalCheckout(service: ServiceView): boolean {
  if (service.request_only || service.pricing_model === 'quote') {
    return false;
  }
  if (service.gumroad_url.trim() || service.purchase_url.trim()) {
    return false;
  }
  if (service.pricing_model === 'pwyw' || service.pricing_model === 'donation') {
    return true;
  }
  if (service.pricing_model === 'fixed') {
    return service.price_cents >= 50 || Boolean(service.stripe_price_id.trim());
  }
  return false;
}

export function serviceExternalStoreUrl(service: ServiceView): string {
  return (service.gumroad_url?.trim() || service.purchase_url?.trim() || '').trim();
}

export function serviceCategoryLabel(category: string): string {
  const map: Record<string, string> = {
    game_dev: 'Game development',
    asset: 'Assets & art',
    web: 'Websites',
    app: 'Apps & tools',
    merch: 'Merch',
    support: 'Tips & support',
    other: 'More',
  };
  return map[category] ?? category;
}

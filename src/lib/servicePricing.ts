/**
 * Service / gig commerce helpers (mirrors gamePricing.ts).
 */
import type { ProductType, ServicePricingModel, ServiceView, VariantGroup, VariantOption } from '../types';
import { donationPresetsFromUnknown, stripeMinimumUsdCents } from './gamePricing';

export { donationPresetsFromUnknown, stripeMinimumUsdCents };

/** Map of variant group id -> chosen option id. */
export type VariantSelection = Record<string, string>;

/** Parse untrusted JSONB into a typed VariantGroup[] (drops malformed rows). */
export function normalizeVariantGroups(raw: unknown): VariantGroup[] {
  if (!Array.isArray(raw)) return [];
  const groups: VariantGroup[] = [];
  for (const g of raw) {
    if (!g || typeof g !== 'object') continue;
    const rec = g as Record<string, unknown>;
    const id = String(rec.id ?? '').trim() || `grp-${groups.length + 1}`;
    const name = String(rec.name ?? '').trim();
    const optionsRaw = Array.isArray(rec.options) ? rec.options : [];
    const options: VariantOption[] = [];
    for (const o of optionsRaw) {
      if (!o || typeof o !== 'object') continue;
      const orec = o as Record<string, unknown>;
      const oid = String(orec.id ?? '').trim() || `opt-${options.length + 1}`;
      const label = String(orec.label ?? '').trim();
      if (!label) continue;
      options.push({
        id: oid,
        label,
        price_delta_cents: Math.round(Number(orec.price_delta_cents ?? 0)) || 0,
        sku: orec.sku != null ? String(orec.sku) : undefined,
      });
    }
    if (!name && options.length === 0) continue;
    groups.push({ id, name: name || 'Option', options });
  }
  return groups;
}

export function normalizeProductType(raw: unknown): ProductType {
  const v = String(raw ?? 'service').toLowerCase();
  return v === 'physical' || v === 'digital' ? v : 'service';
}

/** Resolve the default selection (first option of each group). */
export function defaultVariantSelection(groups: VariantGroup[]): VariantSelection {
  const sel: VariantSelection = {};
  for (const g of groups) {
    if (g.options[0]) sel[g.id] = g.options[0].id;
  }
  return sel;
}

/** Sum the price deltas for a given selection. */
export function variantPriceDeltaCents(groups: VariantGroup[], selection: VariantSelection): number {
  let delta = 0;
  for (const g of groups) {
    const chosen = selection[g.id];
    const opt = g.options.find((o) => o.id === chosen);
    if (opt) delta += opt.price_delta_cents;
  }
  return delta;
}

/** Human-readable variant suffix, e.g. "Size: L · Color: Red". */
export function variantSelectionLabel(groups: VariantGroup[], selection: VariantSelection): string {
  const parts: string[] = [];
  for (const g of groups) {
    const opt = g.options.find((o) => o.id === selection[g.id]);
    if (opt) parts.push(`${g.name}: ${opt.label}`);
  }
  return parts.join(' · ');
}

/** Effective unit price for a fixed-price product given a variant selection. */
export function effectiveUnitPriceCents(service: ServiceView, selection: VariantSelection): number {
  return Math.max(0, service.price_cents + variantPriceDeltaCents(service.variant_groups, selection));
}

export function servicePricingModelFromRecord(raw: unknown, priceCents: number): ServicePricingModel {
  const m = String(raw ?? 'quote').toLowerCase();
  if (m === 'quote') return 'quote';
  if (m === 'donation') {
    return 'tip';
  }
  if (m === 'fixed' || m === 'pwyw' || m === 'tip' || m === 'free') {
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
    case 'tip':
      return 'Tip the devs';
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
  if (service.pricing_model === 'pwyw' || service.pricing_model === 'tip') {
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

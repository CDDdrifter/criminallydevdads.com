/**
 * CMS: sellable services / gigs (migration 025).
 */
import type { ServicePricingModel, ServiceView, SiteService } from '../types';
import { donationPresetsFromUnknown } from './gamePricing';
import {
  normalizeProductType,
  normalizeVariantGroups,
  servicePricingModelFromRecord,
} from './servicePricing';
import { supabase, supabaseConfigured } from './supabase';
import { unknownColumnFromPostgrestMessage } from './postgrestUnknownColumn';

function normalizeService(row: Record<string, unknown>): SiteService {
  const features = row.features;
  return {
    slug: String(row.slug ?? ''),
    title: String(row.title ?? ''),
    tagline: String(row.tagline ?? ''),
    description: String(row.description ?? ''),
    category: String(row.category ?? 'other'),
    kind: String(row.kind ?? 'service'),
    icon_emoji: String(row.icon_emoji ?? '✨'),
    image_url: String(row.image_url ?? ''),
    features: Array.isArray(features)
      ? features.map((x) => String(x)).filter(Boolean)
      : [],
    deliverables: String(row.deliverables ?? ''),
    turnaround: String(row.turnaround ?? ''),
    pricing_model: String(row.pricing_model ?? 'quote'),
    price_cents: row.price_cents != null ? Number(row.price_cents) : null,
    stripe_price_id: row.stripe_price_id != null ? String(row.stripe_price_id) : null,
    purchase_url: row.purchase_url != null ? String(row.purchase_url) : null,
    gumroad_url: row.gumroad_url != null ? String(row.gumroad_url) : null,
    pwyw_min_cents: row.pwyw_min_cents != null ? Number(row.pwyw_min_cents) : null,
    pwyw_suggested_cents: row.pwyw_suggested_cents != null ? Number(row.pwyw_suggested_cents) : null,
    donation_presets_cents: donationPresetsFromUnknown(row.donation_presets_cents),
    cta_label: String(row.cta_label ?? 'Get started'),
    request_only: Boolean(row.request_only),
    request_form_enabled: row.request_form_enabled !== false,
    published: row.published !== false,
    show_on_services_hub: row.show_on_services_hub !== false,
    sort_order: Number(row.sort_order ?? 0),
    product_type: normalizeProductType(row.product_type),
    variant_groups: normalizeVariantGroups(row.variant_groups),
    requires_shipping: Boolean(row.requires_shipping),
    allow_quantity: Boolean(row.allow_quantity),
    max_quantity: Math.max(1, Math.round(Number(row.max_quantity ?? 1)) || 1),
  };
}

export function serviceToView(s: SiteService): ServiceView {
  const price_cents = Number(s.price_cents ?? 0);
  return {
    slug: s.slug,
    title: s.title,
    tagline: s.tagline,
    description: s.description,
    category: s.category,
    kind: s.kind,
    icon_emoji: s.icon_emoji,
    image_url: s.image_url,
    features: s.features,
    deliverables: s.deliverables,
    turnaround: s.turnaround,
    pricing_model: servicePricingModelFromRecord(s.pricing_model, price_cents),
    price_cents,
    purchase_url: s.purchase_url?.trim() ?? '',
    gumroad_url: s.gumroad_url?.trim() ?? '',
    stripe_price_id: s.stripe_price_id?.trim() ?? '',
    pwyw_min_cents: Number(s.pwyw_min_cents ?? 0),
    pwyw_suggested_cents: Number(s.pwyw_suggested_cents ?? 0),
    donation_presets_cents: s.donation_presets_cents ?? [],
    cta_label: s.cta_label,
    request_only: s.request_only,
    request_form_enabled: s.request_form_enabled,
    product_type: normalizeProductType(s.product_type),
    variant_groups: normalizeVariantGroups(s.variant_groups),
    requires_shipping: Boolean(s.requires_shipping),
    allow_quantity: Boolean(s.allow_quantity),
    max_quantity: Math.max(1, Math.round(Number(s.max_quantity ?? 1)) || 1),
  };
}

export async function fetchPublishedServices(): Promise<ServiceView[]> {
  if (!supabaseConfigured || !supabase) return [];
  const { data, error } = await supabase
    .from('site_services')
    .select('*')
    .eq('published', true)
    .eq('show_on_services_hub', true)
    .order('sort_order', { ascending: true });
  if (error) {
    console.warn('[services] fetch', error.message);
    return [];
  }
  return (data ?? []).map((row) => serviceToView(normalizeService(row as Record<string, unknown>)));
}

export async function fetchServiceBySlug(slug: string): Promise<ServiceView | null> {
  if (!supabaseConfigured || !supabase) return null;
  const { data, error } = await supabase
    .from('site_services')
    .select('*')
    .eq('slug', slug)
    .eq('published', true)
    .maybeSingle();
  if (error || !data) return null;
  return serviceToView(normalizeService(data as Record<string, unknown>));
}

export async function fetchAllServicesAdmin(): Promise<SiteService[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.from('site_services').select('*').order('sort_order');
  if (error) {
    console.error('[services] admin', error);
    return [];
  }
  return (data ?? []).map((row) => normalizeService(row as Record<string, unknown>));
}

export async function upsertService(row: Partial<SiteService> & { slug: string; title: string }) {
  if (!supabase) throw new Error('Supabase not configured');
  const payload: Record<string, unknown> = {
    ...row,
    updated_at: new Date().toISOString(),
    donation_presets_cents: row.donation_presets_cents ?? [],
    features: row.features ?? [],
  };
  for (let attempt = 0; attempt < 16; attempt++) {
    const { error } = await supabase.from('site_services').upsert(payload, { onConflict: 'slug' });
    if (!error) return;
    const unknown = unknownColumnFromPostgrestMessage(error.message ?? '');
    if (!unknown || !(unknown in payload)) throw error;
    delete payload[unknown];
  }
  throw new Error('Could not save service (run migration 025).');
}

export async function deleteServiceSlug(slug: string) {
  if (!supabase) throw new Error('Supabase not configured');
  const { error } = await supabase.from('site_services').delete().eq('slug', slug);
  if (error) throw error;
}

export const SERVICE_CATEGORY_OPTIONS = [
  { value: 'game_dev', label: '🎮 Game development' },
  { value: 'asset', label: '🎨 Assets & art' },
  { value: 'web', label: '🌐 Websites' },
  { value: 'app', label: '⚡ Apps & tools' },
  { value: 'merch', label: '👕 Merch' },
  { value: 'support', label: '☕ Tips & support' },
  { value: 'other', label: '✨ Other' },
] as const;

export const SERVICE_KIND_OPTIONS = [
  { value: 'service', label: 'Service / gig' },
  { value: 'product', label: 'Product' },
  { value: 'tip', label: 'Tip / coffee' },
  { value: 'deposit', label: 'Deposit / partial pay' },
] as const;

export const SERVICE_PRICING_OPTIONS: { value: ServicePricingModel; label: string }[] = [
  { value: 'quote', label: 'Quote only (request form)' },
  { value: 'free', label: 'Free label (no checkout)' },
  { value: 'fixed', label: 'Fixed price — Stripe' },
  { value: 'pwyw', label: 'Pay what you want — Stripe' },
  { value: 'donation', label: 'Donation / tip presets — Stripe' },
];

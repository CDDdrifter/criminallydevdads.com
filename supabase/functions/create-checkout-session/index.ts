/**
 * create-checkout-session — Stripe Checkout for games OR services (migration 025 + 029).
 *
 * POST JSON (one of):
 *   { "game_slug": string, "amount_cents"?: number }
 *   { "service_slug": string, "amount_cents"?: number, "quantity"?: number,
 *     "variant_selection"?: { [groupId]: optionId } }
 *
 * For fixed-price services the server recomputes the unit price from
 * `price_cents` + the chosen variant deltas (never trusts a client price), then
 * multiplies by a clamped quantity. Physical products with shipping enabled add
 * Stripe `shipping_address_collection` + flat-rate `shipping_options` from
 * `site_settings.shipping`.
 *
 * Secrets: STRIPE_SECRET_KEY, SITE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL
 * See docs/STRIPE_CHECKOUT.md and docs/SERVICES_COMMERCE.md
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MIN_USD_CENTS = 50;
const MAX_USD_CENTS = 999_999_00;

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function normalizeSupabaseApiOrigin(raw: string): string {
  const t = raw.trim().replace(/\/$/, '');
  try {
    const u = new URL(t);
    if (u.protocol === 'https:' && u.hostname.endsWith('.supabase.co')) {
      return `https://${u.hostname}`;
    }
  } catch {
    return t;
  }
  return t;
}

type VariantOption = { id: string; label: string; price_delta_cents: number; sku?: string };
type VariantGroup = { id: string; name: string; options: VariantOption[] };

type CommerceRow = {
  slug: string;
  title: string;
  published: boolean;
  pricing_model: string;
  price_cents: number | null;
  purchase_url: string | null;
  gumroad_url: string | null;
  stripe_price_id: string | null;
  pwyw_min_cents: number | null;
  request_only?: boolean | null;
  // Store (migration 029) — services only.
  product_type?: string | null;
  variant_groups?: unknown;
  requires_shipping?: boolean | null;
  allow_quantity?: boolean | null;
  max_quantity?: number | null;
};

type ShippingRate = { id: string; label: string; amount_cents: number; delivery_estimate?: string };
type ShippingConfig = { enabled: boolean; allowed_countries: string[]; rates: ShippingRate[] };

type CheckoutExtras = {
  quantity?: number;
  variantSelection?: Record<string, string>;
  shipping?: ShippingConfig | null;
};

function parseVariantGroups(raw: unknown): VariantGroup[] {
  if (!Array.isArray(raw)) return [];
  const out: VariantGroup[] = [];
  for (const g of raw) {
    if (!g || typeof g !== 'object') continue;
    const rec = g as Record<string, unknown>;
    const options: VariantOption[] = Array.isArray(rec.options)
      ? (rec.options as unknown[])
          .map((o) => {
            if (!o || typeof o !== 'object') return null;
            const orec = o as Record<string, unknown>;
            const label = String(orec.label ?? '').trim();
            if (!label) return null;
            return {
              id: String(orec.id ?? '').trim(),
              label,
              price_delta_cents: Math.round(Number(orec.price_delta_cents ?? 0)) || 0,
              sku: orec.sku != null ? String(orec.sku) : undefined,
            } as VariantOption;
          })
          .filter((x): x is VariantOption => x !== null)
      : [];
    out.push({ id: String(rec.id ?? '').trim(), name: String(rec.name ?? 'Option'), options });
  }
  return out;
}

/** Sum variant deltas for a selection; ignores unknown ids. */
function variantDeltaCents(groups: VariantGroup[], selection: Record<string, string>): number {
  let delta = 0;
  for (const g of groups) {
    const opt = g.options.find((o) => o.id === selection[g.id]);
    if (opt) delta += opt.price_delta_cents;
  }
  return delta;
}

function variantLabel(groups: VariantGroup[], selection: Record<string, string>): string {
  const parts: string[] = [];
  for (const g of groups) {
    const opt = g.options.find((o) => o.id === selection[g.id]);
    if (opt) parts.push(`${g.name}: ${opt.label}`);
  }
  return parts.join(' · ');
}

function effectiveModel(row: CommerceRow): string {
  const m = String(row.pricing_model ?? 'free').toLowerCase();
  if (m === 'quote' || row.request_only) {
    return 'quote';
  }
  if (m === 'free' && Number(row.price_cents ?? 0) > 0) {
    return 'fixed';
  }
  return m;
}

function floorCents(row: CommerceRow, model: string): number {
  const configured = Number(row.pwyw_min_cents ?? 0);
  if (model === 'donation' || model === 'pwyw') {
    return Math.max(MIN_USD_CENTS, configured);
  }
  return MIN_USD_CENTS;
}

async function stripeCreateCheckoutSession(body: URLSearchParams): Promise<{ url: string }> {
  const key = Deno.env.get('STRIPE_SECRET_KEY');
  if (!key?.trim()) {
    throw new Error('STRIPE_SECRET_KEY is not configured for this project');
  }
  const res = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Stripe ${res.status}: ${t}`);
  }
  const data = (await res.json()) as { url?: string };
  if (!data.url) {
    throw new Error('Stripe returned no checkout URL');
  }
  return { url: data.url };
}

/** Attach shipping address collection + flat-rate options for physical goods. */
function applyShipping(params: URLSearchParams, row: CommerceRow, extras: CheckoutExtras): void {
  const ship = extras.shipping;
  if (!row.requires_shipping || !ship || !ship.enabled) return;
  const countries = (ship.allowed_countries ?? []).filter((c) => /^[A-Z]{2}$/.test(c));
  const list = countries.length ? countries : ['US'];
  list.forEach((c, i) => params.append(`shipping_address_collection[allowed_countries][${i}]`, c));
  (ship.rates ?? []).slice(0, 5).forEach((rate, i) => {
    params.append(`shipping_options[${i}][shipping_rate_data][type]`, 'fixed_amount');
    params.append(`shipping_options[${i}][shipping_rate_data][fixed_amount][amount]`, String(Math.max(0, Math.round(rate.amount_cents))));
    params.append(`shipping_options[${i}][shipping_rate_data][fixed_amount][currency]`, 'usd');
    params.append(`shipping_options[${i}][shipping_rate_data][display_name]`, String(rate.label ?? 'Shipping').slice(0, 100));
  });
}

async function buildCheckout(
  row: CommerceRow,
  kind: 'game' | 'service',
  amountCents: number | undefined,
  siteUrl: string,
  extras: CheckoutExtras = {},
): Promise<{ url: string }> {
  const slug = row.slug;
  if (String(row.gumroad_url ?? '').trim() || String(row.purchase_url ?? '').trim()) {
    throw new Error('This item uses an external store URL');
  }

  const model = effectiveModel(row);
  if (model === 'free' || model === 'quote') {
    throw new Error('This item is not available for checkout');
  }

  const title = String(row.title ?? slug).slice(0, 120);
  const successUrl = `${siteUrl}/#/purchase/success?session_id={CHECKOUT_SESSION_ID}&kind=${kind}&slug=${encodeURIComponent(slug)}`;
  const cancelUrl =
    kind === 'service'
      ? `${siteUrl}/#/services`
      : `${siteUrl}/#/game/${encodeURIComponent(slug)}`;

  const metaKey = kind === 'service' ? 'service_slug' : 'game_slug';

  // Clamp quantity to [1, max_quantity] (only when the row opts into quantity).
  const allowQty = kind === 'service' && Boolean(row.allow_quantity);
  const maxQty = Math.max(1, Math.round(Number(row.max_quantity ?? 1)) || 1);
  const reqQty = Math.round(Number(extras.quantity ?? 1)) || 1;
  const quantity = allowQty ? Math.min(maxQty, Math.max(1, reqQty)) : 1;

  // Variant selection → server-side price delta (never trust the client).
  const groups = kind === 'service' ? parseVariantGroups(row.variant_groups) : [];
  const selection = extras.variantSelection ?? {};
  const variantDelta = variantDeltaCents(groups, selection);
  const variantText = variantLabel(groups, selection);

  if (model === 'fixed') {
    const priceId = String(row.stripe_price_id ?? '').trim();
    const baseUnit = Math.round(Number(row.price_cents ?? 0));
    // A Stripe Price ID is a fixed catalog price → variant deltas don't apply.
    const useDynamic = !priceId || variantDelta !== 0;
    const unit = Math.max(0, baseUnit + variantDelta);
    if (useDynamic && unit < MIN_USD_CENTS) {
      throw new Error('Price must be at least $0.50 or use a Stripe Price ID');
    }

    const params = new URLSearchParams();
    params.set('mode', 'payment');
    params.set('success_url', successUrl);
    params.set('cancel_url', cancelUrl);
    params.append(`metadata[${metaKey}]`, slug);
    params.append('metadata[pricing_model]', 'fixed');
    params.append('metadata[item_kind]', kind);
    if (quantity > 1) params.append('metadata[quantity]', String(quantity));
    if (variantText) params.append('metadata[variant]', variantText.slice(0, 480));
    if (priceId && !useDynamic) {
      params.append('line_items[0][price]', priceId);
      params.append('line_items[0][quantity]', String(quantity));
    } else {
      const name = variantText ? `${title} — ${variantText}`.slice(0, 250) : title;
      params.append('line_items[0][quantity]', String(quantity));
      params.append('line_items[0][price_data][currency]', 'usd');
      params.append('line_items[0][price_data][unit_amount]', String(unit));
      params.append('line_items[0][price_data][product_data][name]', name);
    }
    applyShipping(params, row, extras);
    return stripeCreateCheckoutSession(params);
  }

  if (model !== 'pwyw' && model !== 'donation') {
    throw new Error('Unsupported pricing_model');
  }

  const amount = typeof amountCents === 'number' ? Math.round(amountCents) : NaN;
  if (!Number.isFinite(amount)) {
    throw new Error('amount_cents required for this pricing type');
  }

  const floor = floorCents(row, model);
  if (amount < floor || amount > MAX_USD_CENTS) {
    throw new Error(`amount_cents must be between ${floor} and ${MAX_USD_CENTS}`);
  }

  const params = new URLSearchParams();
  params.set('mode', 'payment');
  params.set('success_url', successUrl);
  params.set('cancel_url', cancelUrl);
  params.append(`metadata[${metaKey}]`, slug);
  params.append('metadata[pricing_model]', model);
  params.append('metadata[item_kind]', kind);
  params.append('line_items[0][quantity]', '1');
  params.append('line_items[0][price_data][currency]', 'usd');
  params.append('line_items[0][price_data][unit_amount]', String(amount));
  const lineName = model === 'donation' ? `${title} — support` : `${title} — pay what you want`;
  params.append('line_items[0][price_data][product_data][name]', lineName.slice(0, 120));

  return stripeCreateCheckoutSession(params);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Use POST' }, 405);
  }

  try {
    const siteUrl = (Deno.env.get('SITE_URL') ?? '').trim().replace(/\/$/, '');
    if (!siteUrl) {
      return jsonResponse({ error: 'SITE_URL secret is not set (public site base, no trailing slash)' }, 500);
    }

    const supabaseUrl = normalizeSupabaseApiOrigin(Deno.env.get('SUPABASE_URL') ?? '');
    const serviceKey = (Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '').trim();
    if (!supabaseUrl || !serviceKey) {
      return jsonResponse({
        error: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be available to create-checkout-session',
      }, 500);
    }

    const payload = (await req.json().catch(() => ({}))) as {
      game_slug?: string;
      service_slug?: string;
      amount_cents?: number;
      quantity?: number;
      variant_selection?: Record<string, string>;
    };

    const gameSlug = String(payload.game_slug ?? '').trim();
    const serviceSlug = String(payload.service_slug ?? '').trim();
    const variantSelection: Record<string, string> = {};
    if (payload.variant_selection && typeof payload.variant_selection === 'object') {
      for (const [k, v] of Object.entries(payload.variant_selection)) {
        variantSelection[String(k)] = String(v);
      }
    }
    if (Boolean(gameSlug) === Boolean(serviceSlug)) {
      return jsonResponse({ error: 'Provide exactly one of game_slug or service_slug' }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);

    if (serviceSlug) {
      if (!/^[a-z0-9][a-z0-9-]*$/i.test(serviceSlug)) {
        return jsonResponse({ error: 'Invalid service_slug' }, 400);
      }
      const { data: row, error: qErr } = await admin
        .from('site_services')
        .select(
          'slug,title,published,pricing_model,price_cents,purchase_url,gumroad_url,stripe_price_id,pwyw_min_cents,request_only,product_type,variant_groups,requires_shipping,allow_quantity,max_quantity',
        )
        .eq('slug', serviceSlug)
        .eq('published', true)
        .maybeSingle();

      if (qErr) {
        console.error(qErr);
        return jsonResponse({ error: 'Could not load service' }, 500);
      }
      if (!row) {
        return jsonResponse({ error: 'Service not found or not published' }, 404);
      }

      // Load site-wide shipping config only when the product needs it.
      let shipping: ShippingConfig | null = null;
      if ((row as CommerceRow).requires_shipping) {
        const { data: settingsRow } = await admin
          .from('site_settings')
          .select('shipping')
          .eq('id', 1)
          .maybeSingle();
        const raw = (settingsRow as { shipping?: unknown } | null)?.shipping;
        if (raw && typeof raw === 'object') {
          const s = raw as Record<string, unknown>;
          shipping = {
            enabled: Boolean(s.enabled),
            allowed_countries: Array.isArray(s.allowed_countries)
              ? s.allowed_countries.map((c) => String(c).toUpperCase())
              : ['US'],
            rates: Array.isArray(s.rates)
              ? (s.rates as unknown[])
                  .map((r) => {
                    if (!r || typeof r !== 'object') return null;
                    const rr = r as Record<string, unknown>;
                    const label = String(rr.label ?? '').trim();
                    if (!label) return null;
                    return {
                      id: String(rr.id ?? ''),
                      label,
                      amount_cents: Math.max(0, Math.round(Number(rr.amount_cents ?? 0)) || 0),
                    } as ShippingRate;
                  })
                  .filter((x): x is ShippingRate => x !== null)
              : [],
          };
        }
      }

      const { url } = await buildCheckout(row as CommerceRow, 'service', payload.amount_cents, siteUrl, {
        quantity: payload.quantity,
        variantSelection,
        shipping,
      });
      return jsonResponse({ url });
    }

    if (!/^[a-z0-9][a-z0-9-]*$/i.test(gameSlug)) {
      return jsonResponse({ error: 'Invalid game_slug' }, 400);
    }

    const { data: row, error: qErr } = await admin
      .from('site_games')
      .select(
        'slug,title,published,pricing_model,price_cents,purchase_url,gumroad_url,stripe_price_id,pwyw_min_cents,pwyw_suggested_cents',
      )
      .eq('slug', gameSlug)
      .eq('published', true)
      .maybeSingle();

    if (qErr) {
      console.error(qErr);
      return jsonResponse({ error: 'Could not load game' }, 500);
    }
    if (!row) {
      return jsonResponse({ error: 'Game not found or not published' }, 404);
    }

    const { url } = await buildCheckout(row as CommerceRow, 'game', payload.amount_cents, siteUrl);
    return jsonResponse({ url });
  } catch (e) {
    console.error(e);
    const msg = e instanceof Error ? e.message : 'Checkout failed';
    return jsonResponse({ error: msg }, 500);
  }
});

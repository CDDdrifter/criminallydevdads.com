/**
 * create-checkout-session — Stripe Checkout for games OR services (migration 025).
 *
 * POST JSON (one of):
 *   { "game_slug": string, "amount_cents"?: number }
 *   { "service_slug": string, "amount_cents"?: number }
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
};

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

async function buildCheckout(
  row: CommerceRow,
  kind: 'game' | 'service',
  amountCents: number | undefined,
  siteUrl: string,
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

  if (model === 'fixed') {
    const priceId = String(row.stripe_price_id ?? '').trim();
    const unit = Math.round(Number(row.price_cents ?? 0));
    if (!priceId && unit < MIN_USD_CENTS) {
      throw new Error('Fixed price must be at least $0.50 or use a Stripe Price ID');
    }

    const params = new URLSearchParams();
    params.set('mode', 'payment');
    params.set('success_url', successUrl);
    params.set('cancel_url', cancelUrl);
    params.append(`metadata[${metaKey}]`, slug);
    params.append('metadata[pricing_model]', 'fixed');
    params.append('metadata[item_kind]', kind);
    if (priceId) {
      params.append('line_items[0][price]', priceId);
      params.append('line_items[0][quantity]', '1');
    } else {
      params.append('line_items[0][quantity]', '1');
      params.append('line_items[0][price_data][currency]', 'usd');
      params.append('line_items[0][price_data][unit_amount]', String(unit));
      params.append('line_items[0][price_data][product_data][name]', title);
    }
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
    };

    const gameSlug = String(payload.game_slug ?? '').trim();
    const serviceSlug = String(payload.service_slug ?? '').trim();
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
          'slug,title,published,pricing_model,price_cents,purchase_url,gumroad_url,stripe_price_id,pwyw_min_cents,request_only',
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

      const { url } = await buildCheckout(row as CommerceRow, 'service', payload.amount_cents, siteUrl);
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

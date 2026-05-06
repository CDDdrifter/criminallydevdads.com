/**
 * Creates a Stripe Checkout Session for a published game (fixed, PWYW, or donation).
 *
 * POST JSON: { game_slug: string, amount_cents?: number }
 * - fixed: amount_cents ignored; uses price_cents or stripe_price_id
 * - pwyw | donation: amount_cents required (USD cents), validated against mins / Stripe limits
 *
 * Secrets: STRIPE_SECRET_KEY, SITE_URL (public site base, no trailing slash, e.g. https://user.github.io/repo)
 * Optional: SUPABASE_SERVICE_ROLE_KEY (required to read site_games); SUPABASE_URL auto in hosted functions
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

type GameRow = {
  slug: string;
  title: string;
  published: boolean;
  pricing_model: string;
  price_cents: number | null;
  purchase_url: string | null;
  stripe_price_id: string | null;
  pwyw_min_cents: number | null;
  pwyw_suggested_cents: number | null;
};

function effectiveModel(row: GameRow): string {
  const m = String(row.pricing_model ?? 'free').toLowerCase();
  if (m === 'free' && Number(row.price_cents ?? 0) > 0) {
    return 'fixed';
  }
  return m;
}

function floorCents(row: GameRow, model: string): number {
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

    const supabaseUrl = (Deno.env.get('SUPABASE_URL') ?? '').trim();
    const serviceKey = (Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '').trim();
    if (!supabaseUrl || !serviceKey) {
      return jsonResponse({
        error: 'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be available to create-checkout-session',
      }, 500);
    }

    const payload = (await req.json().catch(() => ({}))) as {
      game_slug?: string;
      amount_cents?: number;
    };
    const slug = String(payload.game_slug ?? '').trim();
    if (!slug || !/^[a-z0-9][a-z0-9-]*$/i.test(slug)) {
      return jsonResponse({ error: 'Invalid game_slug' }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: row, error: qErr } = await admin
      .from('site_games')
      .select(
        'slug,title,published,pricing_model,price_cents,purchase_url,stripe_price_id,pwyw_min_cents,pwyw_suggested_cents',
      )
      .eq('slug', slug)
      .eq('published', true)
      .maybeSingle();

    if (qErr) {
      console.error(qErr);
      return jsonResponse({ error: 'Could not load game' }, 500);
    }
    if (!row) {
      return jsonResponse({ error: 'Game not found or not published' }, 404);
    }

    const game = row as GameRow;
    if (String(game.purchase_url ?? '').trim()) {
      return jsonResponse({
        error: 'This game uses an external checkout URL; open it from the game page link instead',
      }, 400);
    }

    const model = effectiveModel(game);
    if (model === 'free') {
      return jsonResponse({ error: 'This game is not for sale' }, 400);
    }

    const title = String(game.title ?? slug).slice(0, 120);
    const successUrl = `${siteUrl}/#/purchase/success?session_id={CHECKOUT_SESSION_ID}`;
    const cancelUrl = `${siteUrl}/#/game/${encodeURIComponent(slug)}`;

    if (model === 'fixed') {
      const priceId = String(game.stripe_price_id ?? '').trim();
      const unit = Math.round(Number(game.price_cents ?? 0));
      if (!priceId && unit < MIN_USD_CENTS) {
        return jsonResponse({ error: 'Fixed price must be at least $0.50 or use a Stripe Price ID' }, 400);
      }

      const params = new URLSearchParams();
      params.set('mode', 'payment');
      params.set('success_url', successUrl);
      params.set('cancel_url', cancelUrl);
      params.append('metadata[game_slug]', slug);
      params.append('metadata[pricing_model]', 'fixed');
      if (priceId) {
        params.append('line_items[0][price]', priceId);
        params.append('line_items[0][quantity]', '1');
      } else {
        params.append('line_items[0][quantity]', '1');
        params.append('line_items[0][price_data][currency]', 'usd');
        params.append('line_items[0][price_data][unit_amount]', String(unit));
        params.append('line_items[0][price_data][product_data][name]', title);
      }

      const { url } = await stripeCreateCheckoutSession(params);
      return jsonResponse({ url });
    }

    if (model !== 'pwyw' && model !== 'donation') {
      return jsonResponse({ error: 'Unsupported pricing_model' }, 400);
    }

    const rawAmount = payload.amount_cents;
    const amount = typeof rawAmount === 'number' ? Math.round(rawAmount) : NaN;
    if (!Number.isFinite(amount)) {
      return jsonResponse({ error: 'amount_cents required for this pricing type' }, 400);
    }

    const floor = floorCents(game, model);
    if (amount < floor || amount > MAX_USD_CENTS) {
      return jsonResponse(
        {
          error: `amount_cents must be between ${floor} and ${MAX_USD_CENTS} for this game`,
        },
        400,
      );
    }

    const params = new URLSearchParams();
    params.set('mode', 'payment');
    params.set('success_url', successUrl);
    params.set('cancel_url', cancelUrl);
    params.append('metadata[game_slug]', slug);
    params.append('metadata[pricing_model]', model);
    params.append('line_items[0][quantity]', '1');
    params.append('line_items[0][price_data][currency]', 'usd');
    params.append('line_items[0][price_data][unit_amount]', String(amount));
    const lineName = model === 'donation' ? `${title} — support` : `${title} — pay what you want`;
    params.append('line_items[0][price_data][product_data][name]', lineName.slice(0, 120));

    const { url } = await stripeCreateCheckoutSession(params);
    return jsonResponse({ url });
  } catch (e) {
    console.error(e);
    const msg = e instanceof Error ? e.message : 'Checkout failed';
    return jsonResponse({ error: msg }, 500);
  }
});

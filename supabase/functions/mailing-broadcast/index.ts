/**
 * mailing-broadcast — Supabase Edge Function (Deno)
 *
 * Sends one email per opted-in subscriber via Resend (API key stays server-side).
 *
 * POST JSON: { "subject": string, "html": string, "text"?: string }
 *
 * Requires Authorization: Bearer <user JWT>. Caller must pass is_site_admin().
 *
 * Secrets (Supabase Dashboard → Edge Functions → Secrets):
 *   RESEND_API_KEY       — re_… from https://resend.com
 *   RESEND_FROM          — verified sender, e.g. "Criminally Dev Dads <hello@yourdomain.com>"
 *   SUPABASE_URL         — project API URL (often auto-set)
 *   SUPABASE_ANON_KEY    — anon key (auto-set)
 *
 * Optional:
 *   MAILING_BROADCAST_DELAY_MS — delay between sends (default 120) to respect provider rate limits
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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

type Subscriber = { email: string };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Use POST' }, 405);
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return jsonResponse({ error: 'Missing Bearer token' }, 401);
  }

  const supabaseUrl = normalizeSupabaseApiOrigin(Deno.env.get('SUPABASE_URL') ?? '');
  const anonKey = (Deno.env.get('SUPABASE_ANON_KEY') ?? '').trim();
  const serviceKey = (Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '').trim();

  if (!supabaseUrl || !anonKey) {
    return jsonResponse({ error: 'Missing Supabase env for edge function' }, 500);
  }
  if (!serviceKey) {
    return jsonResponse({ error: 'SUPABASE_SERVICE_ROLE_KEY required to read subscriber emails' }, 500);
  }

  const resendKey = (Deno.env.get('RESEND_API_KEY') ?? '').trim();
  const resendFrom = (Deno.env.get('RESEND_FROM') ?? '').trim();
  if (!resendKey || !resendFrom) {
    return jsonResponse(
      {
        error:
          'Configure RESEND_API_KEY and RESEND_FROM in Edge Function secrets. Use a verified domain in Resend.',
      },
      500,
    );
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: isAdmin, error: adminErr } = await userClient.rpc('is_site_admin');
  if (adminErr) {
    console.error(adminErr);
    return jsonResponse({ error: 'Could not verify admin: ' + adminErr.message }, 403);
  }
  if (isAdmin !== true) {
    return jsonResponse({ error: 'Only site admins can send broadcasts' }, 403);
  }

  const payload = (await req.json().catch(() => ({}))) as {
    subject?: string;
    html?: string;
    text?: string;
  };

  const subject = String(payload.subject ?? '').trim();
  const html = String(payload.html ?? '').trim();
  const text = String(payload.text ?? '').trim() || undefined;

  if (!subject || subject.length > 200) {
    return jsonResponse({ error: 'subject required (max 200 chars)' }, 400);
  }
  if (!html || html.length > 500_000) {
    return jsonResponse({ error: 'html body required (max ~500k chars)' }, 400);
  }

  const adminDb = createClient(supabaseUrl, serviceKey);

  const { data: rows, error: subErr } = await adminDb.rpc('admin_mailing_recipients', { p_limit: 20_000 });

  if (subErr) {
    console.error(subErr);
    return jsonResponse({ error: 'Could not load subscribers: ' + subErr.message }, 500);
  }

  const subscribers = (rows ?? []) as Subscriber[];
  const emails = subscribers.map((s) => String(s.email ?? '').trim().toLowerCase()).filter(Boolean);

  if (emails.length === 0) {
    return jsonResponse({ ok: true, sent: 0, failed: 0, message: 'No opted-in subscribers' });
  }

  const delayMs = Math.max(0, Math.min(2000, Number(Deno.env.get('MAILING_BROADCAST_DELAY_MS') ?? 120) || 120));

  let sent = 0;
  let failed = 0;
  const errors: string[] = [];

  for (const to of emails) {
    try {
      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: resendFrom,
          to: [to],
          subject,
          html,
          text,
        }),
      });

      if (!r.ok) {
        const t = await r.text();
        failed += 1;
        errors.push(`${to}: ${r.status} ${t.slice(0, 120)}`);
      } else {
        sent += 1;
      }
    } catch (e) {
      failed += 1;
      errors.push(`${to}: ${e instanceof Error ? e.message : 'send error'}`);
    }

    if (delayMs > 0) {
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }

  return jsonResponse({
    ok: failed === 0,
    sent,
    failed,
    total: emails.length,
    errors_sample: errors.slice(0, 8),
  });
});

/**
 * admin-ai — Supabase Edge Function (Deno)
 *
 * Admin-only copilot using Google Gemini (free tier on your Google project).
 * API key lives in Edge secrets — NOT in GitHub or the browser.
 *
 * POST JSON: { userMessage, history?, context? }
 * Authorization: Bearer <signed-in admin JWT>
 *
 * Secrets (Supabase → Edge Functions → Secrets):
 *   GEMINI_API_KEY — from https://aistudio.google.com/apikey (free tier)
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

type AiContext = {
  currentTab?: string;
  settingsSummary?: string;
  gamesCount?: number;
  pagesCount?: number;
  servicesCount?: number;
};

function buildSystemPrompt(ctx: AiContext): string {
  return `You are the built-in admin copilot for "Criminally Dev Dads" — a Godot/game hub (React + Supabase + HashRouter).

The editor is on Admin tab: ${ctx.currentTab ?? 'unknown'}.

Site settings snapshot:
${ctx.settingsSummary ?? '(none)'}

Catalog: ${ctx.gamesCount ?? 0} games, ${ctx.pagesCount ?? 0} pages, ${ctx.servicesCount ?? 0} services.

ADMIN TABS: overview, ai, settings, services, games, pages, nav, devlogs, theme, effects, typography, layout, components, behavior, seo, brand, social, motion, media, system, analytics, mailing

RULES:
- Help with admin: mood, copy, services/gigs, games, Stripe, migrations.
- End with a fenced JSON block:
\`\`\`json
{"reply":"summary","actions":[...]}
\`\`\`
- action types: navigate, patch_settings, patch_behavior, set_service_draft, remind_save
- patch_settings keys only: hero_title, hero_subtitle, site_visual_preset, support_title, support_body, footer_text, stripe_donation_url, support_page_href
- site_visual_preset: default, ember, aurora, toxic, arcade, midnight, paper
- User clicks Apply in UI; remind_save after edits.
- Be concise.`;
}

function parseAdminAiResponse(raw: string): { reply: string; actions: unknown[] } {
  const trimmed = raw.trim();
  const fence = trimmed.match(/```json\s*([\s\S]*?)```/i);
  const tryParse = (s: string) => {
    try {
      const p = JSON.parse(s) as { reply?: string; actions?: unknown[] };
      if (typeof p.reply === 'string' && Array.isArray(p.actions)) {
        return { reply: p.reply, actions: p.actions };
      }
    } catch {
      /* */
    }
    return null;
  };
  if (fence?.[1]) {
    const p = tryParse(fence[1]);
    if (p) return p;
  }
  const p = tryParse(trimmed);
  if (p) return p;
  return { reply: trimmed, actions: [] };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Use POST' }, 405);
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return jsonResponse({ error: 'Sign in to admin first' }, 401);
  }

  const geminiKey = (Deno.env.get('GEMINI_API_KEY') ?? '').trim();
  if (!geminiKey) {
    return jsonResponse(
      {
        error: 'GEMINI_NOT_CONFIGURED',
        message:
          'Add GEMINI_API_KEY in Supabase → Edge Functions → Secrets (free key from aistudio.google.com/apikey), then run: supabase functions deploy admin-ai',
      },
      503,
    );
  }

  const supabaseUrl = normalizeSupabaseApiOrigin(Deno.env.get('SUPABASE_URL') ?? '');
  const anonKey = (Deno.env.get('SUPABASE_ANON_KEY') ?? '').trim();
  if (!supabaseUrl || !anonKey) {
    return jsonResponse({ error: 'Missing Supabase env' }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: isAdmin, error: adminErr } = await userClient.rpc('is_site_admin');
  if (adminErr || isAdmin !== true) {
    return jsonResponse({ error: 'Only site admins can use admin AI' }, 403);
  }

  const payload = (await req.json().catch(() => ({}))) as {
    userMessage?: string;
    history?: { role: string; text: string }[];
    context?: AiContext;
  };

  const userMessage = String(payload.userMessage ?? '').trim();
  if (!userMessage || userMessage.length > 8000) {
    return jsonResponse({ error: 'userMessage required (max 8000 chars)' }, 400);
  }

  const history = Array.isArray(payload.history) ? payload.history.slice(-10) : [];
  const context = payload.context ?? {};
  const system = buildSystemPrompt(context);

  const contents = [
    ...history
      .filter((h) => h && (h.role === 'user' || h.role === 'model') && typeof h.text === 'string')
      .map((h) => ({
        role: h.role === 'model' ? 'model' : 'user',
        parts: [{ text: h.text.slice(0, 8000) }],
      })),
    { role: 'user' as const, parts: [{ text: userMessage }] },
  ];

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${encodeURIComponent(geminiKey)}`;

  const geminiRes = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents,
      generationConfig: { temperature: 0.35, maxOutputTokens: 2048 },
    }),
  });

  if (!geminiRes.ok) {
    const t = await geminiRes.text();
    return jsonResponse({ error: `Gemini ${geminiRes.status}: ${t.slice(0, 400)}` }, 502);
  }

  const data = (await geminiRes.json()) as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  const text =
    data.candidates?.[0]?.content?.parts
      ?.map((p) => p.text ?? '')
      .join('') ?? '';

  if (!text.trim()) {
    return jsonResponse({ error: 'Empty Gemini response' }, 502);
  }

  const parsed = parseAdminAiResponse(text);
  return jsonResponse({ reply: parsed.reply, actions: parsed.actions, source: 'gemini' });
});

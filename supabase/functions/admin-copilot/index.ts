/**
 * admin-copilot — Gemini for signed-in site admins only.
 *
 * Secret (Supabase → Edge Functions): GEMINI_API_KEY
 * Get a free key: https://aistudio.google.com/apikey
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

type HistoryTurn = { role: 'user' | 'model'; text: string };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Use POST' }, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Sign in as an editor first.' }, 401);
    }

    const geminiKey = (Deno.env.get('GEMINI_API_KEY') ?? '').trim();
    if (!geminiKey) {
      return jsonResponse(
        {
          error: 'GEMINI_API_KEY is not set for this project.',
          hint: 'Supabase → Edge Functions → Secrets → add GEMINI_API_KEY (free at Google AI Studio).',
        },
        503,
      );
    }

    const supabaseUrl = normalizeSupabaseApiOrigin(Deno.env.get('SUPABASE_URL') ?? '');
    const supabaseAnonKey = (Deno.env.get('SUPABASE_ANON_KEY') ?? '').trim();
    if (!supabaseUrl || !supabaseAnonKey) {
      return jsonResponse({ error: 'Missing SUPABASE_URL or SUPABASE_ANON_KEY on Edge.' }, 500);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: isAdmin, error: adminErr } = await userClient.rpc('is_site_admin');
    if (adminErr) {
      return jsonResponse({ error: adminErr.message }, 403);
    }
    if (!isAdmin) {
      return jsonResponse({ error: 'Forbidden — site admin only' }, 403);
    }

    const body = (await req.json().catch(() => ({}))) as {
      message?: string;
      systemPrompt?: string;
      history?: HistoryTurn[];
    };
    const message = String(body.message ?? '').trim();
    if (!message) {
      return jsonResponse({ error: 'message is required' }, 400);
    }
    const systemPrompt = String(body.systemPrompt ?? 'You are a helpful admin copilot.').trim();
    const history = Array.isArray(body.history) ? body.history.slice(-12) : [];

    const contents = [
      ...history
        .filter((h) => h && (h.role === 'user' || h.role === 'model') && typeof h.text === 'string')
        .map((h) => ({
          role: h.role,
          parts: [{ text: h.text }],
        })),
      { role: 'user' as const, parts: [{ text: message }] },
    ];

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${encodeURIComponent(geminiKey)}`;
    const geminiRes = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents,
        generationConfig: { temperature: 0.35, maxOutputTokens: 4096 },
      }),
    });

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      return jsonResponse({ error: `Gemini ${geminiRes.status}: ${errText.slice(0, 400)}` }, 502);
    }

    const data = (await geminiRes.json()) as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
    };
    const text =
      data.candidates?.[0]?.content?.parts
        ?.map((p) => p.text ?? '')
        .join('') ?? '';
    if (!text.trim()) {
      return jsonResponse({ error: 'Empty response from Gemini' }, 502);
    }

    return jsonResponse({ text });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: msg }, 500);
  }
});

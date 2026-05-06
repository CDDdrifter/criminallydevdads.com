/**
 * Validates build-time Supabase env so mis-copied dashboard URLs fail visibly on /admin.
 *
 * RELATED: Stripe checkout uses a different URL — Edge secret `SITE_URL` = your **public site** root
 * (hash routes), not `https://*.supabase.co`. See docs/STRIPE_CHECKOUT.md.
 */

/**
 * API base URL must be https://REF.supabase.co only. Dashboard / docs sometimes paste a path
 * after the host (e.g. /project/default) — strip it so the JS client matches PostgREST.
 * Same normalization idea as create-checkout-session Edge Function for SUPABASE_URL.
 */
export function normalizeSupabaseProjectUrl(raw: string): string {
  const t = raw.trim();
  if (!t) {
    return t;
  }
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

/** Value from the build env before normalization (for diagnostics only). */
export function getRawBuildTimeSupabaseUrl(): string {
  return (import.meta.env.VITE_SUPABASE_URL ?? '').trim();
}

/** Same base URL the live client uses (paths after *.supabase.co are stripped). */
export function getBuildTimeSupabaseUrl(): string {
  return normalizeSupabaseProjectUrl(getRawBuildTimeSupabaseUrl());
}

export function getBuildTimeAnonKey(): string {
  return (import.meta.env.VITE_SUPABASE_ANON_KEY ?? '').trim();
}

export function supabaseUrlLooksValid(url: string): { ok: boolean; message: string } {
  const raw = url.trim();
  if (!raw) {
    return { ok: false, message: 'VITE_SUPABASE_URL is empty in this build.' };
  }
  if (raw.includes('app.supabase.com')) {
    return {
      ok: false,
      message:
        'This looks like a dashboard link, not the API URL. In Supabase use the left sidebar gear → Project Settings → API → copy “Project URL” only (https://xxxx.supabase.co).',
    };
  }
  const t = normalizeSupabaseProjectUrl(raw);
  let u: URL;
  try {
    u = new URL(t);
  } catch {
    return { ok: false, message: 'VITE_SUPABASE_URL is not a valid https URL.' };
  }
  if (u.protocol !== 'https:') {
    return { ok: false, message: 'Project URL must start with https://' };
  }
  if (!u.hostname.endsWith('.supabase.co')) {
    return {
      ok: false,
      message:
        'Host must be something like abcdefghijklmnop.supabase.co — copy it from Project Settings → API (“Project URL”).',
    };
  }
  const path = u.pathname.replace(/\/$/, '') || '';
  if (path !== '') {
    return {
      ok: false,
      message: 'Project URL must not have a path after .supabase.co (no /dashboard etc.).',
    };
  }
  return { ok: true, message: '' };
}

export function anonKeyLooksValid(key: string): { ok: boolean; message: string } {
  const k = key.trim();
  if (!k) {
    return { ok: false, message: 'VITE_SUPABASE_ANON_KEY is empty in this build.' };
  }
  if (k.includes('service_role') || k.startsWith('sb_secret_')) {
    return {
      ok: false,
      message:
        'Wrong key: use the anon public key from the same API page — not service_role or any “secret” key.',
    };
  }
  if (k.length < 80) {
    return {
      ok: false,
      message:
        'Anon key looks too short — click “Reveal” and copy the entire anon public key from Project Settings → API.',
    };
  }
  return { ok: true, message: '' };
}

/** First/last chars only — enough to verify you didn’t paste the wrong secret. */
export function describeAnonKeyShape(key: string): string {
  if (key.length < 30) {
    return '(missing or too short)';
  }
  return `${key.slice(0, 16)}…${key.slice(-8)} (${key.length} chars)`;
}

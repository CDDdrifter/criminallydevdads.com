/**
 * Validates build-time Supabase env so mis-copied dashboard URLs fail visibly on /admin.
 */

export function getBuildTimeSupabaseUrl(): string {
  return (import.meta.env.VITE_SUPABASE_URL ?? '').trim();
}

export function getBuildTimeAnonKey(): string {
  return (import.meta.env.VITE_SUPABASE_ANON_KEY ?? '').trim();
}

export function supabaseUrlLooksValid(url: string): { ok: boolean; message: string } {
  const t = url.trim();
  if (!t) {
    return { ok: false, message: 'VITE_SUPABASE_URL is empty in this build.' };
  }
  if (t.includes('/project/') || t.includes('app.supabase.com')) {
    return {
      ok: false,
      message:
        'This looks like a dashboard link, not the API URL. In Supabase use the left sidebar gear → Project Settings → API → copy “Project URL” only (https://xxxx.supabase.co).',
    };
  }
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

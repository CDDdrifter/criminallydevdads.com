const raw = import.meta.env.VITE_ALLOWED_EMAIL_DOMAINS ?? 'criminallydevdads.com';

export function allowedEmailDomains(): string[] {
  return raw
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

/** Client-side gate for UX; real enforcement is Supabase RLS. */
export function isAllowedEditorEmail(email: string | undefined | null): boolean {
  if (!email) {
    return false;
  }
  const lower = email.toLowerCase();
  const host = lower.split('@')[1];
  if (!host) {
    return false;
  }
  return allowedEmailDomains().includes(host);
}

/**
 * PostgREST / Supabase errors are plain objects with message, details, hint, code — not always `instanceof Error`.
 */
export function formatSupabaseWriteError(err: unknown): string {
  if (err == null) {
    return 'Save failed (empty error).';
  }
  if (typeof err === 'string') {
    return err;
  }
  if (typeof err !== 'object') {
    return `Save failed (${String(err)}).`;
  }

  const o = err as {
    message?: unknown;
    details?: unknown;
    hint?: unknown;
    code?: unknown;
  };
  let message = typeof o.message === 'string' ? o.message.trim() : '';
  const details = typeof o.details === 'string' ? o.details.trim() : '';
  const hint = typeof o.hint === 'string' ? o.hint.trim() : '';
  const code = typeof o.code === 'string' ? o.code.trim() : '';

  if (!message && err instanceof Error) {
    message = err.message.trim();
  }

  const parts: string[] = [];
  if (message) {
    parts.push(message);
  }
  if (details) {
    parts.push(details);
  }
  if (hint) {
    parts.push(`Hint: ${hint}`);
  }
  if (code) {
    parts.push(`Code: ${code}`);
  }
  return parts.length ? parts.join(' — ') : 'Save failed (no details from server).';
}

/** Postgres insufficient_privilege / RLS denial — save looks like "everything is broken" when it's really auth. */
export function isRlsOrPermissionError(err: unknown): boolean {
  const code =
    typeof err === 'object' && err !== null && 'code' in err
      ? String((err as { code?: string }).code ?? '')
      : '';
  if (code === '42501' || code === 'PGRST301') {
    return true;
  }
  const text = formatSupabaseWriteError(err).toLowerCase();
  return (
    text.includes('row-level security') ||
    text.includes('permission denied') ||
    (text.includes('rls') && text.includes('policy')) ||
    text.includes('jwt expired')
  );
}

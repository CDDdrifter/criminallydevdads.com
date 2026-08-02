/**
 * Admin save errors — Firebase Firestore / Auth (replaces Supabase PostgREST helpers).
 */
export function formatAdminWriteError(err: unknown): string {
  if (err == null) {
    return 'Save failed (empty error).';
  }
  if (typeof err === 'string') {
    return err;
  }
  if (err instanceof Error) {
    return err.message.trim() || 'Save failed.';
  }
  if (typeof err === 'object') {
    const o = err as { message?: unknown; code?: unknown };
    const message = typeof o.message === 'string' ? o.message.trim() : '';
    const code = typeof o.code === 'string' ? o.code.trim() : '';
    if (message && code) {
      return `${message} (code: ${code})`;
    }
    if (message) {
      return message;
    }
    if (code) {
      return `Save failed (code: ${code}).`;
    }
  }
  return `Save failed (${String(err)}).`;
}

/** Firestore permission-denied / auth issues. */
export function isFirebasePermissionError(err: unknown): boolean {
  const code =
    typeof err === 'object' && err !== null && 'code' in err
      ? String((err as { code?: string }).code ?? '')
      : '';
  if (code === 'permission-denied' || code === 'unauthenticated') {
    return true;
  }
  const text = formatAdminWriteError(err).toLowerCase();
  return (
    text.includes('permission') ||
    text.includes('missing or insufficient permissions') ||
    text.includes('firebase not configured') ||
    text.includes('sign in')
  );
}

export function describeAdminWriteFailure(err: unknown): string {
  const core = formatAdminWriteError(err);
  if (isFirebasePermissionError(err)) {
    return `${core}\n\nSign in at /admin with a @criminallydevdads.com Google account, then run: npx firebase deploy --only firestore:rules,firestore:indexes --project criminallydevdads`;
  }
  if (/github token|no github token/i.test(core)) {
    return `${core}\n\nGame file uploads need a GitHub PAT in Admin → System → GitHub sync (repo scope).`;
  }
  return core;
}

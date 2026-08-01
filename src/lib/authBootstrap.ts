/**
 * Path-based SPA helpers for Firebase Auth redirect flow.
 */
const AUTH_RETURN_KEY = 'cdd_auth_return';

/** Where to send the user after Google sign-in completes. */
export function stashAuthReturn(path?: string) {
  const raw = path ?? (window.location.pathname + window.location.search || '/account');
  const normalized = raw.startsWith('/') ? raw : `/${raw}`;
  sessionStorage.setItem(AUTH_RETURN_KEY, normalized);
}

export function popAuthReturn(): string {
  const p = sessionStorage.getItem(AUTH_RETURN_KEY) || '/account';
  sessionStorage.removeItem(AUTH_RETURN_KEY);
  return p;
}

/** No-op — kept for main.tsx import stability. Do NOT rewrite OAuth URLs (breaks Firebase redirect). */
export function bootstrapSpaAuthPaths(): void {
  // Firebase signInWithRedirect must return to the same URL getRedirectResult expects.
  // Old Supabase code rewrote ?code= to /auth/callback — that prevented sign-in from sticking.
}

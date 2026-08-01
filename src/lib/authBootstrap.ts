/**
 * Path-based SPA helpers for Firebase Auth redirect flow.
 */
import { getAuthRedirectBaseUrl } from './authRedirect';

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

/** Minimal bootstrap — no hash routing needed with BrowserRouter. */
export function bootstrapSpaAuthPaths(): void {
  // Redirect OAuth code params to /auth/callback if they land on root
  const { pathname, search, origin } = window.location;
  const params = new URLSearchParams(search);
  if (params.get('code') && pathname !== '/auth/callback') {
    window.history.replaceState(window.history.state, '', `${origin}/auth/callback${search}`);
  }
}

/** Strip OAuth query params after sign-in completes. */
export function cleanOAuthQueryFromUrl() {
  const base = getAuthRedirectBaseUrl().replace(/\/$/, '');
  window.history.replaceState({}, '', `${base}/auth/callback`);
}

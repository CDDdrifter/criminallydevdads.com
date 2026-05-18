/**
 * Hash-router SPA helpers for Supabase Auth.
 *
 * Supabase redirects to path-based URLs (`/oauth/consent`, `/…?code=…`) while this
 * app routes live under `/#/…`.
 *
 * Use `history.replaceState` (not `location.replace`) when moving `?code=` into the
 * hash: a full reload can abort PKCE exchange and consume the verifier →
 * "PKCE code verifier not found" on the next load.
 */
import { getAuthRedirectBaseUrl } from './authRedirect';

const AUTH_RETURN_KEY = 'cdd_auth_return';
const OAUTH_CONSENT_ID_KEY = 'cdd_oauth_authorization_id';

/** OAuth callback target (query `?code=` — works with HashRouter). */
export function getOAuthRedirectUrl(): string {
  return getAuthRedirectBaseUrl();
}

/** Where to send the user after Google sign-in completes. */
export function stashAuthReturn(path?: string) {
  const raw = path ?? (window.location.hash.slice(1) || '/account');
  const normalized = raw.startsWith('/') ? raw : `/${raw}`;
  sessionStorage.setItem(AUTH_RETURN_KEY, normalized);
}

export function popAuthReturn(): string {
  const p = sessionStorage.getItem(AUTH_RETURN_KEY) || '/account';
  sessionStorage.removeItem(AUTH_RETURN_KEY);
  return p;
}

export function stashOAuthAuthorizationId(authorizationId: string) {
  sessionStorage.setItem(OAUTH_CONSENT_ID_KEY, authorizationId);
}

export function popOAuthAuthorizationId(): string | null {
  const id = sessionStorage.getItem(OAUTH_CONSENT_ID_KEY);
  sessionStorage.removeItem(OAUTH_CONSENT_ID_KEY);
  return id;
}

/**
 * If Supabase or OAuth server sent the browser to a path route, rewrite to hash route
 * so HashRouter can render the right page.
 */
export function bootstrapSpaAuthPaths(): void {
  const { pathname, search, origin, hash } = window.location;
  const params = new URLSearchParams(search);
  const hasCode = Boolean(params.get('code'));

  if (hasCode && !hash.startsWith('#/auth/callback')) {
    const basePath = pathname.replace(/\/$/, '') || '';
    const next = `${origin}${basePath}/#/auth/callback${search}`;
    window.history.replaceState(window.history.state, '', next);
    return;
  }

  if (hash.startsWith('#/')) {
    const root = pathname.replace(/\/index\.html$/i, '') || '/';
    if (root !== '/') {
      window.history.replaceState(window.history.state, '', `${origin}/${hash}${search}`);
    }
    return;
  }

  const appPath = pathname.replace(/\/index\.html$/i, '') || '/';
  if (appPath !== '/') {
    window.history.replaceState(window.history.state, '', `${origin}/#${appPath}${search}`);
    return;
  }

  if (pathname === '/oauth/consent' || pathname.endsWith('/oauth/consent')) {
    const basePath = pathname.replace(/\/oauth\/consent\/?$/, '') || '';
    const next = `${origin}${basePath}/#/oauth/consent${search}`;
    window.history.replaceState(window.history.state, '', next);
    return;
  }
  if (pathname === '/auth/callback' || pathname.endsWith('/auth/callback')) {
    const basePath = pathname.replace(/\/auth\/callback\/?$/, '') || '';
    const next = `${origin}${basePath}/#/auth/callback${search}`;
    window.history.replaceState(window.history.state, '', next);
  }
}

/** Strip `?code=` / `?error=` from the address bar after PKCE exchange (keep hash route). */
export function cleanOAuthQueryFromUrl() {
  const base = getAuthRedirectBaseUrl().replace(/\/$/, '');
  let hash = window.location.hash?.startsWith('#/') ? window.location.hash : '#/auth/callback';
  const q = hash.indexOf('?');
  if (q !== -1) {
    hash = hash.slice(0, q);
  }
  window.history.replaceState({}, '', `${base}${hash}`);
}

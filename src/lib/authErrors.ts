import { getAuthRedirectBaseUrl } from './authRedirect';

/** Safe decode for OAuth `error` / `error_description` query values. */
export function decodeOAuthQueryValue(raw: string): string {
  try {
    return decodeURIComponent(raw.replace(/\+/g, ' '));
  } catch {
    return raw;
  }
}

/**
 * Turn cryptic OAuth / PKCE errors into actionable hints for Supabase + GitHub Pages.
 */
export function humanizeOAuthError(raw: string): string {
  const t = raw.trim();
  const lower = t.toLowerCase();
  const base = getAuthRedirectBaseUrl();

  if (lower.includes('unauthorized-domain') || lower.includes('auth/unauthorized-domain')) {
    return `${t}

Firebase → Authentication → Settings → Authorized domains must include your live site domain (e.g. criminallydevdads.com). Add the exact domain with no https://.`;
  }

  if (lower.includes('redirect_uri') || lower.includes('redirect uri')) {
    return `${t}

This almost always means Supabase → Authentication → URL Configuration does not list your exact redirect URL.

Add this exact URL under Redirect URLs (with trailing slash if shown): ${base}

If you deploy to both a custom domain and github.io, add both roots. You can set VITE_AUTH_REDIRECT_URL in your build to force one canonical URL.`;
  }

  if (lower.includes('access_denied') || lower.includes('access denied')) {
    return `${t}

The sign-in window was closed or Google denied access. Try again and choose an account, or check that the Google OAuth consent screen is configured for your domain.`;
  }

  if (lower.includes('invalid request') && lower.includes('code')) {
    return `${t}

The sign-in link expired or was already used. Click “Sign in with Google” again.`;
  }

  return t;
}

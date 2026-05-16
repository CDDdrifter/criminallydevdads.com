/**
 * Return URL Supabase uses after Google / magic-link auth. Must be listed in
 * Supabase → Authentication → URL Configuration → Redirect URLs (exact match).
 *
 * Optional: set VITE_AUTH_REDIRECT_URL in GitHub Actions secrets (and .env.local) to your
 * real public URL if auto-detect is wrong (e.g. you always use a custom domain but sometimes
 * open the github.io URL).
 *
 * GitHub Pages often serves the app at .../repo/ or .../repo/index.html — missing trailing
 * slash or a mismatch here commonly causes 404 after OAuth.
 *
 * In Supabase → Authentication → URL Configuration, add these Redirect URLs (exact):
 *   https://criminallydevdads.com/
 *   https://www.criminallydevdads.com/   ← BOTH apex and www, if you use either
 *   https://criminallydevdads.com/**
 *   (and your github.io URL if you use it)
 * Site URL should be https://criminallydevdads.com (no hash).
 * OAuth Server authorization path: /oauth/consent → live at #/oauth/consent
 *
 * PKCE stores the code verifier in this tab’s origin. If the configured redirect host differs
 * from where the user clicked “Sign in” (e.g. www vs apex, or GitHub secret vs actual tab),
 * the callback loads with an empty verifier → “PKCE code verifier not found in storage”.
 */
export function getAuthRedirectBaseUrl(): string {
  const { origin: winOrigin, pathname: rawPath } = window.location;

  let path = rawPath.split('?')[0]?.split('#')[0] ?? '/';

  if (path.endsWith('/index.html')) {
    path = path.slice(0, -'index.html'.length);
  } else if (path.endsWith('index.html')) {
    path = path.slice(0, -'index.html'.length);
  }
  if (path !== '/' && !path.endsWith('/')) {
    path += '/';
  }

  const override = (import.meta.env.VITE_AUTH_REDIRECT_URL ?? '').trim();
  if (override) {
    try {
      const u = new URL(override);
      if (u.protocol !== 'https:') {
        console.warn('[hub] VITE_AUTH_REDIRECT_URL should use https');
      }
      let opath = u.pathname || '/';
      if (opath.endsWith('/index.html')) {
        opath = opath.slice(0, -'index.html'.length);
      }
      if (opath !== '/' && !opath.endsWith('/')) {
        opath += '/';
      }

      if (u.origin !== winOrigin) {
        console.warn(
          '[hub] VITE_AUTH_REDIRECT_URL host does not match this page — using current origin for OAuth redirect (PKCE is origin-scoped).',
          { configured: u.origin, current: winOrigin },
        );
        return `${winOrigin}${path}`;
      }

      return `${u.origin}${opath}`;
    } catch {
      console.warn('[hub] VITE_AUTH_REDIRECT_URL is not a valid URL; using current origin + path');
    }
  }

  return `${winOrigin}${path}`;
}

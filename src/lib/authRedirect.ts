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
 */
export function getAuthRedirectBaseUrl(): string {
  const override = (import.meta.env.VITE_AUTH_REDIRECT_URL ?? '').trim();
  if (override) {
    try {
      const u = new URL(override);
      if (u.protocol !== 'https:') {
        console.warn('[hub] VITE_AUTH_REDIRECT_URL should use https');
      }
      let path = u.pathname || '/';
      if (path.endsWith('/index.html')) {
        path = path.slice(0, -'index.html'.length);
      }
      if (path !== '/' && !path.endsWith('/')) {
        path += '/';
      }
      return `${u.origin}${path}`;
    } catch {
      console.warn('[hub] VITE_AUTH_REDIRECT_URL is not a valid URL; using window.location instead');
    }
  }

  const { origin, pathname: rawPath } = window.location;
  let path = rawPath.split('?')[0]?.split('#')[0] ?? '/';

  if (path.endsWith('/index.html')) {
    path = path.slice(0, -'index.html'.length);
  } else if (path.endsWith('index.html')) {
    path = path.slice(0, -'index.html'.length);
  }
  if (path !== '/' && !path.endsWith('/')) {
    path += '/';
  }
  return `${origin}${path}`;
}

/**
 * Return URL Supabase uses after Google / magic-link auth. Must be listed in
 * Supabase → Authentication → URL Configuration → Redirect URLs (exact match).
 *
 * GitHub Pages often serves the app at .../repo/ or .../repo/index.html — missing trailing
 * slash or a mismatch here commonly causes 404 after OAuth.
 */
export function getAuthRedirectBaseUrl(): string {
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

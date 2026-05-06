/** Optional JSON snapshots under /cms (copied from repo `cms/` at build time). */

function cmsAssetUrl(path: string): string {
  const base = import.meta.env.BASE_URL || '/';
  const normalizedBase = base.endsWith('/') ? base : `${base}/`;
  const rel = path.startsWith('/') ? path.slice(1) : path;
  return `${normalizedBase}${rel}`;
}

export async function fetchStaticJson<T>(relativePath: string): Promise<T | null> {
  try {
    const res = await fetch(cmsAssetUrl(relativePath), { cache: 'no-store' });
    if (!res.ok) {
      return null;
    }
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

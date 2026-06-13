/**
 * Absolute URL for static files next to the built app (games/, games.json, etc.).
 * Uses Vite's BASE_URL so GitHub Pages project sites and trailing-slash quirks resolve correctly.
 */
import { enforceHttpsAssetUrl } from './secureContext';

export function resolvePublicAssetUrl(relativePath: string): string {
  if (/^https?:\/\//i.test(relativePath)) {
    return enforceHttpsAssetUrl(relativePath);
  }
  const rel = relativePath.replace(/^\//, '');
  const baseUrl = new URL(import.meta.env.BASE_URL, window.location.href);
  if (!baseUrl.pathname.endsWith('/')) {
    baseUrl.pathname += '/';
  }
  return enforceHttpsAssetUrl(new URL(rel, baseUrl).href);
}

/** Resolve playable URL for iframe / window (HashRouter-safe). */
export function resolveGameUrl(launchPath: string): string {
  return resolvePublicAssetUrl(launchPath);
}

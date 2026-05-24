/**
 * Document branding: favicon, apple-touch-icon, and page title.
 * Site-wide defaults come from Admin → SEO + Head / Brand; routes can override temporarily.
 */
import type { SiteSettings } from '../types';

export const BUNDLED_FAVICON = '/favicon.svg';
export const BUNDLED_APPLE_TOUCH = '/apple-touch-icon.svg';

function faviconMime(href: string): string | undefined {
  const lower = href.toLowerCase();
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.ico')) return 'image/x-icon';
  return undefined;
}

export function resolveSiteFavicon(settings: Pick<SiteSettings, 'seo' | 'branding'>): string {
  return (
    settings.seo.favicon_url?.trim() ||
    settings.branding.header_logo_url?.trim() ||
    BUNDLED_FAVICON
  );
}

export function resolveSiteAppleTouch(settings: Pick<SiteSettings, 'seo' | 'branding'>): string {
  return (
    settings.seo.apple_touch_icon_url?.trim() ||
    settings.seo.favicon_url?.trim() ||
    settings.branding.header_logo_url?.trim() ||
    BUNDLED_APPLE_TOUCH
  );
}

export function resolveGameTabIcon(
  game: { tab_icon?: string; thumbnail?: string },
  settings: Pick<SiteSettings, 'seo' | 'branding'>,
): string {
  return (
    game.tab_icon?.trim() ||
    game.thumbnail?.trim() ||
    resolveSiteFavicon(settings)
  );
}

export function applyDocumentFavicon(url: string) {
  if (typeof document === 'undefined') return;
  const href = url.trim() || BUNDLED_FAVICON;
  let link = document.querySelector<HTMLLinkElement>('link[rel="icon"]');
  if (!link) {
    link = document.createElement('link');
    link.rel = 'icon';
    document.head.appendChild(link);
  }
  const mime = faviconMime(href);
  if (mime) link.type = mime;
  else link.removeAttribute('type');
  if (link.href !== href) link.href = href;
}

export function applyAppleTouchIcon(url: string) {
  if (typeof document === 'undefined') return;
  const href = url.trim() || BUNDLED_APPLE_TOUCH;
  let link = document.querySelector<HTMLLinkElement>('link[rel="apple-touch-icon"]');
  if (!link) {
    link = document.createElement('link');
    link.rel = 'apple-touch-icon';
    document.head.appendChild(link);
  }
  if (link.href !== href) link.href = href;
}

export function applyRouteTitle(pageTitle: string, settings: Pick<SiteSettings, 'seo' | 'branding'>) {
  if (typeof document === 'undefined' || !pageTitle.trim()) return;
  const template = settings.seo.title_template?.trim() || '%s — Criminally Dev Dads';
  document.title = template.replace('%s', pageTitle.trim());
}

/** Restore hub defaults after a per-route override unmounts. */
export function applySiteBranding(settings: SiteSettings) {
  applyDocumentFavicon(resolveSiteFavicon(settings));
  applyAppleTouchIcon(resolveSiteAppleTouch(settings));
  const siteName = settings.branding.site_name?.trim();
  if (siteName) {
    applyRouteTitle(siteName, settings);
  }
}

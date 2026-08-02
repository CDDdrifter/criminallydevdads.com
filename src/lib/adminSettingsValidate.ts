import type { SitePage, SiteSettings } from '../types';

export type SettingsFieldErrors = Record<string, string>;

function slugFromInternalPageHref(href: string): string | null {
  const h = href.trim();
  if (!h.startsWith('/p/')) {
    return null;
  }
  const rest = h.slice(3);
  const slug = rest.split('/')[0]?.replace(/\/$/, '').trim();
  return slug || null;
}

/**
 * Blocks save — broken routing (e.g. `/p/shop` with "external" checked).
 * Missing CMS pages are hints only (see `softSiteSettingsLinkHints`) so you can save first, then add the page.
 */
export function blockingSiteSettingsIssues(settings: SiteSettings): SettingsFieldErrors {
  const errors: SettingsFieldErrors = {};

  settings.support_buttons.forEach((btn, i) => {
    const stripe = settings.stripe_tip_url.trim();
    const supportPath = settings.support_page_href.trim();
    const effectiveHref =
      (btn.id === 'tip' || btn.id === 'donate') && stripe
        ? stripe
        : btn.id === 'contact' && supportPath
          ? supportPath
          : btn.href;

    if (btn.external && effectiveHref.trim().startsWith('/')) {
      errors[`support_btn_${i}`] =
        'Internal paths like /p/… must stay in the site shell. Uncheck “Open in new tab (external)”, or use a full https:// URL for an outside shop.';
    }
  });

  (settings.promo_events ?? []).forEach((ev, i) => {
    const h = ev.href.trim();
    if (!h) {
      return;
    }
    if (ev.external && h.startsWith('/')) {
      errors[`promo_${i}_href`] =
        'Uncheck “External link” for /p/… routes, or use a full https:// URL.';
    }
  });

  return errors;
}

/** Non-blocking hints (orange). Same keys as blocking issues for missing pages — shown until a page exists. */
export function softSiteSettingsLinkHints(settings: SiteSettings, pages: SitePage[]): SettingsFieldErrors {
  const hints: SettingsFieldErrors = {};
  const pageSlugs = new Set(pages.map((p) => p.slug));

  const hintMissing = (href: string, key: string) => {
    const slug = slugFromInternalPageHref(href);
    if (!slug || pageSlugs.has(slug)) {
      return;
    }
    hints[key] = `Tip: add a page with slug "${slug}" under the Pages tab so this link has content. You can still save.`;
  };

  hintMissing(settings.support_page_href, 'support_page_href');

  settings.support_buttons.forEach((btn, i) => {
    const stripe = settings.stripe_tip_url.trim();
    const supportPath = settings.support_page_href.trim();
    const effectiveHref =
      (btn.id === 'tip' || btn.id === 'donate') && stripe
        ? stripe
        : btn.id === 'contact' && supportPath
          ? supportPath
          : btn.href;
    if (btn.external && effectiveHref.trim().startsWith('/')) {
      return;
    }
    if (!btn.external || ((btn.id === 'tip' || btn.id === 'donate') && stripe) || (btn.id === 'contact' && supportPath)) {
      hintMissing(effectiveHref, `support_btn_${i}`);
    }
  });

  (settings.promo_events ?? []).forEach((ev, i) => {
    const h = ev.href.trim();
    if (!h || ev.external) {
      return;
    }
    hintMissing(h, `promo_${i}_href`);
  });

  return hints;
}

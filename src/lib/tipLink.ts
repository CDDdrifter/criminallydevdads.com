/** Magic href values in page blocks / buttons that resolve to Admin → Site copy → Stripe tip URL. */
export const TIP_LINK_ALIASES = new Set(['@tip', '#tip', '$tip', 'stripe:tip', '/@tip', '{{tip}}']);

/** Shorthand shown in admin pickers — paste into any button URL field. */
export const TIP_LINK_ALIAS = '@tip';

export function isTipLinkAlias(href: string): boolean {
  return TIP_LINK_ALIASES.has(href.trim().toLowerCase());
}

export function resolveTipHref(
  href: string,
  tipUrl: string,
): { href: string; external: true } | null {
  const url = tipUrl.trim();
  if (!url || !isTipLinkAlias(href)) {
    return null;
  }
  return { href: url, external: true };
}

/** Resolve button hrefs for render — `@tip` → Stripe link; https opens in a new tab. */
export function resolveButtonHref(
  href: string,
  tipUrl: string,
  externalHint = false,
): { href: string; external: boolean } {
  const raw = href.trim();
  if (!raw) {
    return { href: '', external: externalHint };
  }
  const tip = resolveTipHref(raw, tipUrl);
  if (tip) {
    return tip;
  }
  const external = externalHint || /^https?:\/\//i.test(raw) || raw.startsWith('mailto:');
  return { href: raw, external };
}

/** Magic href values in page blocks / buttons that resolve to Admin → Site copy → Stripe tip URL. */
export const TIP_LINK_ALIASES = new Set(['@tip', '#tip', '$tip', 'stripe:tip', '/@tip', '{{tip}}']);

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

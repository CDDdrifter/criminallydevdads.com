import { useEffect } from 'react';
import { useSiteSettings } from './useSiteSettings';
import { applyDocumentFavicon, applyRouteTitle, applySiteBranding } from '../lib/routeBranding';

type RouteBrandingOpts = {
  /** When false, skip overrides (e.g. while loading). */
  active?: boolean;
  title?: string | null;
  faviconUrl?: string | null;
};

/**
 * Temporarily sets document title + favicon for a route; restores site defaults on unmount.
 */
export function useRouteBranding({ active = true, title, faviconUrl }: RouteBrandingOpts) {
  const { settings } = useSiteSettings();

  useEffect(() => {
    if (!active) return;
    const hasTitle = Boolean(title?.trim());
    const hasIcon = Boolean(faviconUrl?.trim());
    if (!hasTitle && !hasIcon) return;

    if (hasIcon) applyDocumentFavicon(faviconUrl!);
    if (hasTitle) applyRouteTitle(title!, settings);

    return () => {
      applySiteBranding(settings);
    };
  }, [active, title, faviconUrl, settings]);
}

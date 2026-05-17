import { useEffect } from 'react';
import { useSiteSettings } from './useSiteSettings';
import type { RouteFxOverride } from '../lib/routeFx';
import { mergeSiteFxWithRouteOverride } from '../lib/routeFx';
import { setDocumentFxFlags } from '../lib/siteFx';

/** Applies per-route FX overrides while mounted; restores site FX on unmount. */
export function useRouteFxSync(routeFx?: RouteFxOverride | null) {
  const { settings } = useSiteSettings();
  useEffect(() => {
    const merged = mergeSiteFxWithRouteOverride(settings, routeFx);
    setDocumentFxFlags(merged);
    return () => {
      setDocumentFxFlags(settings);
    };
  }, [settings, routeFx]);
}

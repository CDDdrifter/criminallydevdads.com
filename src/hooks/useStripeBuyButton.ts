import { useMemo } from 'react';
import { useSiteSettings } from './useSiteSettings';
import { defaultStripeBuyButtonPlacements } from '../lib/themeDefaults';
import type { StripeBuyButtonPlacements } from '../types';

export function useStripeBuyButton() {
  const { settings } = useSiteSettings();

  return useMemo(() => {
    const buyButtonId = settings.stripe_buy_button_id.trim();
    const publishableKey = settings.stripe_publishable_key.trim();
    const configured = Boolean(buyButtonId && publishableKey);
    const placements: StripeBuyButtonPlacements = {
      ...defaultStripeBuyButtonPlacements(),
      ...(settings.behavior?.stripe_buy_button_placements ?? {}),
    };

    return {
      configured,
      buyButtonId,
      publishableKey,
      placements,
      showPlacement(placement: keyof StripeBuyButtonPlacements) {
        return configured && placements[placement];
      },
    };
  }, [
    settings.stripe_buy_button_id,
    settings.stripe_publishable_key,
    settings.behavior?.stripe_buy_button_placements,
  ]);
}

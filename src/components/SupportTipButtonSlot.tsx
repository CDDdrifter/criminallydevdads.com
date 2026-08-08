import { SupportTipButton } from './SupportTipButton';
import { useSiteSettings } from '../hooks/useSiteSettings';
import { defaultStripeBuyButtonPlacements } from '../lib/themeDefaults';
import type { StripeBuyButtonPlacements } from '../types';

type Props = {
  placement: keyof StripeBuyButtonPlacements;
  label?: string;
};

/** Site-wide tip button bar — placement toggles live in Admin → Behavior / Site copy. */
export function SupportTipButtonSlot({ placement, label }: Props) {
  const { settings } = useSiteSettings();
  const tipUrl = settings.stripe_tip_url.trim();
  const placements: StripeBuyButtonPlacements = {
    ...defaultStripeBuyButtonPlacements(),
    ...(settings.behavior?.stripe_buy_button_placements ?? {}),
  };

  if (!tipUrl || !placements[placement]) {
    return null;
  }

  return (
    <aside
      className={`support-tip-bar support-tip-bar--${placement}`}
      aria-label="Support the devs"
    >
      <SupportTipButton label={label} />
    </aside>
  );
}

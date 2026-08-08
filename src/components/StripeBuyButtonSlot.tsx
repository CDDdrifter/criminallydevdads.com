import { StripeBuyButton } from './StripeBuyButton';
import { useStripeBuyButton } from '../hooks/useStripeBuyButton';
import type { StripeBuyButtonPlacements } from '../types';

type Props = {
  placement: keyof StripeBuyButtonPlacements;
};

/** Renders the Stripe buy button when credentials + placement toggle are set in Admin. */
export function StripeBuyButtonSlot({ placement }: Props) {
  const stripe = useStripeBuyButton();

  if (!stripe.showPlacement(placement)) {
    return null;
  }

  return (
    <aside
      className={`stripe-buy-button-bar stripe-buy-button-bar--${placement}`}
      aria-label="Support the devs"
    >
      <StripeBuyButton buyButtonId={stripe.buyButtonId} publishableKey={stripe.publishableKey} />
    </aside>
  );
}

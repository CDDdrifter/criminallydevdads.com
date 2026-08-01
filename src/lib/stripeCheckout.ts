/**
 * Stripe checkout — requires a backend (Firebase Cloud Functions).
 * Use purchase_url / Payment Links in game JSON until Cloud Functions are deployed.
 */
import { backendConfigured } from './backend';

export async function startGameCheckout(_args: { slug: string; amountCents?: number }): Promise<void> {
  if (!backendConfigured()) {
    throw new Error('Firebase is not configured.');
  }
  throw new Error(
    'Built-in Stripe checkout requires Firebase Cloud Functions. Set purchase_url on the game or use a Stripe Payment Link — see docs/STRIPE_SETUP.md.',
  );
}

export async function startServiceCheckout(_args: {
  slug: string;
  amountCents?: number;
  quantity?: number;
  variantSelection?: Record<string, string>;
}): Promise<void> {
  if (!backendConfigured()) {
    throw new Error('Firebase is not configured.');
  }
  throw new Error(
    'Built-in Stripe checkout requires Firebase Cloud Functions. Set purchase_url on the service or use a Stripe Payment Link.',
  );
}

import { supabase, supabaseConfigured } from './supabase';

export async function startGameCheckout(args: { slug: string; amountCents?: number }): Promise<void> {
  if (!supabaseConfigured || !supabase) {
    throw new Error('Supabase is not configured (needed for checkout).');
  }
  const { data, error } = await supabase.functions.invoke<{ url?: string; error?: string }>(
    'create-checkout-session',
    { body: args },
  );
  if (data && typeof data.error === 'string' && data.error) {
    throw new Error(data.error);
  }
  if (error) {
    throw new Error(error.message ?? 'Checkout request failed');
  }
  const url = data?.url;
  if (!url || typeof url !== 'string') {
    throw new Error('Checkout did not return a URL. Is create-checkout-session deployed?');
  }
  window.location.href = url;
}

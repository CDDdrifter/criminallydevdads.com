/**
 * Admin: send HTML email to mailing-list subscribers.
 * Requires Firebase Cloud Functions + Resend — not yet migrated from Supabase Edge Functions.
 */
import { backendConfigured } from './backend';

export type MailingBroadcastResult = {
  ok: boolean;
  sent?: number;
  failed?: number;
  total?: number;
  errors_sample?: string[];
  message?: string;
};

export async function invokeMailingBroadcast(_body: {
  subject: string;
  html: string;
  text?: string;
}): Promise<MailingBroadcastResult & { error?: string }> {
  if (!backendConfigured()) {
    return { ok: false, error: 'Firebase is not configured.' };
  }
  return {
    ok: false,
    error: 'Mailing broadcast requires Firebase Cloud Functions (Resend). Export the list from Admin → Mailing for now.',
  };
}

/**
 * Admin: send HTML email to all mailing-list subscribers via Edge Function `mailing-broadcast`.
 * Requires Resend secrets on the function — see `supabase/functions/mailing-broadcast/index.ts`.
 */
import { supabase, supabaseConfigured } from './supabase';

export type MailingBroadcastResult = {
  ok: boolean;
  sent?: number;
  failed?: number;
  total?: number;
  errors_sample?: string[];
  message?: string;
};

export async function invokeMailingBroadcast(body: {
  subject: string;
  html: string;
  text?: string;
}): Promise<MailingBroadcastResult & { error?: string }> {
  if (!supabaseConfigured || !supabase) {
    return { ok: false, error: 'Supabase is not configured.' };
  }

  const { data, error } = await supabase.functions.invoke<
    MailingBroadcastResult & { error?: string }
  >('mailing-broadcast', {
    body,
  });

  const payload = data as Record<string, unknown> | null;
  if (payload && typeof payload.error === 'string' && payload.error) {
    return { ok: false, error: payload.error };
  }

  if (error) {
    return { ok: false, error: error.message };
  }

  if (!payload) {
    return { ok: false, error: 'Empty response from mailing-broadcast.' };
  }

  return payload as MailingBroadcastResult;
}

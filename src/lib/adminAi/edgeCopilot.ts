import { supabase, supabaseConfigured } from '../supabase';
import { buildSystemPrompt } from './buildContext';
import { parseAdminAiResponse } from './parseResponse';
import type { AdminAiContext, AdminAiResponse } from './types';

export type CopilotHistoryTurn = { role: 'user' | 'model'; text: string };

export async function askEdgeCopilot(args: {
  context: AdminAiContext;
  userMessage: string;
  history?: CopilotHistoryTurn[];
}): Promise<AdminAiResponse | null> {
  if (!supabaseConfigured || !supabase) {
    return null;
  }
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData.session?.access_token;
  if (!token) {
    return null;
  }

  const { data, error } = await supabase.functions.invoke<{ text?: string; error?: string; hint?: string }>(
    'admin-copilot',
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: {
        message: args.userMessage,
        systemPrompt: buildSystemPrompt(args.context),
        history: args.history ?? [],
      },
    },
  );

  if (error) {
    return null;
  }
  if (data?.error) {
    return null;
  }
  const text = data?.text?.trim();
  if (!text) {
    return null;
  }
  return parseAdminAiResponse(text);
}

export function edgeCopilotHintFromError(data: { error?: string; hint?: string } | null): string | null {
  if (!data?.error) return null;
  return data.hint ? `${data.error} ${data.hint}` : data.error;
}

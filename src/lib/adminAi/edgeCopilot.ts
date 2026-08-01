import { backendConfigured } from '../backend';
import type { AdminAiContext, AdminAiResponse } from './types';

export type CopilotHistoryTurn = { role: 'user' | 'model'; text: string };

/** Admin AI copilot — requires Firebase Cloud Functions (Gemini). Not yet deployed. */
export async function askEdgeCopilot(_args: {
  context: AdminAiContext;
  userMessage: string;
  history?: CopilotHistoryTurn[];
}): Promise<AdminAiResponse | null> {
  if (!backendConfigured()) {
    return null;
  }
  return null;
}

export function edgeCopilotHintFromError(data: { error?: string; hint?: string } | null): string | null {
  if (!data?.error) return null;
  return data.hint ? `${data.error} ${data.hint}` : data.error;
}

/**
 * Optional: Chrome on-device AI (Gemini Nano) — no API key when available.
 * https://developer.chrome.com/docs/ai/built-in
 */
import { buildSystemPrompt } from './buildContext';
import { parseAdminAiResponse } from './parseResponse';
import type { AdminAiContext, AdminAiResponse } from './types';

type LanguageModelSession = {
  prompt: (input: string) => Promise<string>;
  destroy?: () => void;
};

type ChromeAi = {
  languageModel?: {
    capabilities: () => Promise<{ available?: string }>;
    create: (opts?: { systemPrompt?: string }) => Promise<LanguageModelSession>;
  };
};

function getChromeAi(): ChromeAi | undefined {
  return (globalThis as unknown as { ai?: ChromeAi }).ai;
}

export async function chromeAiAvailable(): Promise<boolean> {
  const ai = getChromeAi();
  if (!ai?.languageModel?.capabilities) return false;
  try {
    const caps = await ai.languageModel.capabilities();
    return caps.available === 'readily' || caps.available === 'available';
  } catch {
    return false;
  }
}

export async function askChromeBrowserAi(args: {
  context: AdminAiContext;
  userMessage: string;
}): Promise<AdminAiResponse | null> {
  const ai = getChromeAi();
  if (!ai?.languageModel?.create) return null;

  const caps = await ai.languageModel.capabilities().catch(() => ({ available: 'no' }));
  if (caps.available !== 'readily' && caps.available !== 'available') {
    return null;
  }

  const system = `${buildSystemPrompt(args.context)}

Reply helpfully. If you suggest admin edits, end with a JSON block:
\`\`\`json
{"reply":"summary","actions":[]}
\`\`\`
Use action types: navigate, patch_settings, patch_behavior, set_service_draft, remind_save.`;

  const session = await ai.languageModel.create({ systemPrompt: system });
  try {
    const text = await session.prompt(args.userMessage);
    if (!text?.trim()) return null;
    return parseAdminAiResponse(text);
  } finally {
    session.destroy?.();
  }
}

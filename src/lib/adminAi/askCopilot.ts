import { askChromeBrowserAi, chromeAiAvailable } from './browserAi';
import { askCopilotAgent } from './copilotAgent';
import { askEdgeCopilot, type CopilotHistoryTurn } from './edgeCopilot';
import { askAdminGemini } from './gemini';
import type { AdminAiContext, AdminAiResponse } from './types';

export type CopilotEngine = 'gemini-edge' | 'gemini-byok' | 'chrome-on-device' | 'builtin';

export async function askAdminCopilot(args: {
  context: AdminAiContext;
  userMessage: string;
  preferBrowserAi?: boolean;
  geminiApiKey?: string;
  history?: CopilotHistoryTurn[];
}): Promise<AdminAiResponse & { engine: CopilotEngine }> {
  const history = args.history ?? [];

  const edge = await askEdgeCopilot({
    context: args.context,
    userMessage: args.userMessage,
    history,
  });
  if (edge) {
    return { ...edge, engine: 'gemini-edge' };
  }

  const byok = args.geminiApiKey?.trim();
  if (byok) {
    try {
      const res = await askAdminGemini({
        apiKey: byok,
        context: args.context,
        history,
        userMessage: args.userMessage,
      });
      return { ...res, engine: 'gemini-byok' };
    } catch {
      /* fall through */
    }
  }

  const useChrome = args.preferBrowserAi !== false && (await chromeAiAvailable());
  if (useChrome) {
    try {
      const res = await askChromeBrowserAi({
        context: args.context,
        userMessage: args.userMessage,
      });
      if (res) {
        return { ...res, engine: 'chrome-on-device' };
      }
    } catch {
      /* fall through */
    }
  }

  const res = askCopilotAgent(args.userMessage, args.context);
  return { ...res, engine: 'builtin' };
}

export { chromeAiAvailable };

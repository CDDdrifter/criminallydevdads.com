import { askChromeBrowserAi, chromeAiAvailable } from './browserAi';
import { askCopilotAgent } from './copilotAgent';
import type { AdminAiContext, AdminAiResponse } from './types';

export type CopilotEngine = 'builtin' | 'chrome-on-device';

export async function askAdminCopilot(args: {
  context: AdminAiContext;
  userMessage: string;
  preferBrowserAi?: boolean;
}): Promise<AdminAiResponse & { engine: CopilotEngine }> {
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
      /* fall through to builtin */
    }
  }

  const res = askCopilotAgent(args.userMessage, args.context);
  return { ...res, engine: 'builtin' };
}

export { chromeAiAvailable };

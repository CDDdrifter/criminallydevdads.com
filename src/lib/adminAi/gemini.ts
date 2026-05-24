import { buildSystemPrompt } from './buildContext';
import { parseAdminAiResponse } from './parseResponse';
import type { AdminAiContext, AdminAiResponse } from './types';

type ChatTurn = { role: 'user' | 'model'; text: string };

export async function askAdminGemini(args: {
  apiKey: string;
  context: AdminAiContext;
  history: ChatTurn[];
  userMessage: string;
}): Promise<AdminAiResponse> {
  const key = args.apiKey.trim();
  if (!key) {
    throw new Error('Add your free Gemini API key below (Google AI Studio).');
  }

  const system = buildSystemPrompt(args.context);
  const contents = [
    ...args.history.map((h) => ({
      role: h.role,
      parts: [{ text: h.text }],
    })),
    { role: 'user' as const, parts: [{ text: args.userMessage }] },
  ];

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${encodeURIComponent(key)}`;

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents,
      generationConfig: {
        temperature: 0.35,
        maxOutputTokens: 2048,
      },
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API ${res.status}: ${errText.slice(0, 280)}`);
  }

  const data = (await res.json()) as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  const text =
    data.candidates?.[0]?.content?.parts
      ?.map((p) => p.text ?? '')
      .join('') ?? '';
  if (!text.trim()) {
    throw new Error('Empty response from Gemini.');
  }
  return parseAdminAiResponse(text);
}

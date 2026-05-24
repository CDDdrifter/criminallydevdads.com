import { useCallback, useEffect, useRef, useState } from 'react';
import type { Dispatch, SetStateAction } from 'react';
import { applyAdminAiActions } from '../../lib/adminAi/applyActions';
import { askAdminCopilot, chromeAiAvailable } from '../../lib/adminAi/askCopilot';
import type { CopilotHistoryTurn } from '../../lib/adminAi/edgeCopilot';
import { summarizeSettingsForAi } from '../../lib/adminAi/buildContext';
import { ADMIN_AI_GEMINI_KEY_STORAGE, type AdminAiAction, type AdminAiResponse } from '../../lib/adminAi/types';
import type { SiteSettings } from '../../types';

type Props = {
  currentTab: string;
  settings: SiteSettings;
  gamesCount: number;
  pagesCount: number;
  servicesCount: number;
  setTab: (tab: string) => void;
  setSettings: Dispatch<SetStateAction<SiteSettings>>;
  flash: (msg: string) => void;
};

type Msg = {
  role: 'user' | 'assistant';
  text: string;
  pendingActions?: AdminAiAction[];
  engine?: string;
};

const QUICK_PROMPTS = [
  'help',
  'add button Hire us → /p/hire-us',
  'hide services page while I edit',
  'set mood to ember',
  'open pages',
];

const ENGINE_LABEL: Record<string, string> = {
  'gemini-edge': 'Gemini (Supabase)',
  'gemini-byok': 'Gemini (your API key)',
  'chrome-on-device': 'Chrome on-device AI',
  builtin: 'Built-in commands',
};

export function AdminAiAssistant({
  currentTab,
  settings,
  gamesCount,
  pagesCount,
  servicesCount,
  setTab,
  setSettings,
  flash,
}: Props) {
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [chromeAi, setChromeAi] = useState(false);
  const [autoApply, setAutoApply] = useState(true);
  const [geminiKey, setGeminiKey] = useState('');
  const historyRef = useRef<CopilotHistoryTurn[]>([]);
  const [messages, setMessages] = useState<Msg[]>([
    {
      role: 'assistant',
      text: 'Site copilot — can add homepage buttons, change copy/mood, hide built-in pages, and draft CMS pages.\n\nBest: add GEMINI_API_KEY in Supabase Edge secrets (free at Google AI Studio) and deploy admin-copilot. Optional: paste your own Gemini key below (stored only in this browser).',
    },
  ]);
  const [lastResponse, setLastResponse] = useState<(AdminAiResponse & { engine?: string }) | null>(null);

  useEffect(() => {
    void chromeAiAvailable().then(setChromeAi);
    try {
      const stored = localStorage.getItem(ADMIN_AI_GEMINI_KEY_STORAGE);
      if (stored) setGeminiKey(stored);
    } catch {
      /* ignore */
    }
  }, []);

  const persistGeminiKey = useCallback((key: string) => {
    setGeminiKey(key);
    try {
      if (key.trim()) {
        localStorage.setItem(ADMIN_AI_GEMINI_KEY_STORAGE, key.trim());
      } else {
        localStorage.removeItem(ADMIN_AI_GEMINI_KEY_STORAGE);
      }
    } catch {
      /* ignore */
    }
  }, []);

  const runMessage = useCallback(
    async (text: string) => {
      if (!text.trim() || busy) return;
      setError(null);
      setBusy(true);
      setMessages((m) => [...m, { role: 'user', text }]);

      try {
        const res = await askAdminCopilot({
          userMessage: text,
          geminiApiKey: geminiKey,
          history: historyRef.current,
          context: {
            currentTab,
            settingsSummary: summarizeSettingsForAi(settings),
            gamesCount,
            pagesCount,
            servicesCount,
          },
        });

        historyRef.current = [
          ...historyRef.current,
          { role: 'user' as const, text },
          { role: 'model' as const, text: res.reply },
        ].slice(-14);

        setLastResponse(res);

        if (autoApply && res.actions.length) {
          const notes = applyAdminAiActions({
            actions: res.actions,
            setTab,
            setSettings,
            flash,
          });
          setMessages((m) => [
            ...m,
            {
              role: 'assistant',
              text: `${res.reply}\n\n✓ Auto-applied: ${notes.join(' · ') || 'done'}. Save the relevant tab if prompted.`,
              engine: res.engine,
            },
          ]);
          setLastResponse(null);
        } else {
          setMessages((m) => [
            ...m,
            {
              role: 'assistant',
              text: res.reply,
              pendingActions: res.actions.length ? res.actions : undefined,
              engine: res.engine,
            },
          ]);
        }
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'Copilot failed';
        setError(msg);
        setMessages((m) => [...m, { role: 'assistant', text: `Error: ${msg}` }]);
      } finally {
        setBusy(false);
      }
    },
    [
      autoApply,
      busy,
      currentTab,
      flash,
      gamesCount,
      geminiKey,
      pagesCount,
      servicesCount,
      setSettings,
      setTab,
      settings,
    ],
  );

  const send = useCallback(() => {
    const text = input.trim();
    if (!text) return;
    setInput('');
    void runMessage(text);
  }, [input, runMessage]);

  const applyPending = useCallback(() => {
    if (!lastResponse?.actions.length) return;
    const notes = applyAdminAiActions({
      actions: lastResponse.actions,
      setTab,
      setSettings,
      flash,
    });
    flash(notes.length ? `Applied: ${notes.join(' · ')}` : 'Nothing to apply.');
    setLastResponse(null);
  }, [flash, lastResponse, setSettings, setTab]);

  return (
    <div className="admin-grid admin-copilot" style={{ gap: 16 }}>
      <div className="admin-panel" style={{ borderColor: 'rgba(62, 207, 142, 0.35)' }}>
        <h2 style={{ margin: '0 0 8px', fontSize: '1rem', color: 'var(--accent)' }}>🤖 Site copilot</h2>
        <p className="admin-muted" style={{ marginTop: 0, lineHeight: 1.55, fontSize: '0.88rem' }}>
          Tries <strong>Gemini on Supabase</strong> first (one free API key for all editors — secret{' '}
          <code>GEMINI_API_KEY</code>, deploy <code>admin-copilot</code>). Then your optional browser key, then Chrome
          on-device AI, then built-in commands.{' '}
          {chromeAi ? (
            <span style={{ color: '#3ecf8e' }}>Chrome AI available.</span>
          ) : null}
        </p>
        <div className="admin-field" style={{ marginTop: 12, marginBottom: 0 }}>
          <label htmlFor="ai_gemini_key" className="admin-muted" style={{ fontSize: '0.85rem' }}>
            Optional: your Gemini API key (browser only — overrides server if Edge is down)
          </label>
          <input
            id="ai_gemini_key"
            type="password"
            autoComplete="off"
            placeholder="AIza…"
            value={geminiKey}
            onChange={(e) => persistGeminiKey(e.target.value)}
          />
        </div>
        <label className="admin-row" style={{ gap: 8, marginTop: 10 }}>
          <input type="checkbox" checked={autoApply} onChange={(e) => setAutoApply(e.target.checked)} />
          <span style={{ fontSize: '0.88rem' }}>Auto-apply edits (recommended)</span>
        </label>
      </div>

      <div className="admin-row" style={{ flexWrap: 'wrap', gap: 8 }}>
        {QUICK_PROMPTS.map((p) => (
          <button key={p} type="button" className="admin-copilot__chip" disabled={busy} onClick={() => void runMessage(p)}>
            {p}
          </button>
        ))}
      </div>

      <div
        className="admin-panel admin-ai-chat"
        style={{ display: 'flex', flexDirection: 'column', minHeight: 320, maxHeight: 480 }}
      >
        <div className="admin-ai-chat__log" style={{ flex: 1, overflow: 'auto', padding: '4px 0' }}>
          {messages.map((m, i) => (
            <div
              key={i}
              className={`admin-ai-chat__msg admin-ai-chat__msg--${m.role}`}
              style={{
                marginBottom: 12,
                padding: '10px 12px',
                borderRadius: 8,
                background:
                  m.role === 'user' ? 'rgba(115, 248, 255, 0.08)' : 'rgba(166, 115, 255, 0.08)',
                lineHeight: 1.55,
                whiteSpace: 'pre-wrap',
                fontSize: '0.9rem',
              }}
            >
              {m.engine ? (
                <span className="admin-muted" style={{ fontSize: '0.72rem', display: 'block', marginBottom: 6 }}>
                  via {ENGINE_LABEL[m.engine] ?? m.engine}
                </span>
              ) : null}
              {m.text}
              {m.pendingActions?.length ? (
                <p className="admin-muted" style={{ margin: '10px 0 0', fontSize: '0.78rem' }}>
                  {m.pendingActions.length} action(s) — click Apply below.
                </p>
              ) : null}
            </div>
          ))}
        </div>
        <div className="admin-row" style={{ gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
          <input
            style={{ flex: 1, minWidth: 200 }}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                send();
              }
            }}
            placeholder='e.g. "add button Play now → /play/my-game"'
            disabled={busy}
          />
          <button type="button" disabled={busy || !input.trim()} onClick={send}>
            {busy ? 'Working…' : 'Send'}
          </button>
          {!autoApply ? (
            <button
              type="button"
              disabled={!lastResponse?.actions.length}
              onClick={applyPending}
              style={{ borderColor: 'rgba(62, 207, 142, 0.6)' }}
            >
              Apply suggestions
            </button>
          ) : null}
        </div>
        {error ? (
          <p style={{ color: 'var(--danger)', marginTop: 10, fontSize: '0.85rem' }} role="alert">
            {error}
          </p>
        ) : null}
      </div>

      <p className="admin-muted" style={{ fontSize: '0.78rem', lineHeight: 1.5 }}>
        After AI changes studio fields, click <strong>Save studio settings</strong>. Page/service drafts need Save on
        their tabs. CMS pages: uncheck <strong>Published</strong> while editing; built-in routes: Behavior → Built-in
        pages.
      </p>
    </div>
  );
}

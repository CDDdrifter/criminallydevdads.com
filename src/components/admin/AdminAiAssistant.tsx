import { useCallback, useEffect, useState } from 'react';
import type { Dispatch, SetStateAction } from 'react';
import { applyAdminAiActions } from '../../lib/adminAi/applyActions';
import { askAdminCopilot, chromeAiAvailable } from '../../lib/adminAi/askCopilot';
import { summarizeSettingsForAi } from '../../lib/adminAi/buildContext';
import type { AdminAiAction, AdminAiResponse } from '../../lib/adminAi/types';
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
  'open effects',
  'set mood to ember',
  'go to services',
  'how do I set up stripe',
  'create game demo service',
];

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
  const [messages, setMessages] = useState<Msg[]>([
    {
      role: 'assistant',
      text: 'Built-in site copilot — no API keys, no payment. I understand this admin panel and can open tabs, change hero copy, hub mood, nav flags, and draft services. Say "help" or use a quick button below.',
    },
  ]);
  const [lastResponse, setLastResponse] = useState<(AdminAiResponse & { engine?: string }) | null>(null);

  useEffect(() => {
    void chromeAiAvailable().then(setChromeAi);
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
          context: {
            currentTab,
            settingsSummary: summarizeSettingsForAi(settings),
            gamesCount,
            pagesCount,
            servicesCount,
          },
        });

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
        <h2 style={{ margin: '0 0 8px', fontSize: '1rem', color: 'var(--accent)' }}>🤖 Site copilot (free)</h2>
        <p className="admin-muted" style={{ marginTop: 0, lineHeight: 1.55, fontSize: '0.88rem' }}>
          Runs <strong>in your browser</strong> — no Gemini key, no Supabase secrets, nothing to pay. Uses built-in
          commands + site knowledge.{' '}
          {chromeAi ? (
            <span style={{ color: '#3ecf8e' }}>Chrome on-device AI is available as a bonus.</span>
          ) : (
            <span>Use Chrome desktop for optional on-device AI boost (still free).</span>
          )}
        </p>
        <label className="admin-row" style={{ gap: 8, marginTop: 10 }}>
          <input
            type="checkbox"
            checked={autoApply}
            onChange={(e) => setAutoApply(e.target.checked)}
          />
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
                  via {m.engine === 'chrome-on-device' ? 'Chrome on-device AI' : 'built-in copilot'}
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
            placeholder="Tell me what to change…"
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
        Not a full ChatGPT — for open-ended writing, edit text in Site copy / Pages. This copilot is tuned for{' '}
        <strong>this admin panel</strong> only.
      </p>
    </div>
  );
}

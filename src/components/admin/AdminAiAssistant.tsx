import { useCallback, useState } from 'react';
import { applyAdminAiActions } from '../../lib/adminAi/applyActions';
import { summarizeSettingsForAi } from '../../lib/adminAi/buildContext';
import { askAdminGemini } from '../../lib/adminAi/gemini';
import { loadGeminiApiKey, saveGeminiApiKey } from '../../lib/adminAi/storage';
import type { AdminAiAction, AdminAiResponse } from '../../lib/adminAi/types';
import type { SiteSettings } from '../../types';
import type { Dispatch, SetStateAction } from 'react';

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

type Msg = { role: 'user' | 'assistant'; text: string; pendingActions?: AdminAiAction[] };

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
  const [apiKey, setApiKey] = useState(() => loadGeminiApiKey());
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [messages, setMessages] = useState<Msg[]>([
    {
      role: 'assistant',
      text: 'I can navigate admin tabs, draft site copy, hub mood, behavior flags, and service gigs. Paste a free Gemini API key (stored only in this browser), ask anything, then Apply suggested changes and Save.',
    },
  ]);
  const [lastResponse, setLastResponse] = useState<AdminAiResponse | null>(null);

  const send = useCallback(async () => {
    const text = input.trim();
    if (!text || busy) return;
    setInput('');
    setError(null);
    setBusy(true);
    setMessages((m) => [...m, { role: 'user', text }]);

    const history = messages
      .filter((m) => m.role === 'user' || m.role === 'assistant')
      .slice(-10)
      .map((m) => ({
        role: (m.role === 'user' ? 'user' : 'model') as 'user' | 'model',
        text: m.text,
      }));

    try {
      const res = await askAdminGemini({
        apiKey,
        userMessage: text,
        history,
        context: {
          currentTab,
          settingsSummary: summarizeSettingsForAi(settings),
          gamesCount,
          pagesCount,
          servicesCount,
        },
      });
      setLastResponse(res);
      setMessages((m) => [
        ...m,
        { role: 'assistant', text: res.reply, pendingActions: res.actions.length ? res.actions : undefined },
      ]);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'AI request failed';
      setError(msg);
      setMessages((m) => [...m, { role: 'assistant', text: `Error: ${msg}` }]);
    } finally {
      setBusy(false);
    }
  }, [apiKey, busy, currentTab, gamesCount, input, messages, pagesCount, servicesCount, settings]);

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
    <div className="admin-grid" style={{ gap: 16 }}>
      <div className="admin-panel" style={{ borderColor: 'rgba(166, 115, 255, 0.4)' }}>
        <h2 style={{ margin: '0 0 8px', fontSize: '1rem', color: 'var(--accent)' }}>🤖 Admin AI (free tier)</h2>
        <p className="admin-muted" style={{ marginTop: 0, lineHeight: 1.55, fontSize: '0.88rem' }}>
          Uses <strong>Google Gemini</strong> from your browser — no GitHub secrets. Get a free key at{' '}
          <a href="https://aistudio.google.com/apikey" target="_blank" rel="noreferrer">
            Google AI Studio
          </a>
          . Key stays in <code>localStorage</code> on this device only. Changes apply to the <em>draft</em> until you
          click Save on the relevant tab.
        </p>
        <div className="admin-field" style={{ maxWidth: 520 }}>
          <label htmlFor="gemini_key">Gemini API key</label>
          <input
            id="gemini_key"
            type="password"
            autoComplete="off"
            value={apiKey}
            onChange={(e) => {
              setApiKey(e.target.value);
              saveGeminiApiKey(e.target.value);
            }}
            placeholder="AIza…"
          />
        </div>
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
              {m.text}
              {m.pendingActions?.length ? (
                <p className="admin-muted" style={{ margin: '10px 0 0', fontSize: '0.78rem' }}>
                  {m.pendingActions.length} suggested action(s) — click Apply below.
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
                void send();
              }
            }}
            placeholder="e.g. Set hub mood to ember and write a hire-us tagline…"
            disabled={busy}
          />
          <button type="button" disabled={busy || !input.trim()} onClick={() => void send()}>
            {busy ? 'Thinking…' : 'Ask'}
          </button>
          <button
            type="button"
            disabled={!lastResponse?.actions.length}
            onClick={applyPending}
            style={{ borderColor: 'rgba(62, 207, 142, 0.6)' }}
          >
            Apply suggestions
          </button>
        </div>
        {error ? (
          <p style={{ color: 'var(--danger)', marginTop: 10, fontSize: '0.85rem' }} role="alert">
            {error}
          </p>
        ) : null}
      </div>

      <details className="admin-panel admin-muted" style={{ fontSize: '0.82rem', lineHeight: 1.6 }}>
        <summary style={{ cursor: 'pointer', color: 'var(--accent)' }}>Example prompts</summary>
        <ul style={{ margin: '10px 0 0', paddingLeft: 18 }}>
          <li>“Open Effects and explain site mood vs per-game mood.”</li>
          <li>“Set hero title to CRIMINALLY DEV DADS and subtitle to indie games &amp; commissions.”</li>
          <li>“Draft a new service for $500 game prototypes with quote-only pricing.”</li>
          <li>“Turn on the Services nav link and maintenance mode off.”</li>
          <li>“How do I set up Stripe for tips without adding GitHub secrets?”</li>
        </ul>
      </details>
    </div>
  );
}

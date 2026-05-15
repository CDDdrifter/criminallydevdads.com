import { useCallback, useEffect, useState } from 'react';
import {
  adminMailingListCount,
  adminMailingListPreview,
  type MailingListPreviewRow,
} from '../../../lib/communityData';
import { invokeMailingBroadcast } from '../../../lib/mailingBroadcast';
import { FieldGroup } from '../StudioFields';

export function MailingListStudio() {
  const [count, setCount] = useState<number | null>(null);
  const [preview, setPreview] = useState<MailingListPreviewRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [subject, setSubject] = useState('');
  const [html, setHtml] = useState('<p>Hello — update from the site.</p>');
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [sendResult, setSendResult] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const c = await adminMailingListCount();
    if (c === null) {
      setError('Could not load list. Run migration 022 and sign in as an admin.');
      setCount(null);
      setPreview([]);
    } else {
      setCount(c);
      setPreview(await adminMailingListPreview(60));
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Mailing list (double opt-in from account page)"
        description={
          <>
            Subscribers are users who checked &quot;Email me updates&quot; on{' '}
            <strong>/account</strong>. Sending uses the Supabase Edge Function{' '}
            <code>mailing-broadcast</code> and{' '}
            <a href="https://resend.com" target="_blank" rel="noreferrer">
              Resend
            </a>
            . Set secrets: <code>RESEND_API_KEY</code>, <code>RESEND_FROM</code>
            (verified sender), plus <code>SUPABASE_SERVICE_ROLE_KEY</code> on the function. Deploy migration{' '}
            <code>022_profiles_username_mailing_list.sql</code>.
          </>
        }
      >
        <span className="admin-muted" style={{ fontSize: '0.82rem' }}>
          Use the sections below after refreshing subscriber counts.
        </span>
      </FieldGroup>

      {error ? (
        <p style={{ color: 'var(--danger)', lineHeight: 1.5 }} role="alert">
          {error}
        </p>
      ) : null}

      {loading ? (
        <p className="admin-muted">Loading…</p>
      ) : count !== null ? (
        <>
          <div className="admin-panel">
            <strong style={{ color: 'var(--accent)' }}>{count.toLocaleString()}</strong>{' '}
            <span className="admin-muted">opted-in subscribers</span>
            <button type="button" style={{ marginLeft: 12 }} onClick={() => void load()} disabled={loading}>
              Refresh
            </button>
          </div>

          <FieldGroup title="Recent subscribers (preview)" description="Masked: full list used when sending.">
            {preview.length === 0 ? (
              <p className="admin-muted">Nobody opted in yet.</p>
            ) : (
              <ul style={{ margin: 0, paddingLeft: 20, fontSize: '0.82rem', lineHeight: 1.6 }}>
                {preview.map((row) => (
                  <li key={`${row.email}-${row.username}`}>
                    <code>{row.email}</code> · @{row.username} · {row.display_name}
                    {row.opted_in_at ? (
                      <span className="admin-muted"> · {new Date(row.opted_in_at).toLocaleString()}</span>
                    ) : null}
                  </li>
                ))}
              </ul>
            )}
          </FieldGroup>

          <FieldGroup
            title="Broadcast email"
            description="One Resend message per subscriber (rate-limited). Use simple, accessible HTML."
          >
            <div className="admin-field">
              <label htmlFor="mail_subject">Subject</label>
              <input
                id="mail_subject"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                placeholder="Subject line"
                maxLength={200}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="mail_html">HTML body</label>
              <textarea
                id="mail_html"
                value={html}
                onChange={(e) => setHtml(e.target.value)}
                rows={12}
                style={{ width: '100%', fontFamily: 'monospace', fontSize: '0.85rem' }}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="mail_text">Plain text (optional)</label>
              <textarea
                id="mail_text"
                value={text}
                onChange={(e) => setText(e.target.value)}
                rows={4}
                style={{ width: '100%', fontFamily: 'monospace', fontSize: '0.85rem' }}
                placeholder="Falls back to empty if omitted"
              />
            </div>
            {sendResult ? (
              <p className="admin-muted" style={{ lineHeight: 1.55 }}>
                {sendResult}
              </p>
            ) : null}
            <div className="admin-row" style={{ gap: 12, flexWrap: 'wrap' }}>
              <button
                type="button"
                disabled={sending || count === 0 || !subject.trim() || !html.trim()}
                onClick={() => {
                  if (
                    !window.confirm(
                      `Send this email to all ${count} opted-in subscribers? This cannot be undone.`,
                    )
                  ) {
                    return;
                  }
                  setSending(true);
                  setSendResult(null);
                  void invokeMailingBroadcast({
                    subject: subject.trim(),
                    html: html.trim(),
                    text: text.trim() || undefined,
                  }).then((r) => {
                    setSending(false);
                    if (r.error) {
                      setSendResult(`Error: ${r.error}`);
                      return;
                    }
                    setSendResult(
                      `Done. Sent: ${r.sent ?? 0}, failed: ${r.failed ?? 0}, total: ${r.total ?? count}.` +
                        ((r.errors_sample?.length ?? 0) > 0
                          ? ` Sample errors: ${r.errors_sample!.join('; ')}`
                          : ''),
                    );
                  });
                }}
              >
                {sending ? 'Sending…' : `Send to all ${count} subscribers`}
              </button>
            </div>
          </FieldGroup>
        </>
      ) : null}
    </div>
  );
}

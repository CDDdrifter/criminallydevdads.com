import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { submitServiceRequest } from '../lib/communityData';
import { supabaseConfigured } from '../lib/supabase';
import type { ServiceView } from '../types';

type Props = {
  service?: ServiceView | null;
  heading?: string;
};

export function ServiceRequestForm({ service, heading }: Props) {
  const auth = useAuth();
  const [name, setName] = useState(auth.profile?.display_name ?? '');
  const [email, setEmail] = useState(auth.user?.email ?? '');
  const [message, setMessage] = useState('');
  const [budget, setBudget] = useState('');
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  if (!supabaseConfigured) {
    return <p className="admin-muted">Project requests require Supabase.</p>;
  }

  return (
    <form
      className="service-request-form admin-panel"
      onSubmit={(e) => {
        e.preventDefault();
        setBusy(true);
        setError(null);
        setStatus(null);
        void submitServiceRequest({
          serviceSlug: service?.slug,
          contactName: name,
          contactEmail: email,
          message,
          budgetNote: budget,
          userId: auth.user?.id,
        }).then((r) => {
          setBusy(false);
          if (r.ok) {
            setStatus('Request sent — we will reply by email soon.');
            setMessage('');
            setBudget('');
          } else {
            setError(r.error);
          }
        });
      }}
    >
      <h3 style={{ margin: '0 0 12px', fontSize: '1rem', color: 'var(--accent)' }}>
        {heading ?? (service ? `Request: ${service.title}` : 'General project inquiry')}
      </h3>
      <div className="admin-field">
        <label htmlFor="svc_req_name">Your name</label>
        <input id="svc_req_name" value={name} onChange={(e) => setName(e.target.value)} required />
      </div>
      <div className="admin-field">
        <label htmlFor="svc_req_email">Email</label>
        <input
          id="svc_req_email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="email"
        />
      </div>
      <div className="admin-field">
        <label htmlFor="svc_req_budget">Budget / timeline (optional)</label>
        <input
          id="svc_req_budget"
          placeholder="e.g. $2k, 3 weeks, flexible"
          value={budget}
          onChange={(e) => setBudget(e.target.value)}
        />
      </div>
      <div className="admin-field">
        <label htmlFor="svc_req_message">What do you need?</label>
        <textarea
          id="svc_req_message"
          rows={5}
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          required
          placeholder="Scope, references, platforms, links to similar work…"
        />
      </div>
      <button type="submit" className="btn-play" disabled={busy}>
        {busy ? 'Sending…' : 'Send request'}
      </button>
      {status ? (
        <p className="admin-muted" style={{ marginTop: 12, lineHeight: 1.5 }} role="status">
          {status}
        </p>
      ) : null}
      {error ? (
        <p style={{ color: 'var(--danger)', marginTop: 12, lineHeight: 1.5 }} role="alert">
          {error}
        </p>
      ) : null}
    </form>
  );
}

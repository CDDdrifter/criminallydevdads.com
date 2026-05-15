import { useCallback, useEffect, useState } from 'react';
import { fetchAnalyticsSummary, type AnalyticsSummary } from '../../../lib/communityData';
import { FieldGroup } from '../StudioFields';

type Props = {
  daysBack: number;
  onDaysBackChange: (n: number) => void;
};

export function AnalyticsStudio({ daysBack, onDaysBackChange }: Props) {
  const [summary, setSummary] = useState<AnalyticsSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const data = await fetchAnalyticsSummary(daysBack);
    if (!data) {
      setError(
        'Could not load analytics. Run migration 020 in Supabase SQL Editor and sign in as an admin.',
      );
      setSummary(null);
    } else {
      setSummary(data);
    }
    setLoading(false);
  }, [daysBack]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="First-party analytics (built-in)"
        description={
          <>
            Events are stored in <code>site_analytics_events</code> when Behavior → first-party analytics is on.
            Third-party tools (Plausible, GA4, etc.) are configured under SEO. Run migration{' '}
            <code>020_community_profiles_comments_analytics.sql</code> once.
          </>
        }
      >
        <div className="admin-field">
          <label htmlFor="analytics_days">Report window (days)</label>
          <input
            id="analytics_days"
            type="number"
            min={1}
            max={365}
            value={daysBack}
            onChange={(e) => onDaysBackChange(Math.max(1, Math.min(365, Number(e.target.value) || 30)))}
          />
        </div>
        <div className="admin-row" style={{ gap: 10, marginTop: 12 }}>
          <button type="button" onClick={() => void load()} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </FieldGroup>

      {error ? (
        <p style={{ color: 'var(--danger)', lineHeight: 1.5 }} role="alert">
          {error}
        </p>
      ) : null}

      {summary && !loading ? (
        <>
          <div className="analytics-kpi-grid">
            <Kpi label="Total events" value={summary.total_events} />
            <Kpi label="Page views" value={summary.page_views} />
            <Kpi label="Game plays" value={summary.game_plays} />
            <Kpi label="Unique sessions" value={summary.unique_sessions} />
            <Kpi label="Signed-in visitors" value={summary.signed_in_users} />
            <Kpi label="Registered profiles" value={summary.registered_profiles} />
            <Kpi label="Comments posted" value={summary.comments_posted} />
            <Kpi label="Sign-ins" value={summary.sign_ins} />
          </div>

          <div className="admin-grid" style={{ gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <div className="admin-panel">
              <h3 style={{ marginTop: 0, fontSize: '0.9rem' }}>Top pages</h3>
              {summary.top_paths.length === 0 ? (
                <p className="admin-muted">No page views yet.</p>
              ) : (
                <ol style={{ margin: 0, paddingLeft: 20 }}>
                  {summary.top_paths.map((row) => (
                    <li key={row.path} style={{ marginBottom: 6 }}>
                      <code>{row.path}</code> — {row.views}
                    </li>
                  ))}
                </ol>
              )}
            </div>
            <div className="admin-panel">
              <h3 style={{ marginTop: 0, fontSize: '0.9rem' }}>Top games (plays)</h3>
              {summary.top_games.length === 0 ? (
                <p className="admin-muted">No play events yet.</p>
              ) : (
                <ol style={{ margin: 0, paddingLeft: 20 }}>
                  {summary.top_games.map((row) => (
                    <li key={row.game_slug} style={{ marginBottom: 6 }}>
                      <code>{row.game_slug}</code> — {row.plays}
                    </li>
                  ))}
                </ol>
              )}
            </div>
          </div>

          <p className="admin-muted" style={{ fontSize: '0.8rem' }}>
            Since {new Date(summary.since).toLocaleString()} · {summary.days_back} day window
          </p>
        </>
      ) : loading ? (
        <p className="admin-muted">Loading analytics…</p>
      ) : null}
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: number }) {
  return (
    <div className="analytics-kpi admin-panel">
      <div className="analytics-kpi__value">{value.toLocaleString()}</div>
      <div className="analytics-kpi__label">{label}</div>
    </div>
  );
}

import { useCallback, useEffect, useState } from 'react';
import {
  adminListComments,
  adminListRecentProfiles,
  fetchAnalyticsSummary,
  type AdminCommentRow,
  type AdminProfileRow,
  type AnalyticsSummary,
  type GameAnalyticsRow,
} from '../../../lib/communityData';
import { FieldGroup } from '../StudioFields';

type Props = {
  daysBack: number;
  onDaysBackChange: (n: number) => void;
};

type DrillPanel = 'comments' | 'users' | null;

export function AnalyticsStudio({ daysBack, onDaysBackChange }: Props) {
  const [summary, setSummary] = useState<AnalyticsSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [drill, setDrill] = useState<DrillPanel>(null);
  const [comments, setComments] = useState<AdminCommentRow[]>([]);
  const [profiles, setProfiles] = useState<AdminProfileRow[]>([]);
  const [drillLoading, setDrillLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const data = await fetchAnalyticsSummary(daysBack);
    if (!data) {
      setError(
        'Could not load analytics. Run migrations 020, 021, and 024 in Supabase SQL Editor and sign in as an admin.',
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

  const openDrill = useCallback(
    async (panel: DrillPanel) => {
      if (!panel) {
        setDrill(null);
        return;
      }
      setDrill(panel);
      setDrillLoading(true);
      if (panel === 'comments') {
        setComments(await adminListComments(200, daysBack));
      } else {
        setProfiles(await adminListRecentProfiles(200));
      }
      setDrillLoading(false);
    },
    [daysBack],
  );

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="First-party analytics (built-in)"
        description={
          <>
            Events in <code>site_analytics_events</code> when Behavior → first-party analytics is on. Run migrations{' '}
            <code>020</code>, <code>021</code>, and <code>024</code> for drill-down lists and per-game stats.
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
            <Kpi label="App opens (HTML)" value={summary.events_by_type?.app_open ?? 0} />
            <Kpi label="Unique sessions" value={summary.unique_sessions} />
            <Kpi label="Signed-in visitors" value={summary.signed_in_users} />
            <Kpi
              label="Registered profiles"
              value={summary.registered_profiles}
              onClick={() => void openDrill('users')}
              hint="Click to list sign-ups"
            />
            <Kpi
              label="Comments posted"
              value={summary.comments_posted}
              onClick={() => void openDrill('comments')}
              hint="Click to list all comments"
            />
            <Kpi
              label="Comment events"
              value={summary.events_by_type?.comment_post ?? 0}
              onClick={() => void openDrill('comments')}
              hint="Click to list comments"
            />
            <Kpi label="Sign-ins" value={summary.sign_ins} onClick={() => void openDrill('users')} hint="Click to list users" />
          </div>

          {drill ? (
            <div className="admin-panel">
              <div className="admin-row" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
                <h3 style={{ margin: 0, fontSize: '0.95rem' }}>
                  {drill === 'comments' ? 'All comments' : 'Registered users'}
                </h3>
                <button type="button" onClick={() => setDrill(null)}>
                  Close
                </button>
              </div>
              {drillLoading ? (
                <p className="admin-muted" style={{ marginTop: 12 }}>
                  Loading…
                </p>
              ) : drill === 'comments' ? (
                <CommentList rows={comments} />
              ) : (
                <ProfileList rows={profiles} />
              )}
            </div>
          ) : null}

          <div className="admin-panel">
            <h3 style={{ marginTop: 0, fontSize: '0.9rem' }}>Per-game analytics</h3>
            {(summary.game_analytics ?? []).length === 0 ? (
              <p className="admin-muted">No published games or run migration 024.</p>
            ) : (
              <div style={{ overflowX: 'auto' }}>
                <table className="admin-table" style={{ width: '100%', fontSize: '0.85rem' }}>
                  <thead>
                    <tr>
                      <th style={{ textAlign: 'left' }}>Game</th>
                      <th>Plays</th>
                      <th>Hub views</th>
                      <th>Comments</th>
                      <th>Sessions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(summary.game_analytics ?? []).map((row) => (
                      <GameAnalyticsTableRow key={row.game_slug} row={row} />
                    ))}
                  </tbody>
                </table>
              </div>
            )}
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

function Kpi({
  label,
  value,
  onClick,
  hint,
}: {
  label: string;
  value: number;
  onClick?: () => void;
  hint?: string;
}) {
  const inner = (
    <>
      <div className="analytics-kpi__value">{value.toLocaleString()}</div>
      <div className="analytics-kpi__label">{label}</div>
      {hint ? (
        <div className="admin-muted" style={{ fontSize: '0.72rem', marginTop: 4 }}>
          {hint}
        </div>
      ) : null}
    </>
  );
  if (onClick) {
    return (
      <button
        type="button"
        className="analytics-kpi admin-panel"
        style={{ cursor: 'pointer', textAlign: 'left', width: '100%' }}
        onClick={onClick}
      >
        {inner}
      </button>
    );
  }
  return <div className="analytics-kpi admin-panel">{inner}</div>;
}

function GameAnalyticsTableRow({ row }: { row: GameAnalyticsRow }) {
  return (
    <tr>
      <td>
        <strong>{row.game_title || row.game_slug}</strong>
        <br />
        <code style={{ fontSize: '0.78rem' }}>{row.game_slug}</code>
      </td>
      <td style={{ textAlign: 'center' }}>{row.plays}</td>
      <td style={{ textAlign: 'center' }}>{row.page_views}</td>
      <td style={{ textAlign: 'center' }}>{row.comments}</td>
      <td style={{ textAlign: 'center' }}>{row.unique_sessions}</td>
    </tr>
  );
}

function CommentList({ rows }: { rows: AdminCommentRow[] }) {
  if (rows.length === 0) {
    return <p className="admin-muted" style={{ marginTop: 12 }}>No comments in this window.</p>;
  }
  return (
    <ul style={{ margin: '12px 0 0', padding: 0, listStyle: 'none', maxHeight: 420, overflow: 'auto' }}>
      {rows.map((c) => (
        <li
          key={c.id}
          style={{
            marginBottom: 10,
            padding: '10px 12px',
            borderRadius: 8,
            border: '1px solid rgba(115, 248, 255, 0.2)',
          }}
        >
          <div className="admin-muted" style={{ fontSize: '0.78rem', marginBottom: 4 }}>
            {new Date(c.created_at).toLocaleString()} ·{' '}
            <code>
              {c.target_type}/{c.target_key}
            </code>{' '}
            · @{c.username || 'player'}
            {c.author_email ? ` · ${c.author_email}` : ''}
          </div>
          <p style={{ margin: 0, lineHeight: 1.5, whiteSpace: 'pre-wrap' }}>{c.body}</p>
        </li>
      ))}
    </ul>
  );
}

function ProfileList({ rows }: { rows: AdminProfileRow[] }) {
  if (rows.length === 0) {
    return <p className="admin-muted" style={{ marginTop: 12 }}>No profiles yet.</p>;
  }
  return (
    <ul style={{ margin: '12px 0 0', padding: 0, listStyle: 'none', maxHeight: 420, overflow: 'auto' }}>
      {rows.map((p) => (
        <li
          key={p.id}
          style={{
            marginBottom: 8,
            padding: '8px 12px',
            borderRadius: 8,
            border: '1px solid rgba(115, 248, 255, 0.2)',
            fontSize: '0.85rem',
            lineHeight: 1.5,
          }}
        >
          <strong>{p.display_name}</strong> @{p.username}
          <br />
          {p.email || '(no email)'} · joined {new Date(p.created_at).toLocaleDateString()}
          {p.mailing_list_opt_in ? ' · ✉️ subscribed' : ''}
        </li>
      ))}
    </ul>
  );
}

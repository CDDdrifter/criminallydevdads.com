import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { fetchDevLogs } from '../lib/cmsData';
import type { DevLogPost } from '../types';

export function DevLogListPage() {
  const [posts, setPosts] = useState<DevLogPost[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    fetchDevLogs().then((p) => {
      if (!cancelled) {
        setPosts(p);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <header>
        <div className="header-title" style={{ fontSize: '2.2rem' }}>
          Dev log
        </div>
        <div className="header-subtitle">Build notes · design · chaos</div>
      </header>

      {loading && <div className="empty-state">Loading…</div>}

      {!loading && posts.length === 0 && (
        <div className="admin-panel">
          <p className="admin-muted">
            No posts yet. When Supabase is connected, add entries from <Link to="/admin">Admin → Dev logs</Link>.
          </p>
        </div>
      )}

      <div className="game-grid" style={{ gridTemplateColumns: '1fr' }}>
        {posts.map((p) => (
          <Link key={p.slug} to={`/devlog/${p.slug}`} style={{ textDecoration: 'none', color: 'inherit' }}>
            <div className="game-card" style={{ ['--i' as string]: 0 }}>
              <div className="game-info">
                <div className="game-type">Log</div>
                <div className="game-title">{p.title}</div>
                <div className="game-description">
                  {new Date(p.published_at).toLocaleDateString()} — click to read
                </div>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </SiteChrome>
  );
}

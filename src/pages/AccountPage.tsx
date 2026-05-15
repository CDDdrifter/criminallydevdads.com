import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { listUserGameSaves, type SiteGameSave } from '../lib/communityData';
import { supabaseConfigured } from '../lib/supabase';
import { SiteChrome } from '../components/SiteChrome';

export function AccountPage() {
  const auth = useAuth();
  const [saves, setSaves] = useState<SiteGameSave[]>([]);
  const [loadingSaves, setLoadingSaves] = useState(false);

  useEffect(() => {
    if (!auth.user?.id) {
      setSaves([]);
      return;
    }
    let cancelled = false;
    setLoadingSaves(true);
    void listUserGameSaves(auth.user.id).then((rows) => {
      if (!cancelled) {
        setSaves(rows);
        setLoadingSaves(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [auth.user?.id]);

  if (!supabaseConfigured) {
    return (
      <SiteChrome>
        <div className="empty-state">Sign-in requires Supabase configuration.</div>
      </SiteChrome>
    );
  }

  if (auth.loading) {
    return (
      <SiteChrome>
        <div className="empty-state">Loading account…</div>
      </SiteChrome>
    );
  }

  if (!auth.isSignedIn) {
    return (
      <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
        <article className="admin-panel page-article" style={{ maxWidth: 520, margin: '0 auto' }}>
          <h1 className="header-title" style={{ fontSize: '1.8rem', textAlign: 'left' }}>
            Your account
          </h1>
          <p className="admin-muted" style={{ lineHeight: 1.55 }}>
            Sign in with Google to sync cloud saves and post comments on any device. No username to pick — we use your
            Google name and photo.
          </p>
          <button type="button" className="user-auth-nav__google" onClick={() => void auth.signInWithGoogle()}>
            Sign in with Google
          </button>
        </article>
      </SiteChrome>
    );
  }

  const name = auth.profile?.display_name || auth.user?.email || 'Player';

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <article className="admin-panel page-article account-page">
        <header className="account-page__head">
          {auth.profile?.avatar_url ? (
            <img src={auth.profile.avatar_url} alt="" className="account-page__avatar" width={72} height={72} />
          ) : (
            <span className="account-page__avatar account-page__avatar--placeholder">
              {(name[0] ?? '?').toUpperCase()}
            </span>
          )}
          <div>
            <h1 className="header-title" style={{ fontSize: '1.8rem', textAlign: 'left', marginBottom: 4 }}>
              {name}
            </h1>
            <p className="admin-muted">{auth.user?.email}</p>
            {auth.isAdmin ? (
              <p className="admin-muted" style={{ marginTop: 8 }}>
                <Link to="/admin">Open Admin studio →</Link>
              </p>
            ) : null}
          </div>
        </header>

        <section style={{ marginTop: 28 }}>
          <h2 className="page-section-title" style={{ fontSize: '0.85rem', textTransform: 'uppercase' }}>
            Cloud game saves
          </h2>
          <p className="admin-muted" style={{ lineHeight: 1.55, marginBottom: 12 }}>
            Games that call <code>window.CDD.saveSave(slug, data)</code> store progress here. Same account on phone and
            laptop shares one save per game.
          </p>
          {loadingSaves ? (
            <p className="admin-muted">Loading saves…</p>
          ) : saves.length === 0 ? (
            <p className="admin-muted">No cloud saves yet. Play a game that supports CDD cloud sync.</p>
          ) : (
            <ul className="account-save-list">
              {saves.map((s) => (
                <li key={s.game_slug} className="account-save-list__item">
                  <Link to={`/game/${s.game_slug}`}>{s.game_slug}</Link>
                  <span className="admin-muted">
                    Updated {new Date(s.updated_at).toLocaleString()}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>

        <div className="admin-row" style={{ marginTop: 24, gap: 12 }}>
          <button type="button" onClick={() => void auth.signOut()}>
            Sign out
          </button>
        </div>
      </article>
    </SiteChrome>
  );
}

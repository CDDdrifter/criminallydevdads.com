import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  isUsernameAvailable,
  listUserGameSaves,
  updateMyProfile,
  type SiteGameSave,
} from '../lib/communityData';
import { firebaseConfigured } from '../lib/firebase';
import { MailingListOptInCard } from '../components/MailingListOptInCard';
import { SiteChrome } from '../components/SiteChrome';

export function AccountPage() {
  const auth = useAuth();
  const [saves, setSaves] = useState<SiteGameSave[]>([]);
  const [loadingSaves, setLoadingSaves] = useState(false);
  const [displayName, setDisplayName] = useState('');
  const [username, setUsername] = useState('');
  const [usernameHint, setUsernameHint] = useState<string | null>(null);
  const [profileMessage, setProfileMessage] = useState<string | null>(null);
  const [profileSaving, setProfileSaving] = useState(false);

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

  useEffect(() => {
    if (auth.profile) {
      setDisplayName(auth.profile.display_name);
      setUsername(auth.profile.username);
    }
  }, [auth.profile]);

  if (!firebaseConfigured) {
    return (
      <SiteChrome>
        <div className="empty-state">Sign-in requires Firebase configuration. See docs/NO_SUPABASE_SETUP.md</div>
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
            Sign in with Google to sync cloud saves and post comments. After you sign in you can choose a unique public
            username and opt into rare email updates from the site owners.
          </p>
          <button type="button" className="user-auth-nav__google" onClick={() => void auth.signInWithGoogle()}>
            Sign in with Google
          </button>
        </article>
      </SiteChrome>
    );
  }

  const name = auth.profile?.display_name || auth.user?.email || 'Player';
  const isNewAccount =
    auth.profile?.created_at != null &&
    Date.now() - new Date(auth.profile.created_at).getTime() < 1000 * 60 * 60 * 24 * 3;

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
            {auth.profile?.username ? (
              <p className="admin-muted" style={{ marginTop: 2 }}>
                Public handle <code>@{auth.profile.username}</code>
              </p>
            ) : null}
            {auth.isAdmin ? (
              <p className="admin-muted" style={{ marginTop: 8 }}>
                <Link to="/admin">Open Admin studio →</Link>
              </p>
            ) : null}
          </div>
        </header>

        <MailingListOptInCard variant={isNewAccount ? 'welcome' : 'default'} />

        <section style={{ marginTop: 28 }}>
          <h2 className="page-section-title" style={{ fontSize: '0.85rem', textTransform: 'uppercase' }}>
            Profile
          </h2>
          <p className="admin-muted" style={{ lineHeight: 1.55, marginBottom: 12 }}>
            Usernames are unique site-wide (lowercase, 3–32 characters). Newsletter opt-in is in the card above — toggle
            anytime.
          </p>
          <div className="admin-field" style={{ maxWidth: 420 }}>
            <label htmlFor="acct_display_name">Display name</label>
            <input
              id="acct_display_name"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              autoComplete="nickname"
            />
          </div>
          <div className="admin-field" style={{ maxWidth: 420 }}>
            <label htmlFor="acct_username">Username</label>
            <input
              id="acct_username"
              value={username}
              onChange={(e) => setUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
              onBlur={() => {
                void (async () => {
                  if (!auth.user?.id || !auth.profile) return;
                  const u = username.trim().toLowerCase();
                  if (u === auth.profile.username) {
                    setUsernameHint(null);
                    return;
                  }
                  const ok = await isUsernameAvailable(u, auth.user.id);
                  if (ok === true) setUsernameHint('Available');
                  else if (ok === false) setUsernameHint('Taken or invalid format');
                  else setUsernameHint('Could not verify availability');
                })();
              }}
              autoComplete="username"
              spellCheck={false}
            />
            {usernameHint ? <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 4 }}>{usernameHint}</p> : null}
          </div>
          {profileMessage ? (
            <p className="admin-muted" style={{ marginTop: 10, lineHeight: 1.5 }}>
              {profileMessage}
            </p>
          ) : null}
          <div className="admin-row" style={{ marginTop: 12 }}>
            <button
              type="button"
              disabled={profileSaving}
              onClick={() => {
                if (!auth.user?.id) return;
                setProfileSaving(true);
                setProfileMessage(null);
                void updateMyProfile(auth.user.id, {
                  display_name: displayName,
                  username: username.trim().toLowerCase(),
                  mailing_list_opt_in: auth.profile?.mailing_list_opt_in ?? false,
                }).then(async (r) => {
                  setProfileSaving(false);
                  if (r.ok) {
                    setProfileMessage('Saved.');
                    await auth.refreshProfile();
                  } else {
                    setProfileMessage(r.error);
                  }
                });
              }}
            >
              {profileSaving ? 'Saving…' : 'Save profile'}
            </button>
          </div>
        </section>

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

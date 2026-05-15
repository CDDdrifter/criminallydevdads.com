import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { humanizeOAuthError } from '../lib/authErrors';
import { supabaseConfigured } from '../lib/supabase';
import { useSiteSettings } from '../hooks/useSiteSettings';

/**
 * Header sign-in / account control for public visitors (Google OAuth).
 */
export function UserAuthNav() {
  const auth = useAuth();
  const { settings } = useSiteSettings();
  const b = settings.behavior;
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (!supabaseConfigured) {
    return null;
  }
  if (b?.player_google_sign_in_enabled === false) {
    return null;
  }
  if (b?.show_player_sign_in_nav === false) {
    return null;
  }

  if (auth.loading) {
    return <span className="admin-muted user-auth-nav__loading">…</span>;
  }

  if (auth.isSignedIn && auth.user) {
    const name = auth.profile?.display_name || auth.user.email?.split('@')[0] || 'Account';
    const avatar = auth.profile?.avatar_url;
    return (
      <span className="user-auth-nav">
        <Link to="/account" className="user-auth-nav__account" title="Your account">
          {avatar ? (
            <img src={avatar} alt="" className="user-auth-nav__avatar" width={28} height={28} />
          ) : (
            <span className="user-auth-nav__avatar user-auth-nav__avatar--placeholder" aria-hidden>
              {(name[0] ?? '?').toUpperCase()}
            </span>
          )}
          <span className="user-auth-nav__name">{name}</span>
        </Link>
        <button
          type="button"
          className="user-auth-nav__signout"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            try {
              await auth.signOut();
            } finally {
              setBusy(false);
            }
          }}
        >
          Sign out
        </button>
      </span>
    );
  }

  return (
    <span className="user-auth-nav">
      <button
        type="button"
        className="user-auth-nav__google"
        disabled={busy}
        onClick={async () => {
          setErr(null);
          setBusy(true);
          try {
            await auth.signInWithGoogle();
          } catch (e) {
            setErr(humanizeOAuthError(e instanceof Error ? e.message : 'Sign-in failed'));
          } finally {
            setBusy(false);
          }
        }}
      >
        {busy ? '…' : 'Sign in with Google'}
      </button>
      {err ? (
        <span className="user-auth-nav__error admin-muted" role="alert">
          {err}
        </span>
      ) : null}
    </span>
  );
}

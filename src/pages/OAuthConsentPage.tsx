import { useCallback, useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { useAuth } from '../context/AuthContext';
import { stashAuthReturn } from '../lib/authBootstrap';
import { supabase, supabaseConfigured } from '../lib/supabase';

type ConsentDetails = {
  authorization_id: string;
  client: { name: string; icon_url?: string };
  scope: string;
  redirect_uri: string;
};

function isConsentDetails(data: unknown): data is ConsentDetails {
  return Boolean(data && typeof data === 'object' && 'authorization_id' in data);
}

function isOAuthRedirect(data: unknown): data is { redirect_url: string } {
  return Boolean(data && typeof data === 'object' && 'redirect_url' in data);
}

/**
 * Supabase OAuth 2.1 server consent UI (Authentication → OAuth Server).
 * Preview URL: https://yoursite.com/#/oauth/consent
 * Live flow: SITE_URL/oauth/consent → bootstrap rewrites to /#/oauth/consent?authorization_id=…
 */
export function OAuthConsentPage() {
  const auth = useAuth();
  const [searchParams] = useSearchParams();
  const authorizationId = searchParams.get('authorization_id')?.trim() ?? '';

  const [details, setDetails] = useState<ConsentDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadDetails = useCallback(async () => {
    if (!supabaseConfigured || !supabase || !authorizationId) {
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    const { data, error: err } = await supabase.auth.oauth.getAuthorizationDetails(authorizationId);
    setLoading(false);
    if (err) {
      setError(err.message);
      return;
    }
    if (isOAuthRedirect(data)) {
      window.location.href = data.redirect_url;
      return;
    }
    if (isConsentDetails(data)) {
      setDetails(data);
    } else {
      setError('Unexpected response from authorization server.');
    }
  }, [authorizationId]);

  useEffect(() => {
    if (!authorizationId) {
      setLoading(false);
      return;
    }
    if (!auth.isSignedIn) {
      setLoading(false);
      return;
    }
    void loadDetails();
  }, [authorizationId, auth.isSignedIn, loadDetails]);

  const onSignIn = async () => {
    if (!authorizationId) return;
    stashAuthReturn(`/oauth/consent?authorization_id=${encodeURIComponent(authorizationId)}`);
    try {
      await auth.signInWithGoogle(
        `/oauth/consent?authorization_id=${encodeURIComponent(authorizationId)}`,
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Sign-in failed');
    }
  };

  const onApprove = async () => {
    if (!supabase || !authorizationId) return;
    setBusy(true);
    setError(null);
    const { data, error: err } = await supabase.auth.oauth.approveAuthorization(authorizationId, {
      skipBrowserRedirect: true,
    });
    setBusy(false);
    if (err) {
      setError(err.message);
      return;
    }
    if (data && 'redirect_url' in data) {
      window.location.href = data.redirect_url;
    }
  };

  const onDeny = async () => {
    if (!supabase || !authorizationId) return;
    setBusy(true);
    const { data, error: err } = await supabase.auth.oauth.denyAuthorization(authorizationId, {
      skipBrowserRedirect: true,
    });
    setBusy(false);
    if (err) {
      setError(err.message);
      return;
    }
    if (data && 'redirect_url' in data) {
      window.location.href = data.redirect_url;
    }
  };

  if (!supabaseConfigured) {
    return (
      <SiteChrome>
        <div className="empty-state">Supabase not configured.</div>
      </SiteChrome>
    );
  }

  if (!authorizationId) {
    return (
      <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
        <article className="admin-panel page-article" style={{ maxWidth: 560, margin: '0 auto' }}>
          <h1 className="header-title" style={{ fontSize: '1.6rem', textAlign: 'left' }}>
            OAuth consent
          </h1>
          <p className="admin-muted" style={{ lineHeight: 1.55 }}>
            Missing <code>authorization_id</code> in the URL. Supabase OAuth Server sends users here during third-party
            app authorization. For normal site sign-in, use <strong>Sign in with Google</strong> in the header or{' '}
            <Link to="/account">Account</Link>.
          </p>
        </article>
      </SiteChrome>
    );
  }

  if (!auth.isSignedIn) {
    return (
      <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
        <article className="admin-panel page-article oauth-consent" style={{ maxWidth: 520, margin: '0 auto' }}>
          <h1 className="header-title" style={{ fontSize: '1.6rem', textAlign: 'left' }}>
            Sign in to continue
          </h1>
          <p className="admin-muted" style={{ lineHeight: 1.55, marginBottom: 20 }}>
            An app is requesting access to your Criminally Dev Dads account. Sign in with Google to review and approve.
          </p>
          <button type="button" className="user-auth-nav__google" disabled={auth.loading} onClick={() => void onSignIn()}>
            Sign in with Google
          </button>
          {error ? (
            <p style={{ color: 'var(--danger)', marginTop: 12 }} role="alert">
              {error}
            </p>
          ) : null}
        </article>
      </SiteChrome>
    );
  }

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <article className="admin-panel page-article oauth-consent" style={{ maxWidth: 560, margin: '0 auto' }}>
        <h1 className="header-title" style={{ fontSize: '1.6rem', textAlign: 'left' }}>
          Authorize application
        </h1>

        {loading ? (
          <p className="admin-muted" style={{ marginTop: 16 }}>
            Loading request…
          </p>
        ) : details ? (
          <>
            <p style={{ marginTop: 16, lineHeight: 1.55 }}>
              <strong>{details.client.name}</strong> wants access to your account.
            </p>
            {details.client.icon_url ? (
              <img
                src={details.client.icon_url}
                alt=""
                style={{ width: 48, height: 48, marginTop: 12, borderRadius: 8 }}
              />
            ) : null}
            <p className="admin-muted" style={{ marginTop: 12, fontSize: '0.85rem' }}>
              Scopes: <code>{details.scope || 'default'}</code>
            </p>
            <p className="admin-muted" style={{ fontSize: '0.8rem' }}>
              Redirect: <code>{details.redirect_uri}</code>
            </p>
            <div className="admin-row" style={{ marginTop: 24, gap: 12, flexWrap: 'wrap' }}>
              <button type="button" disabled={busy} onClick={() => void onApprove()}>
                {busy ? '…' : 'Allow'}
              </button>
              <button type="button" disabled={busy} onClick={() => void onDeny()}>
                Deny
              </button>
            </div>
          </>
        ) : null}

        {error ? (
          <p style={{ color: 'var(--danger)', marginTop: 16, lineHeight: 1.5 }} role="alert">
            {error}
            <br />
            <span className="admin-muted" style={{ fontSize: '0.82rem' }}>
              Enable OAuth 2.1 server in Supabase → Authentication → OAuth Server and run migration 020 if tables are
              missing.
            </span>
          </p>
        ) : null}
      </article>
    </SiteChrome>
  );
}

import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { popAuthReturn } from '../lib/authBootstrap';
import { humanizeOAuthError } from '../lib/authErrors';
import { auth, firebaseConfigured } from '../lib/firebase';

/**
 * Handles Firebase redirect sign-in completion.
 * Popup sign-in does not need this page — redirect fallback does.
 */
export function AuthCallbackPage() {
  const navigate = useNavigate();
  const [detail, setDetail] = useState<string | null>(null);

  useEffect(() => {
    if (!firebaseConfigured || !auth) {
      setDetail('Firebase is not configured on this build. See docs/NO_SUPABASE_SETUP.md');
      return;
    }

    const params = new URLSearchParams(window.location.search);
    const oauthError = params.get('error_description') ?? params.get('error');
    if (oauthError) {
      setDetail(humanizeOAuthError(oauthError));
      return;
    }

    // onAuthStateChanged in AuthContext handles getRedirectResult — just wait briefly then redirect
    const timer = window.setTimeout(() => {
      if (auth?.currentUser) {
        navigate(popAuthReturn(), { replace: true });
      } else {
        navigate('/', { replace: true });
      }
    }, 1500);

    return () => window.clearTimeout(timer);
  }, [navigate]);

  return (
    <SiteChrome>
      <div className="admin-panel page-article" style={{ maxWidth: 480, margin: '40px auto', textAlign: 'center' }}>
        <h1 className="header-title" style={{ fontSize: '1.4rem' }}>
          Signing you in…
        </h1>
        {detail ? (
          <p style={{ color: 'var(--danger)', marginTop: 16, lineHeight: 1.5 }} role="alert">
            {detail}
          </p>
        ) : (
          <p className="admin-muted" style={{ marginTop: 16 }}>
            Completing Google sign-in. If this takes more than a few seconds, check Firebase authorized domains.
          </p>
        )}
      </div>
    </SiteChrome>
  );
}

import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { SiteChrome } from '../components/SiteChrome';
import { popAuthReturn } from '../lib/authBootstrap';

/** Legacy route — redirect sign-in completes on whatever page you started from. */
export function AuthCallbackPage() {
  const navigate = useNavigate();
  const auth = useAuth();

  useEffect(() => {
    if (auth.loading) {
      return;
    }
    navigate(auth.isSignedIn ? popAuthReturn() : '/', { replace: true });
  }, [auth.loading, auth.isSignedIn, navigate]);

  return (
    <SiteChrome>
      <div className="admin-panel page-article" style={{ maxWidth: 480, margin: '40px auto', textAlign: 'center' }}>
        <h1 className="header-title" style={{ fontSize: '1.4rem' }}>
          Signing you in…
        </h1>
        {auth.authInitError ? (
          <p style={{ color: 'var(--danger)', marginTop: 16, lineHeight: 1.5 }} role="alert">
            {auth.authInitError}
          </p>
        ) : (
          <p className="admin-muted" style={{ marginTop: 16 }}>
            Completing Google sign-in…
          </p>
        )}
      </div>
    </SiteChrome>
  );
}

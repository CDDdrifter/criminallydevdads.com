import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { useAuth } from '../context/AuthContext';
import { cleanOAuthQueryFromUrl, popAuthReturn } from '../lib/authBootstrap';
import { decodeOAuthQueryValue, humanizeOAuthError } from '../lib/authErrors';
import { supabase, supabaseConfigured } from '../lib/supabase';

/**
 * PKCE `code` may arrive in the hash query (`/#/auth/callback?code=…`) because we use HashRouter.
 * `window.location.search` is often empty then — use `useSearchParams()` (or hash fallback).
 */
function oauthParamsFromLocation(searchParams: URLSearchParams): URLSearchParams {
  if (searchParams.get('code') || searchParams.get('error') || searchParams.get('error_description')) {
    return searchParams;
  }
  const hash = window.location.hash;
  if (hash.includes('?')) {
    return new URLSearchParams(hash.split('?')[1] ?? '');
  }
  return new URLSearchParams(window.location.search);
}

/**
 * Finishes Google / magic-link sign-in (PKCE `?code=` on the redirect URL).
 * Listed in Supabase → Redirect URLs as your site root; we route users here after exchange.
 */
export function AuthCallbackPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [detail, setDetail] = useState<string | null>(null);

  const paramKey = useMemo(() => {
    const p = oauthParamsFromLocation(searchParams);
    return `${p.get('code') ?? ''}|${p.get('error') ?? ''}|${p.get('error_description') ?? ''}`;
  }, [searchParams]);

  useEffect(() => {
    if (!supabaseConfigured || !supabase) {
      setDetail('Supabase is not configured on this build.');
      return;
    }

    const params = oauthParamsFromLocation(searchParams);
    const code = params.get('code');
    const oauthError = params.get('error_description') ?? params.get('error');

    if (oauthError) {
      setDetail(humanizeOAuthError(decodeOAuthQueryValue(oauthError)));
      return;
    }

    let cancelled = false;

    (async () => {
      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code);
        if (error && !cancelled) {
          setDetail(humanizeOAuthError(error.message));
          return;
        }
        cleanOAuthQueryFromUrl();
      }

      if (cancelled) return;

      if (auth.loading) return;

      if (auth.user) {
        const dest = popAuthReturn();
        navigate(dest, { replace: true });
        return;
      }

      if (!code) {
        setDetail('No sign-in code in the URL. Try Sign in with Google again.');
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [paramKey, auth.loading, auth.user, navigate, searchParams]);

  useEffect(() => {
    if (auth.loading || !auth.user) return;
    const dest = popAuthReturn();
    navigate(dest, { replace: true });
  }, [auth.loading, auth.user, navigate]);

  return (
    <SiteChrome>
      <div className="admin-panel page-article" style={{ maxWidth: 480, margin: '40px auto', textAlign: 'center' }}>
        <h1 className="header-title" style={{ fontSize: '1.4rem' }}>Signing you in…</h1>
        {detail ? (
          <p style={{ color: 'var(--danger)', marginTop: 16, lineHeight: 1.5 }} role="alert">
            {detail}
          </p>
        ) : (
          <p className="admin-muted" style={{ marginTop: 16 }}>
            Completing Google sign-in. If this takes more than a few seconds, check Supabase redirect URLs and Google
            OAuth client settings.
          </p>
        )}
      </div>
    </SiteChrome>
  );
}

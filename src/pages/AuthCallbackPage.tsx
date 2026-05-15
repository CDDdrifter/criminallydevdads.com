import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
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
 * GoTrue may already exchange the code during `getSession()` → `initialize()` when `code` is in the URL.
 * We must not call `exchangeCodeForSession` again (second call consumes no verifier → "PKCE code verifier not found").
 * Do not depend on `auth.user` / `auth.loading` here — that re-runs the effect after login and duplicated exchange.
 */
export function AuthCallbackPage() {
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

    void (async () => {
      await supabase.auth.getSession();

      if (cancelled) return;

      let {
        data: { session },
      } = await supabase.auth.getSession();

      if (session?.user) {
        cleanOAuthQueryFromUrl();
        navigate(popAuthReturn(), { replace: true });
        return;
      }

      if (!code) {
        if (!cancelled) {
          setDetail('No sign-in code in the URL. Try Sign in with Google again.');
        }
        return;
      }

      const { error } = await supabase.auth.exchangeCodeForSession(code);

      if (cancelled) return;

      if (error) {
        ({
          data: { session },
        } = await supabase.auth.getSession());
        if (session?.user) {
          cleanOAuthQueryFromUrl();
          navigate(popAuthReturn(), { replace: true });
          return;
        }
        setDetail(humanizeOAuthError(error.message));
        return;
      }

      cleanOAuthQueryFromUrl();

      ({
        data: { session },
      } = await supabase.auth.getSession());

      if (session?.user) {
        navigate(popAuthReturn(), { replace: true });
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [paramKey, navigate, searchParams]);

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

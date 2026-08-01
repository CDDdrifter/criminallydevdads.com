/**
 * Complete Firebase redirect sign-in exactly once per full page load.
 * Must run before React StrictMode remounts or any URL rewrite (see authBootstrap.ts).
 */
import { getRedirectResult, type Auth, type UserCredential } from 'firebase/auth';

let redirectResultOnce: Promise<UserCredential | null> | null = null;

export async function completeRedirectSignIn(auth: Auth): Promise<UserCredential | null> {
  if (!redirectResultOnce) {
    redirectResultOnce = getRedirectResult(auth);
  }
  try {
    return await redirectResultOnce;
  } catch (err) {
    redirectResultOnce = null;
    throw err;
  }
}

/** Remove Firebase OAuth query params from the address bar after redirect. */
export function cleanFirebaseAuthParamsFromUrl() {
  if (typeof window === 'undefined') {
    return;
  }
  const url = new URL(window.location.href);
  const keys = [
    'apiKey',
    'authType',
    'providerId',
    'redirectUrl',
    'scope',
    'state',
    'code',
    'error',
    'error_description',
  ];
  let changed = false;
  for (const key of keys) {
    if (url.searchParams.has(key)) {
      url.searchParams.delete(key);
      changed = true;
    }
  }
  if (changed) {
    const next = `${url.pathname}${url.search}${url.hash}`;
    window.history.replaceState(window.history.state, '', next || '/');
  }
}

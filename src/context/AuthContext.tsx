import type { User } from 'firebase/auth';
import {
  GoogleAuthProvider,
  getRedirectResult,
  onAuthStateChanged,
  signInWithPopup,
  signInWithRedirect,
  signOut as firebaseSignOut,
} from 'firebase/auth';
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { isAdminEmail } from '../lib/adminConfig';
import { popAuthReturn, stashAuthReturn } from '../lib/authBootstrap';
import { humanizeOAuthError } from '../lib/authErrors';
import { installGameCloudBridge } from '../lib/gameCloudBridge';
import { auth, initFirebase } from '../lib/firebase';

export type AuthProfile = {
  display_name: string;
  avatar_url: string;
  username: string;
  mailing_list_opt_in?: boolean;
  created_at?: string;
};

export type AppUser = {
  id: string;
  email: string | null;
  displayName: string | null;
  photoURL: string | null;
};

type AuthState = {
  user: AppUser | null;
  profile: AuthProfile | null;
  loading: boolean;
  isAdmin: boolean;
  isSignedIn: boolean;
  adminCheckError: string | null;
  authConfigured: boolean;
  authInitError: string | null;
  signInWithGoogle: (returnPath?: string) => Promise<void>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

function mapUser(u: User): AppUser {
  return {
    id: u.uid,
    email: u.email,
    displayName: u.displayName,
    photoURL: u.photoURL,
  };
}

function profileFromUser(user: User): AuthProfile {
  return {
    display_name: user.displayName ?? user.email?.split('@')[0] ?? 'Player',
    avatar_url: user.photoURL ?? '',
    username: '',
    mailing_list_opt_in: false,
    created_at: user.metadata.creationTime ?? undefined,
  };
}

function preferRedirectSignIn(): boolean {
  if (typeof window === 'undefined') {
    return false;
  }
  const host = window.location.hostname;
  return host !== 'localhost' && host !== '127.0.0.1';
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AppUser | null>(null);
  const [profile, setProfile] = useState<AuthProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);
  const [adminCheckError, setAdminCheckError] = useState<string | null>(null);
  const [authConfigured, setAuthConfigured] = useState(false);
  const [authInitError, setAuthInitError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    let unsub: (() => void) | undefined;

    void (async () => {
      const ready = await initFirebase();
      if (cancelled) {
        return;
      }

      if (!ready || !auth) {
        setAuthConfigured(false);
        setAuthInitError(
          'Firebase is not configured. Paste your 4 Firebase values into cms/firebase-config.json in the repo, commit, and redeploy — see docs/FIREBASE_SETUP.md',
        );
        setLoading(false);
        return;
      }

      setAuthConfigured(true);
      setAuthInitError(null);

      try {
        const redirectResult = await getRedirectResult(auth);
        if (redirectResult?.user && !cancelled) {
          setUser(mapUser(redirectResult.user));
          setProfile(profileFromUser(redirectResult.user));
          const admin = await isAdminEmail(redirectResult.user.email);
          if (!cancelled) {
            setIsAdmin(admin);
          }
          const returnPath = popAuthReturn();
          if (returnPath && returnPath !== window.location.pathname) {
            window.history.replaceState({}, '', returnPath);
          }
        }
      } catch (err) {
        console.warn('[auth] getRedirectResult failed', err);
        if (!cancelled) {
          setAuthInitError(humanizeOAuthError(err instanceof Error ? err.message : String(err)));
        }
      }

      unsub = onAuthStateChanged(auth, async (next) => {
        if (cancelled) {
          return;
        }
        setUser(next ? mapUser(next) : null);
        setAdminCheckError(null);

        if (!next) {
          setProfile(null);
          setIsAdmin(false);
          setLoading(false);
          return;
        }

        setProfile(profileFromUser(next));
        try {
          const admin = await isAdminEmail(next.email);
          if (!cancelled) {
            setIsAdmin(admin);
          }
        } catch (err) {
          if (!cancelled) {
            setIsAdmin(false);
            setAdminCheckError(err instanceof Error ? err.message : 'Could not verify admin access');
          }
        }
        if (!cancelled) {
          setLoading(false);
        }
      });
    })();

    return () => {
      cancelled = true;
      unsub?.();
    };
  }, []);

  useEffect(() => {
    installGameCloudBridge(() => user?.id ?? null);
  }, [user?.id]);

  const refreshProfile = useCallback(async () => {
    // Profile is derived from Firebase user — no separate backend to refresh.
  }, []);

  const signInWithGoogle = useCallback(async (returnPath?: string) => {
    const ready = await initFirebase();
    if (!ready || !auth) {
      throw new Error(
        'Firebase is not configured. Edit cms/firebase-config.json with your Firebase web app config, commit, push, and redeploy.',
      );
    }
    stashAuthReturn(returnPath);
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ prompt: 'select_account' });

    if (preferRedirectSignIn()) {
      await signInWithRedirect(auth, provider);
      return;
    }

    try {
      await signInWithPopup(auth, provider);
    } catch (err) {
      const code = err && typeof err === 'object' && 'code' in err ? String((err as { code: string }).code) : '';
      if (
        code === 'auth/popup-blocked' ||
        code === 'auth/popup-closed-by-user' ||
        code === 'auth/cancelled-popup-request'
      ) {
        await signInWithRedirect(auth, provider);
        return;
      }
      throw err;
    }
  }, []);

  const signOut = useCallback(async () => {
    if (!auth) {
      return;
    }
    await firebaseSignOut(auth);
    setProfile(null);
    setIsAdmin(false);
  }, []);

  const value = useMemo(
    () => ({
      user,
      profile,
      loading,
      isAdmin,
      isSignedIn: Boolean(user),
      adminCheckError,
      authConfigured,
      authInitError,
      signInWithGoogle,
      signOut,
      refreshProfile,
    }),
    [
      user,
      profile,
      loading,
      isAdmin,
      adminCheckError,
      authConfigured,
      authInitError,
      signInWithGoogle,
      signOut,
      refreshProfile,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return ctx;
}

import type { Session, User } from '@supabase/supabase-js';
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { getOAuthRedirectUrl, stashAuthReturn } from '../lib/authBootstrap';
import { trackSignIn } from '../lib/analytics';
import { ensureProfile, fetchProfile, type SiteProfile } from '../lib/communityData';
import { installGameCloudBridge } from '../lib/gameCloudBridge';
import { supabase, supabaseConfigured } from '../lib/supabase';

type AuthState = {
  session: Session | null;
  user: User | null;
  profile: SiteProfile | null;
  loading: boolean;
  isAdmin: boolean;
  isSignedIn: boolean;
  adminCheckError: string | null;
  signInWithGoogle: (returnPath?: string) => Promise<void>;
  signInWithEmail: (email: string) => Promise<void>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

function metaFromUser(user: User) {
  const m = user.user_metadata ?? {};
  return {
    name: String(m.full_name ?? m.name ?? user.email?.split('@')[0] ?? 'Player'),
    avatar: String(m.avatar_url ?? m.picture ?? ''),
  };
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<SiteProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [serverIsAdmin, setServerIsAdmin] = useState(false);
  const [adminCheckError, setAdminCheckError] = useState<string | null>(null);

  const loadProfile = useCallback(async (user: User | null) => {
    if (!user) {
      setProfile(null);
      return;
    }
    const meta = metaFromUser(user);
    let p = await fetchProfile(user.id);
    if (!p) {
      p = await ensureProfile(user.id, meta);
    }
    setProfile(p);
  }, []);

  const applySession = useCallback(
    async (next: Session | null, event?: string) => {
      setSession(next);
      setAdminCheckError(null);
      if (!supabase) {
        setServerIsAdmin(false);
        setProfile(null);
        return;
      }
      if (!next?.user) {
        setServerIsAdmin(false);
        setProfile(null);
        return;
      }

      await loadProfile(next.user);

      const { data, error } = await supabase.rpc('is_site_admin');
      if (error) {
        console.error('is_site_admin RPC failed', error);
        setServerIsAdmin(false);
        setAdminCheckError(
          error.message ||
            'Could not verify editor access. Run supabase/schema.sql in the SQL Editor, then try again.',
        );
      } else {
        setServerIsAdmin(data === true);
      }

      if (event === 'SIGNED_IN') {
        void trackSignIn(next.user.id);
      }
    },
    [loadProfile],
  );

  useEffect(() => {
    if (!supabaseConfigured || !supabase) {
      setLoading(false);
      return;
    }

    let cancelled = false;

    supabase.auth.getSession().then(({ data }) => {
      if (cancelled) {
        return;
      }
      void applySession(data.session ?? null).finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, next) => {
      setLoading(true);
      void applySession(next, event).finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });
    });

    return () => {
      cancelled = true;
      subscription.unsubscribe();
    };
  }, [applySession]);

  const user = session?.user ?? null;
  const isAdmin = serverIsAdmin;
  const isSignedIn = Boolean(user);

  useEffect(() => {
    installGameCloudBridge(() => user?.id ?? null);
  }, [user?.id]);

  const signInWithGoogle = useCallback(async (returnPath?: string) => {
    if (!supabase) {
      throw new Error('Supabase is not configured');
    }
    stashAuthReturn(returnPath);
    const redirectTo = getOAuthRedirectUrl();
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo,
        queryParams: {
          prompt: 'select_account',
          access_type: 'online',
        },
      },
    });
    if (error) {
      throw error;
    }
  }, []);

  const signInWithEmail = useCallback(async (email: string) => {
    if (!supabase) {
      throw new Error('Supabase is not configured');
    }
    const trimmed = email.trim().toLowerCase();
    const { data: allowed, error: allowErr } = await supabase.rpc('can_request_editor_login', {
      check_email: trimmed,
    });
    if (allowErr) {
      throw allowErr;
    }
    if (!allowed) {
      throw new Error(
        'This email is not on the editor allow list. In Supabase → SQL, add the domain to site_admin_domains or your exact address to site_admin_emails.',
      );
    }
    const redirectTo = getOAuthRedirectUrl();
    const { error } = await supabase.auth.signInWithOtp({
      email: trimmed,
      options: { emailRedirectTo: redirectTo },
    });
    if (error) {
      throw error;
    }
  }, []);

  const signOut = useCallback(async () => {
    if (!supabase) {
      return;
    }
    await supabase.auth.signOut();
    setProfile(null);
  }, []);

  const refreshProfile = useCallback(async () => {
    if (user) {
      await loadProfile(user);
    }
  }, [user, loadProfile]);

  const value = useMemo(
    () => ({
      session,
      user,
      profile,
      loading,
      isAdmin,
      isSignedIn,
      adminCheckError,
      signInWithGoogle,
      signInWithEmail,
      signOut,
      refreshProfile,
    }),
    [
      session,
      user,
      profile,
      loading,
      isAdmin,
      isSignedIn,
      adminCheckError,
      signInWithGoogle,
      signInWithEmail,
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

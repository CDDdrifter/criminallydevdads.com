import type { Session, User } from '@supabase/supabase-js';
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { supabase, supabaseConfigured } from '../lib/supabase';

type AuthState = {
  session: Session | null;
  user: User | null;
  loading: boolean;
  isAdmin: boolean;
  signInWithGoogle: () => Promise<void>;
  signInWithEmail: (email: string) => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [serverIsAdmin, setServerIsAdmin] = useState(false);

  const applySession = useCallback(async (next: Session | null) => {
    setSession(next);
    if (!supabase) {
      setServerIsAdmin(false);
      return;
    }
    if (!next?.user) {
      setServerIsAdmin(false);
      return;
    }
    const { data, error } = await supabase.rpc('is_site_admin');
    if (error) {
      console.error('is_site_admin RPC failed', error);
      setServerIsAdmin(false);
      return;
    }
    setServerIsAdmin(data === true);
  }, []);

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
    } = supabase.auth.onAuthStateChange((_event, next) => {
      setLoading(true);
      void applySession(next).finally(() => {
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

  const signInWithGoogle = useCallback(async () => {
    if (!supabase) {
      throw new Error('Supabase is not configured');
    }
    const redirectTo = `${window.location.origin}${window.location.pathname}#/admin`;
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo },
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
    const redirectTo = `${window.location.origin}${window.location.pathname}#/admin`;
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
  }, []);

  const value = useMemo(
    () => ({
      session,
      user,
      loading,
      isAdmin,
      signInWithGoogle,
      signInWithEmail,
      signOut,
    }),
    [session, user, loading, isAdmin, signInWithGoogle, signInWithEmail, signOut],
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

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { normalizeSupabaseProjectUrl } from './supabaseHealth';

const urlRaw = (import.meta.env.VITE_SUPABASE_URL ?? '').trim();
const url = normalizeSupabaseProjectUrl(urlRaw);
const anon = (import.meta.env.VITE_SUPABASE_ANON_KEY ?? '').trim();

function initSupabase(): { client: SupabaseClient | null; configured: boolean } {
  if (!url || !anon) {
    return { client: null, configured: false };
  }
  try {
    const u = new URL(url);
    if (u.protocol !== 'https:' || !u.hostname.endsWith('.supabase.co')) {
      console.warn(
        '[hub] VITE_SUPABASE_URL should be https://YOUR_REF.supabase.co — Supabase disabled for this build.',
      );
      return { client: null, configured: false };
    }
    if (anon.length < 80) {
      console.warn('[hub] VITE_SUPABASE_ANON_KEY looks truncated — Supabase disabled.');
      return { client: null, configured: false };
    }
    const client = createClient(url, anon, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
    return { client, configured: true };
  } catch (e) {
    console.warn('[hub] Supabase client failed to initialize (site will run without CMS):', e);
    return { client: null, configured: false };
  }
}

const { client: supabase, configured: supabaseConfigured } = initSupabase();

export { supabase, supabaseConfigured };

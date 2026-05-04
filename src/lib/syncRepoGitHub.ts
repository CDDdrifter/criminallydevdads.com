import { supabase } from './supabase';

export type SyncGamesJsonResult = {
  ok?: boolean;
  games?: number;
  commit_url?: string | null;
  error?: string;
};

/**
 * Commits root `games.json` from published `site_games` via Edge Function `sync-repo-to-github`.
 * Requires function deploy + GitHub secrets — see docs/SYNC_CMS_TO_GITHUB.md
 */
export async function invokeSyncGamesJsonToGitHub(): Promise<SyncGamesJsonResult> {
  if (!supabase) {
    return { error: 'Supabase is not configured' };
  }
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData.session?.access_token;
  if (!token) {
    return { error: 'Sign in first' };
  }

  const { data, error } = await supabase.functions.invoke('sync-repo-to-github', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: {},
  });

  if (error) {
    return { error: error.message };
  }

  const body = data as SyncGamesJsonResult | null;
  if (body && typeof body === 'object' && 'error' in body && body.error) {
    return { error: String(body.error) };
  }

  return body ?? { error: 'Empty response from sync-repo-to-github' };
}

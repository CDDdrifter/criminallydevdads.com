import { supabase } from './supabase';

export type SyncGamesJsonResult = {
  ok?: boolean;
  games?: number;
  scope?: 'games' | 'content' | 'all';
  files?: string[];
  commit_urls?: string[];
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
    body: { scope: 'games' },
  });

  const body = data as SyncGamesJsonResult | null;
  if (body && typeof body === 'object' && typeof body.error === 'string' && body.error) {
    return { error: body.error };
  }

  if (error) {
    const hint =
      /non-2xx|failed to send|edge function/i.test(error.message) ?
        ' Deploy the function and secrets: `supabase functions deploy sync-repo-to-github` and `supabase secrets set GITHUB_TOKEN …` (see docs/SYNC_CMS_TO_GITHUB.md).'
      : '';
    return { error: `${error.message}${hint}` };
  }

  return body ?? { error: 'Empty response from sync-repo-to-github' };
}

/** Sync CMS-managed layout/content snapshots (settings/pages/nav/devlogs) into /cms/*.json on GitHub. */
export async function invokeSyncSiteContentToGitHub(): Promise<SyncGamesJsonResult> {
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
    body: { scope: 'content' },
  });

  const body = data as SyncGamesJsonResult | null;
  if (body && typeof body === 'object' && typeof body.error === 'string' && body.error) {
    return { error: body.error };
  }
  if (error) {
    const hint =
      /non-2xx|failed to send|edge function/i.test(error.message)
        ? ' Deploy/update function: `supabase functions deploy sync-repo-to-github` (see docs/SYNC_CMS_TO_GITHUB.md).'
        : '';
    return { error: `${error.message}${hint}` };
  }
  return body ?? { error: 'Empty response from sync-repo-to-github' };
}

/** Sync both games.json and cms/*.json snapshots in one action. */
export async function invokeSyncAllCmsToGitHub(): Promise<SyncGamesJsonResult> {
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
    body: { scope: 'all' },
  });

  const body = data as SyncGamesJsonResult | null;
  if (body && typeof body === 'object' && typeof body.error === 'string' && body.error) {
    return { error: body.error };
  }
  if (error) {
    const hint =
      /non-2xx|failed to send|edge function/i.test(error.message)
        ? ' Deploy/update function: `supabase functions deploy sync-repo-to-github` (see docs/SYNC_CMS_TO_GITHUB.md).'
        : '';
    return { error: `${error.message}${hint}` };
  }
  return body ?? { error: 'Empty response from sync-repo-to-github' };
}

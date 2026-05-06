import { FunctionsHttpError } from '@supabase/supabase-js';
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

/** Edge Functions return JSON `{ error: "..." }` on failure; supabase-js surfaces that only via FunctionsHttpError.context. */
async function readEdgeFunctionErrorMessage(error: unknown): Promise<string | null> {
  if (!(error instanceof FunctionsHttpError)) {
    return null;
  }
  try {
    const res = error.context;
    const clone = res.clone();
    const ct = (clone.headers.get('Content-Type') ?? '').split(';')[0]?.trim() ?? '';
    if (ct === 'application/json') {
      const j: unknown = await clone.json();
      if (j && typeof j === 'object' && 'error' in j && typeof (j as { error: unknown }).error === 'string') {
        return (j as { error: string }).error;
      }
    } else {
      const text = (await clone.text()).trim();
      if (text) {
        return text;
      }
    }
  } catch {
    // ignore
  }
  return null;
}

function invokeHint(serverMessage: string): string {
  const m = serverMessage.toLowerCase();
  if (m.includes('missing github_token') || m.includes('github_owner') || m.includes('github_repo')) {
    return ' Fix: run `supabase secrets set GITHUB_TOKEN=… GITHUB_OWNER=… GITHUB_REPO=…` (see docs/GIT_SYNC_DO_THIS_FIRST.md).';
  }
  if (m.includes('forbidden') && m.includes('admin')) {
    return ' Fix: your account must be in site_admin_emails / site_admin_domains (schema.sql).';
  }
  if (m.includes('missing authorization')) {
    return ' Fix: sign out and sign in to Admin again so your session JWT is fresh.';
  }
  if (m.includes('github read') || m.includes('github write')) {
    return ' Fix: GitHub token needs Contents: Read/Write on the correct repo, or repo name/owner typo in secrets.';
  }
  return ' If the message is vague: redeploy with `supabase functions deploy sync-repo-to-github` and confirm the function name matches exactly.';
}

async function invokeSyncRepo(scope: 'games' | 'content' | 'all'): Promise<SyncGamesJsonResult> {
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
    body: { scope },
  });

  const body = data as SyncGamesJsonResult | null;
  if (body && typeof body === 'object' && typeof body.error === 'string' && body.error) {
    return { error: `${body.error}${invokeHint(body.error)}` };
  }

  if (!error) {
    return body ?? { error: 'Empty response from sync-repo-to-github' };
  }

  const fromServer = await readEdgeFunctionErrorMessage(error);
  const core = fromServer || error.message;
  const generic =
    /non-2xx|edge function/i.test(error.message) && !fromServer ?
      ' The function returned an error HTTP status — details should appear above after this update. Common fixes: deploy the function (`supabase functions deploy sync-repo-to-github`), set GitHub secrets, stay signed in as admin.'
    : '';

  return { error: `${core}${invokeHint(core)}${generic}` };
}

/**
 * Commits root `games.json` from published `site_games` via Edge Function `sync-repo-to-github`.
 * Requires function deploy + GitHub secrets — see docs/GIT_SYNC_DO_THIS_FIRST.md
 */
export async function invokeSyncGamesJsonToGitHub(): Promise<SyncGamesJsonResult> {
  return invokeSyncRepo('games');
}

/** Sync CMS-managed layout/content snapshots (settings/pages/nav/devlogs) into /cms/*.json on GitHub. */
export async function invokeSyncSiteContentToGitHub(): Promise<SyncGamesJsonResult> {
  return invokeSyncRepo('content');
}

/** Sync both games.json and cms/*.json snapshots in one action. */
export async function invokeSyncAllCmsToGitHub(): Promise<SyncGamesJsonResult> {
  return invokeSyncRepo('all');
}

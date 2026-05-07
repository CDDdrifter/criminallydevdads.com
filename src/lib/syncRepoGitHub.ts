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
 * supabase-js throws FunctionsHttpError with `context` = the raw Response when status is not 2xx.
 * Do not rely on `instanceof` alone (duplicate package copies can break it).
 */
async function readFunctionInvokeFailure(error: unknown): Promise<string | null> {
  const ctx =
    error && typeof error === 'object' && 'context' in error ?
      (error as { context: unknown }).context
    : null;
  if (!(ctx instanceof Response)) {
    return null;
  }
  const res = ctx;
  const status = res.status;
  try {
    const clone = res.clone();
    const ct = (clone.headers.get('Content-Type') ?? '').toLowerCase();
    if (ct.includes('application/json')) {
      const j: unknown = await clone.json();
      if (j && typeof j === 'object') {
        const rec = j as Record<string, unknown>;
        if (typeof rec.error === 'string' && rec.error) {
          return `HTTP ${status}: ${rec.error}`;
        }
        if (typeof rec.message === 'string' && rec.message) {
          return `HTTP ${status}: ${rec.message}`;
        }
      }
    }
    const text = (await clone.text()).trim();
    if (text) {
      return `HTTP ${status}: ${text.slice(0, 2000)}`;
    }
    return `HTTP ${status} (empty response body). Deploy: supabase functions deploy sync-repo-to-github — see docs/GIT_SYNC_DO_THIS_FIRST.md`;
  } catch {
    return `HTTP ${status} (could not read error body)`;
  }
}

function invokeHint(serverMessage: string): string {
  const m = serverMessage.toLowerCase();
  if (m.includes('missing supabase env') || m.includes('supabase_anon_key')) {
    return ' Fix: Supabase Edge must see SUPABASE_URL + SUPABASE_ANON_KEY. Dashboard → Project Settings → Edge Functions → Secrets — add SUPABASE_ANON_KEY = same “anon public” key as in the API page (auto-inject usually fills this; if not, set manually).';
  }
  if (m.includes('missing github_token') || m.includes('github_owner') || m.includes('github_repo')) {
    return ' Fix: run `supabase secrets set GITHUB_TOKEN=… GITHUB_OWNER=… GITHUB_REPO=…` (see docs/GIT_SYNC_DO_THIS_FIRST.md).';
  }
  if (m.includes('forbidden') && m.includes('admin')) {
    return ' Fix: your account must be in site_admin_emails / site_admin_domains (schema.sql).';
  }
  if (m.includes('missing authorization') || m.includes('http 401')) {
    return ' Fix: sign out and sign in to Admin again (fresh JWT). If it persists, confirm sync-repo-to-github is deployed on the same Supabase project as VITE_SUPABASE_URL.';
  }
  if (m.includes('github read') || m.includes('github write')) {
    return ' Fix: GitHub token needs Contents: Read/Write on the correct repo, or repo name/owner typo in secrets.';
  }
  if (m.includes('http 404')) {
    return ' Fix: deploy the function: `supabase functions deploy sync-repo-to-github` (wrong project ref = redeploy after `supabase link`).';
  }
  return ' See docs/GIT_SYNC_DO_THIS_FIRST.md (deploy + secrets + same project as the site).';
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

  const fromResponse = await readFunctionInvokeFailure(error);
  const fallbackMsg = error instanceof Error ? error.message : String(error);
  const core = fromResponse || fallbackMsg;

  return { error: `${core}${invokeHint(core)}` };
}

/**
 * Commits root `games.json` from published `site_games` via Edge Function `sync-repo-to-github`.
 * Requires function deploy + GitHub secrets — see docs/GIT_SYNC_DO_THIS_FIRST.md
 */
export async function invokeSyncGamesJsonToGitHub(): Promise<SyncGamesJsonResult> {
  return invokeSyncRepo('games');
}

/** Sync CMS-managed layout/content snapshots into /cms/*.json on GitHub. */
export async function invokeSyncSiteContentToGitHub(): Promise<SyncGamesJsonResult> {
  return invokeSyncRepo('content');
}

/** Sync both games.json and cms/*.json snapshots in one action. */
export async function invokeSyncAllCmsToGitHub(): Promise<SyncGamesJsonResult> {
  return invokeSyncRepo('all');
}

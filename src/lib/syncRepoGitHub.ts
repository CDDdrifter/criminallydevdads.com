import {
  getGitHubToken,
  githubCmsConfigured,
  syncGamesJsonToGitHub,
  syncSiteContentToGitHub,
  writeCmsFiles,
  type GitHubWriteResult,
} from './githubCms';

export type SyncGamesJsonResult = GitHubWriteResult & {
  games?: number;
  scope?: 'games' | 'content' | 'all';
};

/**
 * Commits root games.json via GitHub Contents API (no Supabase required).
 * Requires a GitHub PAT entered in Admin → System → GitHub sync.
 */
export async function invokeSyncGamesJsonToGitHub(): Promise<SyncGamesJsonResult> {
  if (!githubCmsConfigured()) {
    return { error: 'No GitHub token — enter one in Admin → System → GitHub sync.' };
  }
  const res = await fetch('/games.json', { cache: 'no-store' });
  if (!res.ok) {
    return { error: 'Could not read current games.json' };
  }
  const data = await res.json();
  return syncGamesJsonToGitHub(Array.isArray(data) ? data : []);
}

/** Sync CMS-managed layout/content snapshots into /cms/*.json on GitHub. */
export async function invokeSyncSiteContentToGitHub(): Promise<SyncGamesJsonResult> {
  if (!githubCmsConfigured()) {
    return { error: 'No GitHub token — enter one in Admin → System → GitHub sync.' };
  }
  const files: { path: string; data: unknown }[] = [];
  for (const path of ['cms/site-settings.json', 'cms/site-pages.json', 'cms/site-nav.json', 'cms/site-devlogs.json']) {
    const res = await fetch(`/${path}`, { cache: 'no-store' });
    if (res.ok) {
      files.push({ path, data: await res.json() });
    }
  }
  return syncSiteContentToGitHub(files);
}

/** Sync both games.json and cms/*.json snapshots in one action. */
export async function invokeSyncAllCmsToGitHub(): Promise<SyncGamesJsonResult> {
  if (!githubCmsConfigured()) {
    return { error: 'No GitHub token — enter one in Admin → System → GitHub sync.' };
  }
  const gamesRes = await fetch('/games.json', { cache: 'no-store' });
  const games = gamesRes.ok ? await gamesRes.json() : [];
  const cmsFiles: { path: string; data: unknown }[] = [{ path: 'games.json', data: games }];
  for (const path of ['cms/site-settings.json', 'cms/site-pages.json', 'cms/site-nav.json', 'cms/site-devlogs.json']) {
    const res = await fetch(`/${path}`, { cache: 'no-store' });
    if (res.ok) {
      cmsFiles.push({ path, data: await res.json() });
    }
  }
  return writeCmsFiles(cmsFiles, 'chore(cms): sync all content from admin');
}

export { getGitHubToken, githubCmsConfigured };

/**
 * Write CMS JSON files to GitHub via the Contents API.
 * Admin saves go directly to the repo — no Supabase Edge Functions needed.
 *
 * Requires a GitHub Personal Access Token (classic) with `repo` scope,
 * entered once per browser session in /admin → System → GitHub sync.
 */
const GITHUB_PAT_KEY = 'cdd_github_pat';
const GITHUB_BRANCH_KEY = 'cdd_github_branch';

const REPO_OWNER = import.meta.env.VITE_GITHUB_REPO_OWNER ?? 'CDDdrifter';
const REPO_NAME = import.meta.env.VITE_GITHUB_REPO_NAME ?? 'criminallydevdads.com';

export type GitHubWriteResult = {
  ok?: boolean;
  commit_url?: string | null;
  commit_urls?: string[];
  files?: string[];
  error?: string;
};

export function getGitHubToken(): string {
  return sessionStorage.getItem(GITHUB_PAT_KEY) ?? '';
}

export function setGitHubToken(token: string) {
  const trimmed = token.trim();
  if (trimmed) {
    sessionStorage.setItem(GITHUB_PAT_KEY, trimmed);
  } else {
    sessionStorage.removeItem(GITHUB_PAT_KEY);
  }
}

export function getGitHubBranch(): string {
  return sessionStorage.getItem(GITHUB_BRANCH_KEY) ?? 'main';
}

export function setGitHubBranch(branch: string) {
  sessionStorage.setItem(GITHUB_BRANCH_KEY, branch.trim() || 'main');
}

export function githubCmsConfigured(): boolean {
  return Boolean(getGitHubToken());
}

function utf8ToBase64(text: string): string {
  const bytes = new TextEncoder().encode(text);
  let bin = '';
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i]!);
  }
  return btoa(bin);
}

async function writeJsonFile(
  path: string,
  jsonData: unknown,
  commitMessage: string,
  token: string,
  branch: string,
): Promise<string | null> {
  const json = `${JSON.stringify(jsonData, null, 2)}\n`;
  const content = utf8ToBase64(json);
  const ghHeaders: Record<string, string> = {
    Accept: 'application/vnd.github+json',
    Authorization: `Bearer ${token}`,
    'X-GitHub-Api-Version': '2022-11-28',
  };

  const getUrl = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${encodeURIComponent(path)}?ref=${encodeURIComponent(branch)}`;
  const getRes = await fetch(getUrl, { headers: ghHeaders });

  let sha: string | undefined;
  if (getRes.ok) {
    const meta = (await getRes.json()) as { sha?: string };
    sha = meta.sha;
  } else if (getRes.status !== 404) {
    const t = await getRes.text();
    throw new Error(`GitHub read ${path}: ${getRes.status} ${t}`);
  }

  const putRes = await fetch(
    `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${encodeURIComponent(path)}`,
    {
      method: 'PUT',
      headers: { ...ghHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: commitMessage, content, sha, branch }),
    },
  );

  if (!putRes.ok) {
    const t = await putRes.text();
    throw new Error(`GitHub write ${path}: ${putRes.status} ${t}`);
  }

  const result = (await putRes.json()) as { commit?: { html_url?: string } };
  return result.commit?.html_url ?? null;
}

export async function writeCmsFiles(
  files: { path: string; data: unknown }[],
  commitMessage: string,
): Promise<GitHubWriteResult> {
  const token = getGitHubToken();
  if (!token) {
    return {
      error:
        'No GitHub token. In Admin → System → GitHub sync, paste a Personal Access Token with repo scope.',
    };
  }
  const branch = getGitHubBranch();
  const commitUrls: string[] = [];
  const written: string[] = [];

  for (const { path, data } of files) {
    const url = await writeJsonFile(path, data, commitMessage, token, branch);
    written.push(path);
    if (url) {
      commitUrls.push(url);
    }
  }

  return {
    ok: true,
    files: written,
    commit_urls: commitUrls,
    commit_url: commitUrls[commitUrls.length - 1] ?? null,
  };
}

export async function syncGamesJsonToGitHub(gamesJson: unknown[]): Promise<GitHubWriteResult> {
  return writeCmsFiles([{ path: 'games.json', data: gamesJson }], 'chore(cms): update games.json from admin');
}

export async function syncSiteContentToGitHub(files: { path: string; data: unknown }[]): Promise<GitHubWriteResult> {
  return writeCmsFiles(files, 'chore(cms): update site content from admin');
}

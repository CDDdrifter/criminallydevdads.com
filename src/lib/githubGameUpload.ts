/**
 * Upload game builds to `games/<slug>/` in the GitHub repo (not Firebase).
 * Large binaries use Git LFS per `.gitattributes` (*.pck, *.wasm, …).
 *
 * Requires a GitHub PAT with `repo` scope (Admin → System → GitHub sync).
 */
import { getGitHubBranch, getGitHubToken, githubCmsConfigured } from './githubCms';

const REPO_OWNER = import.meta.env.VITE_GITHUB_REPO_OWNER ?? 'CDDdrifter';
const REPO_NAME = import.meta.env.VITE_GITHUB_REPO_NAME ?? 'criminallydevdads.com';

/** GitHub Contents / blob API hard limit for non-LFS blobs. */
export const GITHUB_MAX_PLAIN_BLOB_BYTES = 100 * 1024 * 1024;

/** Per-file cap for admin uploads (Git LFS handles large binaries). */
export const MAX_REPO_GAME_FILE_BYTES = 5 * 1024 * 1024 * 1024;

const LFS_EXTENSIONS = new Set([
  'pck',
  'wasm',
  'bin',
  'so',
  'dll',
  'dylib',
  'png',
  'jpg',
  'jpeg',
  'wav',
  'mp3',
  'ogg',
  'zip',
]);

function ghHeaders(token: string): Record<string, string> {
  return {
    Accept: 'application/vnd.github+json',
    Authorization: `Bearer ${token}`,
    'X-GitHub-Api-Version': '2022-11-28',
  };
}

function lfsHeaders(token: string): Record<string, string> {
  return {
    Accept: 'application/vnd.git-lfs+json',
    'Content-Type': 'application/vnd.git-lfs+json',
    Authorization: `Bearer ${token}`,
  };
}

function requireGitHub() {
  if (!githubCmsConfigured()) {
    throw new Error(
      'No GitHub token. In Admin → System → GitHub sync, paste a Personal Access Token with repo scope.',
    );
  }
  return { token: getGitHubToken(), branch: getGitHubBranch() };
}

export function repoGamePath(slug: string, relPath: string): string {
  const clean = relPath.replace(/\\/g, '/').replace(/^\//, '');
  return `games/${slug}/${clean}`.replace(/\/+/g, '/');
}

export function publicRepoGameUrl(slug: string, relPath: string): string {
  return repoGamePath(slug, relPath);
}

export function needsGitLfs(filename: string, size: number): boolean {
  const ext = filename.split('.').pop()?.toLowerCase() ?? '';
  if (LFS_EXTENSIONS.has(ext)) {
    return true;
  }
  return size > GITHUB_MAX_PLAIN_BLOB_BYTES;
}

import { sha256 } from '@noble/hashes/sha2.js';

/**
 * Incremental SHA-256 for multi-GB blobs (Git LFS) without loading the whole file into RAM.
 */
async function sha256Hex(blob: Blob): Promise<string> {
  const hasher = sha256.create();
  const chunkSize = 4 * 1024 * 1024;
  for (let offset = 0; offset < blob.size; offset += chunkSize) {
    const chunk = blob.slice(offset, Math.min(offset + chunkSize, blob.size));
    hasher.update(new Uint8Array(await chunk.arrayBuffer()));
  }
  return Array.from(hasher.digest())
    .map((b: number) => b.toString(16).padStart(2, '0'))
    .join('');
}

function lfsPointer(oid: string, size: number): string {
  return `version https://git-lfs.github.com/spec/v1\noid sha256:${oid}\nsize ${size}\n`;
}

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result;
      if (typeof result !== 'string') {
        reject(new Error('Could not read file'));
        return;
      }
      const comma = result.indexOf(',');
      resolve(comma >= 0 ? result.slice(comma + 1) : result);
    };
    reader.onerror = () => reject(reader.error ?? new Error('FileReader failed'));
    reader.readAsDataURL(blob);
  });
}

async function uploadLfsObject(blob: Blob, oid: string, size: number, token: string): Promise<void> {
  const batchUrl = `https://github.com/${REPO_OWNER}/${REPO_NAME}.git/info/lfs/objects/batch`;
  const batchRes = await fetch(batchUrl, {
    method: 'POST',
    headers: lfsHeaders(token),
    body: JSON.stringify({
      operation: 'upload',
      transfers: ['basic'],
      objects: [{ oid, size }],
    }),
  });
  if (!batchRes.ok) {
    const t = await batchRes.text();
    throw new Error(`Git LFS batch failed (${batchRes.status}): ${t.slice(0, 300)}`);
  }
  const batch = (await batchRes.json()) as {
    objects?: Array<{
      oid: string;
      actions?: {
        upload?: { href: string; header?: Record<string, string> };
      };
    }>;
  };
  const obj = batch.objects?.find((o) => o.oid === oid);
  const upload = obj?.actions?.upload;
  if (!upload?.href) {
    return;
  }
  const putHeaders: Record<string, string> = { ...(upload.header ?? {}) };
  if (!putHeaders['Content-Type']) {
    putHeaders['Content-Type'] = 'application/octet-stream';
  }
  const putRes = await fetch(upload.href, { method: 'PUT', headers: putHeaders, body: blob });
  if (!putRes.ok) {
    const t = await putRes.text();
    throw new Error(`Git LFS upload failed (${putRes.status}): ${t.slice(0, 200)}`);
  }
}

async function createGitBlob(content: string, encoding: 'utf-8' | 'base64', token: string): Promise<string> {
  const res = await fetch(`https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/blobs`, {
    method: 'POST',
    headers: { ...ghHeaders(token), 'Content-Type': 'application/json' },
    body: JSON.stringify({ content, encoding }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Git blob create failed (${res.status}): ${t.slice(0, 300)}`);
  }
  const data = (await res.json()) as { sha?: string };
  if (!data.sha) {
    throw new Error('Git blob create returned no sha');
  }
  return data.sha;
}

async function blobShaForUpload(path: string, blob: Blob, token: string): Promise<string> {
  if (blob.size > MAX_REPO_GAME_FILE_BYTES) {
    throw new Error(`${path} exceeds ${MAX_REPO_GAME_FILE_BYTES / (1024 * 1024 * 1024)} GB limit.`);
  }
  if (needsGitLfs(path, blob.size)) {
    const oid = await sha256Hex(blob);
    await uploadLfsObject(blob, oid, blob.size, token);
    return createGitBlob(lfsPointer(oid, blob.size), 'utf-8', token);
  }
  if (blob.size > GITHUB_MAX_PLAIN_BLOB_BYTES) {
    throw new Error(
      `${path} is ${Math.round(blob.size / (1024 * 1024))} MB — add its extension to .gitattributes for Git LFS.`,
    );
  }
  const b64 = await blobToBase64(blob);
  return createGitBlob(b64, 'base64', token);
}

type TreeRow = { path: string; mode: '100644'; type: 'blob'; sha: string | null };

async function getBranchHead(token: string, branch: string): Promise<{ commitSha: string; treeSha: string }> {
  const refRes = await fetch(
    `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/ref/heads/${encodeURIComponent(branch)}`,
    { headers: ghHeaders(token) },
  );
  if (!refRes.ok) {
    const t = await refRes.text();
    throw new Error(`Could not read branch ${branch} (${refRes.status}): ${t.slice(0, 200)}`);
  }
  const ref = (await refRes.json()) as { object?: { sha?: string } };
  const commitSha = ref.object?.sha;
  if (!commitSha) {
    throw new Error(`Branch ${branch} has no commit.`);
  }
  const commitRes = await fetch(
    `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/commits/${commitSha}`,
    { headers: ghHeaders(token) },
  );
  if (!commitRes.ok) {
    throw new Error(`Could not read commit ${commitSha}`);
  }
  const commit = (await commitRes.json()) as { tree?: { sha?: string } };
  const treeSha = commit.tree?.sha;
  if (!treeSha) {
    throw new Error('Commit has no tree.');
  }
  return { commitSha, treeSha };
}

async function listRepoPaths(prefix: string, token: string, branch: string): Promise<string[]> {
  const paths: string[] = [];
  async function walk(dir: string): Promise<void> {
    const url = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${encodeURIComponent(dir)}?ref=${encodeURIComponent(branch)}`;
    const res = await fetch(url, { headers: ghHeaders(token) });
    if (!res.ok) {
      return;
    }
    const items: unknown = await res.json();
    if (!Array.isArray(items)) {
      return;
    }
    for (const item of items) {
      if (!item || typeof item !== 'object') {
        continue;
      }
      const row = item as { type?: string; path?: string };
      if (row.type === 'file' && row.path) {
        paths.push(row.path);
      } else if (row.type === 'dir' && row.path) {
        await walk(row.path);
      }
    }
  }
  await walk(prefix.replace(/\/+$/, ''));
  return paths;
}

async function createTree(baseTree: string, tree: TreeRow[], token: string): Promise<string> {
  const res = await fetch(`https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/trees`, {
    method: 'POST',
    headers: { ...ghHeaders(token), 'Content-Type': 'application/json' },
    body: JSON.stringify({ base_tree: baseTree, tree }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Git tree create failed (${res.status}): ${t.slice(0, 300)}`);
  }
  const data = (await res.json()) as { sha?: string };
  if (!data.sha) {
    throw new Error('Git tree create returned no sha');
  }
  return data.sha;
}

async function createCommit(message: string, treeSha: string, parentSha: string, token: string): Promise<string> {
  const res = await fetch(`https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/commits`, {
    method: 'POST',
    headers: { ...ghHeaders(token), 'Content-Type': 'application/json' },
    body: JSON.stringify({ message, tree: treeSha, parents: [parentSha] }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Git commit failed (${res.status}): ${t.slice(0, 300)}`);
  }
  const data = (await res.json()) as { sha?: string };
  if (!data.sha) {
    throw new Error('Git commit returned no sha');
  }
  return data.sha;
}

async function updateBranchRef(branch: string, commitSha: string, token: string): Promise<void> {
  const res = await fetch(
    `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/refs/heads/${encodeURIComponent(branch)}`,
    {
      method: 'PATCH',
      headers: { ...ghHeaders(token), 'Content-Type': 'application/json' },
      body: JSON.stringify({ sha: commitSha, force: false }),
    },
  );
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Git ref update failed (${res.status}): ${t.slice(0, 300)}`);
  }
}

export type RepoFileUpload = { repoPath: string; blob: Blob };

export type RepoFileSource = { repoPath: string; getBlob: () => Promise<Blob> };

/**
 * Commit many files under `games/<slug>/` in a single git commit.
 * Uses Git LFS automatically for large / LFS-tracked extensions.
 */
export async function uploadGameFilesToRepo(
  slug: string,
  files: RepoFileSource[],
  options?: {
    wipeFolderFirst?: boolean;
    commitMessage?: string;
    onProgress?: (done: number, total: number, currentPath?: string) => void;
  },
): Promise<{ fileCount: number; commitUrl: string | null }> {
  const { token, branch } = requireGitHub();
  if (!files.length) {
    throw new Error('No files to upload.');
  }

  const { commitSha, treeSha } = await getBranchHead(token, branch);
  const treeRows: TreeRow[] = [];

  if (options?.wipeFolderFirst) {
    const prefix = `games/${slug}`;
    const existing = await listRepoPaths(prefix, token, branch);
    for (const path of existing) {
      treeRows.push({ path, mode: '100644', type: 'blob', sha: null });
    }
  }

  const total = files.length;
  let done = 0;
  const sorted = [...files];

  for (const file of sorted) {
    options?.onProgress?.(done, total, file.repoPath);
    const blob = await file.getBlob();
    const sha = await blobShaForUpload(file.repoPath, blob, token);
    treeRows.push({ path: file.repoPath, mode: '100644', type: 'blob', sha });
    done += 1;
    options?.onProgress?.(done, total, file.repoPath);
  }

  const newTreeSha = await createTree(treeSha, treeRows, token);
  const message =
    options?.commitMessage ??
    `chore(games): upload ${slug} (${files.length} file${files.length === 1 ? '' : 's'}) from admin`;
  const newCommitSha = await createCommit(message, newTreeSha, commitSha, token);
  await updateBranchRef(branch, newCommitSha, token);

  return {
    fileCount: files.length,
    commitUrl: `https://github.com/${REPO_OWNER}/${REPO_NAME}/commit/${newCommitSha}`,
  };
}

/** Upload one file to `games/<slug>/…` (cover, download package, etc.). */
export async function uploadSingleGameRepoFile(
  slug: string,
  relPath: string,
  blob: Blob,
  commitMessage?: string,
): Promise<string> {
  const repoPath = repoGamePath(slug, relPath);
  await uploadGameFilesToRepo(
    slug,
    [{ repoPath, getBlob: async () => blob }],
    {
      commitMessage: commitMessage ?? `chore(games): update ${repoPath}`,
    },
  );
  return publicRepoGameUrl(slug, relPath);
}

/**
 * Upload a single site asset via GitHub Contents API (plain base64 — no Git LFS).
 * Best for cover images, clips ≤ 100 MB, and page media hosted under games/media/.
 */
export async function uploadRepoBinaryFile(
  repoPath: string,
  blob: Blob,
  commitMessage?: string,
): Promise<string> {
  const { token, branch } = requireGitHub();
  if (blob.size > GITHUB_MAX_PLAIN_BLOB_BYTES) {
    throw new Error(
      `${repoPath} is ${Math.round(blob.size / (1024 * 1024))} MB — GitHub plain uploads max 100 MB. Use a smaller clip or compress the file.`,
    );
  }
  const cleanPath = repoPath.replace(/^\/+/, '').replace(/\/+/g, '/');
  const content = await blobToBase64(blob);
  const ghHeaders = {
    Accept: 'application/vnd.github+json',
    Authorization: `Bearer ${token}`,
    'X-GitHub-Api-Version': '2022-11-28',
  };

  const getUrl = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${encodeURIComponent(cleanPath)}?ref=${encodeURIComponent(branch)}`;
  const getRes = await fetch(getUrl, { headers: ghHeaders });
  let sha: string | undefined;
  if (getRes.ok) {
    const meta = (await getRes.json()) as { sha?: string };
    sha = meta.sha;
  } else if (getRes.status !== 404) {
    const t = await getRes.text();
    throw new Error(`GitHub read ${cleanPath}: ${getRes.status} ${t.slice(0, 300)}`);
  }

  const putRes = await fetch(
    `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${encodeURIComponent(cleanPath)}`,
    {
      method: 'PUT',
      headers: { ...ghHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: commitMessage ?? `chore(media): update ${cleanPath}`,
        content,
        sha,
        branch,
      }),
    },
  );
  if (!putRes.ok) {
    const t = await putRes.text();
    throw new Error(`GitHub upload ${cleanPath}: ${putRes.status} ${t.slice(0, 400)}`);
  }
  return cleanPath;
}

/** Remove every file under `games/<slug>/`. */
export async function deleteRepoGameFolder(slug: string): Promise<number> {
  const { token, branch } = requireGitHub();
  const prefix = `games/${slug}`;
  const existing = await listRepoPaths(prefix, token, branch);
  if (existing.length === 0) {
    return 0;
  }
  const { commitSha, treeSha } = await getBranchHead(token, branch);
  const treeRows: TreeRow[] = existing.map((path) => ({
    path,
    mode: '100644',
    type: 'blob',
    sha: null,
  }));
  const newTreeSha = await createTree(treeSha, treeRows, token);
  const newCommitSha = await createCommit(
    `chore(games): remove ${slug} build`,
    newTreeSha,
    commitSha,
    token,
  );
  await updateBranchRef(branch, newCommitSha, token);
  return existing.length;
}

export function githubGameUploadReady(): boolean {
  return githubCmsConfigured();
}

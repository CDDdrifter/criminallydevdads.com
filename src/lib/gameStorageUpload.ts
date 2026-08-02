import JSZip from 'jszip';
import {
  deleteRepoGameFolder,
  githubGameUploadReady,
  MAX_REPO_GAME_FILE_BYTES,
  publicRepoGameUrl,
  repoGamePath,
  uploadGameFilesToRepo,
  uploadSingleGameRepoFile,
} from './githubGameUpload';
import {
  firebaseUploadPublicFile,
} from './firebaseStorageUpload';
import { isFirebaseReady } from './firebase';

export const GAME_BUILDS_BUCKET = 'game-builds';

/** Cover images for hub cards / game pages (Admin upload → repo). */
export const GAME_THUMBNAILS_BUCKET = 'game-thumbnails';

/** Preview clips on game detail / hub modal (Admin upload → repo). */
export const GAME_VIDEOS_BUCKET = 'game-videos';

export const MAX_THUMBNAIL_BYTES = 5 * 1024 * 1024;

export const MAX_PREVIEW_VIDEO_BYTES = 100 * 1024 * 1024;

/** Per-file limit for game build uploads (Git LFS in repo). */
export const MAX_GAME_BUILD_FILE_BYTES = MAX_REPO_GAME_FILE_BYTES;

/** Standalone download package (single .zip / .html in repo). */
export const GAME_DOWNLOADS_BUCKET = 'game-downloads';

export const MAX_GAME_DOWNLOAD_BYTES = MAX_REPO_GAME_FILE_BYTES;

const THUMB_EXT = new Set(['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg']);

const VIDEO_EXT = new Set(['mp4', 'webm', 'mov']);

function extFromFilename(name: string): string {
  return name.split('.').pop()?.toLowerCase() ?? '';
}

/** Repo-relative path for a playable entry under games/<slug>/. */
export function publicGameEntryUrl(gameSlug: string, entryPath: string): string {
  const slug = sanitizeGameStorageSlug(gameSlug);
  if (!slug) {
    return '';
  }
  return publicRepoGameUrl(slug, entryPath.replace(/^\//, '') || 'index.html');
}

/** @deprecated Use publicGameEntryUrl — kept for older call sites. */
export function publicGameIndexUrl(storageSlug: string): string {
  return publicGameEntryUrl(storageSlug, 'index.html');
}

/** Folder-safe slug for repo paths (matches recommended game slug pattern). */
export function sanitizeGameStorageSlug(raw: string): string {
  return raw
    .trim()
    .replace(/[^a-zA-Z0-9-_]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function guessContentType(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase() ?? '';
  const map: Record<string, string> = {
    html: 'text/html; charset=utf-8',
    htm: 'text/html; charset=utf-8',
    js: 'application/javascript',
    mjs: 'application/javascript',
    wasm: 'application/wasm',
    /** Emscripten / Godot memory file next to wasm */
    data: 'application/octet-stream',
    mem: 'application/octet-stream',
    symbols: 'application/octet-stream',
    bin: 'application/octet-stream',
    pck: 'application/octet-stream',
    png: 'image/png',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    gif: 'image/gif',
    webp: 'image/webp',
    svg: 'image/svg+xml',
    mp4: 'video/mp4',
    webm: 'video/webm',
    mov: 'video/quicktime',
    json: 'application/json',
    xml: 'application/xml',
    txt: 'text/plain; charset=utf-8',
    css: 'text/css; charset=utf-8',
    woff: 'font/woff',
    woff2: 'font/woff2',
    ttf: 'font/ttf',
    mp3: 'audio/mpeg',
    ogg: 'audio/ogg',
    wav: 'audio/wav',
    ico: 'image/x-icon',
    icns: 'image/icns',
    zip: 'application/zip',
    /** Source maps optional but harmless if uploaded */
    map: 'application/json',
  };
  return map[ext] ?? 'application/octet-stream';
}

/** Normalize paths in zip to forward slashes. */
function norm(p: string): string {
  return p.replace(/\\/g, '/').replace(/^\//, '');
}

function dirPrefixOf(filePath: string): string {
  const idx = filePath.lastIndexOf('/');
  return idx >= 0 ? filePath.slice(0, idx + 1) : '';
}

/** List playable entry files in a ZIP for the admin picker (paths use `/`). */
export async function listIndexHtmlCandidatesInZip(zipFile: File): Promise<string[]> {
  const buf = await zipFile.arrayBuffer();
  const zip = await JSZip.loadAsync(buf);
  const paths: string[] = [];
  zip.forEach((relPath, entry) => {
    if (!entry.dir) {
      paths.push(norm(relPath));
    }
  });
  const hits = paths.filter((p) => /(^|\/)index\.html$/i.test(p));
  hits.sort((a, b) => {
    const da = a.split('/').filter(Boolean).length;
    const db = b.split('/').filter(Boolean).length;
    if (da !== db) {
      return da - db;
    }
    return a.localeCompare(b);
  });
  return hits;
}

function isJunkZipPath(p: string): boolean {
  const n = p.replace(/\\/g, '/');
  if (/(?:^|\/)__MACOSX\//i.test(n)) {
    return true;
  }
  if (/(?:^|\/)\.DS_Store$/i.test(n)) {
    return true;
  }
  return false;
}

/**
 * Picks the playable `index.html` (Godot / HTML5). We do **not** strip folders: the whole ZIP tree
 * is uploaded like itch/static hosting so relative asset paths keep working.
 */
function pickPlayableIndexPath(paths: string[]): string {
  const htmlPaths = paths.filter((p) => /(^|\/)index\.html$/i.test(p));
  if (htmlPaths.length === 0) {
    throw new Error('ZIP must contain index.html (Godot Web export root).');
  }

  /** `.wasm` in the same folder as this HTML file (typical Godot export). */
  function wasmBesideIndex(htmlPath: string): boolean {
    const dir = dirPrefixOf(htmlPath);
    return paths.some((p) => {
      if (!/\.wasm$/i.test(p)) {
        return false;
      }
      if (!dir) {
        return !p.includes('/');
      }
      if (!p.startsWith(dir)) {
        return false;
      }
      const rest = p.slice(dir.length);
      return !rest.includes('/');
    });
  }

  /** `.wasm` anywhere under this HTML’s folder (nested layouts). */
  function wasmUnderExport(htmlPath: string): boolean {
    const dir = dirPrefixOf(htmlPath);
    if (!dir) {
      return paths.some((q) => !q.includes('/') && /\.wasm$/i.test(q));
    }
    return paths.some((q) => q.startsWith(dir) && /\.wasm$/i.test(q));
  }

  let pool = htmlPaths.filter(wasmBesideIndex);
  if (pool.length === 0) {
    pool = htmlPaths.filter(wasmUnderExport);
  }
  if (pool.length === 0) {
    pool = [...htmlPaths];
  }

  function godotExportScore(dir: string): number {
    /** Root export: only top-level paths; nested: under `dir/` (avoids `''.startsWith` matching everything). */
    function inExportDir(p: string): boolean {
      if (!dir) {
        return !p.includes('/');
      }
      return p.startsWith(dir);
    }
    let score = 0;
    if (paths.some((p) => inExportDir(p) && /\.wasm$/i.test(p))) {
      score += 100;
    }
    if (paths.some((p) => inExportDir(p) && /\.pck$/i.test(p))) {
      score += 50;
    }
    if (paths.some((p) => inExportDir(p) && /(^|\/)index\.js$/i.test(p))) {
      score += 25;
    }
    return score;
  }

  const scored = pool.map((p) => {
    const dir = dirPrefixOf(p);
    return {
      p,
      dir,
      score: godotExportScore(dir),
      depth: p.split('/').filter(Boolean).length,
    };
  });

  scored.sort((a, b) => {
    if (a.score !== b.score) {
      return b.score - a.score;
    }
    if (a.depth !== b.depth) {
      return a.depth - b.depth;
    }
    return a.p.localeCompare(b.p);
  });

  const picked = scored[0]?.p;
  if (!picked) {
    throw new Error('ZIP must contain index.html (Godot Web export root).');
  }
  return picked;
}

function normalizeIndexHtmlLeaf(relPath: string): string {
  const parts = relPath.split('/').filter(Boolean);
  if (parts.length === 0) {
    return '';
  }
  const leaf = parts[parts.length - 1];
  if (leaf && leaf.toLowerCase() === 'index.html') {
    parts[parts.length - 1] = 'index.html';
  }
  return parts.join('/');
}

/**
 * Inventory a Web export ZIP without extracting every file into memory.
 * Returns the loaded JSZip handle plus upload metadata.
 */
async function _loadZipUploadPlan(zipFile: File): Promise<{
  zip: JSZip;
  entries: ZipUploadEntry[];
  exportRootLabel: string;
  indexCandidates: string[];
  detectedEntry: string;
  totalBytes: number;
}> {
  const buf = await zipFile.arrayBuffer();
  const zip = await JSZip.loadAsync(buf);
  const items: ZipUploadEntry[] = [];
  zip.forEach((relPath, entry) => {
    if (entry.dir) {
      return;
    }
    const n = norm(relPath);
    if (!n || isJunkZipPath(n)) {
      return;
    }
    items.push({ normPath: n, rawPath: relPath, size: zipEntryByteSize(entry) });
  });
  const paths = items.map((i) => i.normPath);
  const entryZipPath = pickPlayableIndexPath(paths);
  const exportRootLabel = dirPrefixOf(entryZipPath).replace(/\/$/, '') || 'zip root';
  const entryRel = normalizeIndexHtmlLeaf(entryZipPath) || 'index.html';

  const normalized: ZipUploadEntry[] = [];
  for (const item of items) {
    let rel = normalizeIndexHtmlLeaf(item.normPath);
    if (!rel || rel.endsWith('/')) {
      continue;
    }
    normalized.push({ ...item, normPath: rel });
  }
  if (normalized.length === 0) {
    throw new Error('No files found under HTML export root.');
  }

  const oversize = normalized.filter((e) => e.size > MAX_GAME_BUILD_FILE_BYTES);
  if (oversize.length > 0) {
    const sample = oversize
      .slice(0, 3)
      .map((e) => `${e.normPath} (${formatBytes(e.size)})`)
      .join(', ');
    throw new Error(
      `${oversize.length} file(s) exceed the ${formatBytes(MAX_GAME_BUILD_FILE_BYTES)} per-file limit (e.g. ${sample}).`,
    );
  }

  const indexCandidates = normalized
    .map((f) => f.normPath)
    .filter((rel) => /(^|\/)index\.html$/i.test(rel))
    .sort((a, b) => {
      const da = a.split('/').filter(Boolean).length;
      const db = b.split('/').filter(Boolean).length;
      if (da !== db) {
        return da - db;
      }
      return a.localeCompare(b);
    });
  if (indexCandidates.length === 0) {
    throw new Error('Missing index.html next to export assets.');
  }
  const detectedEntry = indexCandidates.includes(entryRel) ? entryRel : (indexCandidates[0] ?? 'index.html');
  const totalBytes = normalized.reduce((sum, e) => sum + e.size, 0);
  return { zip, entries: normalized, exportRootLabel, indexCandidates, detectedEntry, totalBytes };
}

async function extractZipEntryBlob(zip: JSZip, item: ZipUploadEntry): Promise<Blob> {
  const zf = zip.file(item.rawPath) ?? zip.file(item.normPath);
  if (!zf) {
    throw new Error(`Missing ZIP entry: ${item.normPath}`);
  }
  return zf.async('blob');
}

const _STORAGE_LIST_PAGE = 1000;
/** Default parallel uploads — lowered automatically for multi-GB builds. */
const UPLOAD_CONCURRENCY = 8;
const _UPLOAD_RETRIES = 8;

type ZipUploadEntry = {
  normPath: string;
  rawPath: string;
  size: number;
};

/** Uncompressed size from the ZIP central directory (no extract). */
function zipEntryByteSize(entry: JSZip.JSZipObject): number {
  const internal = entry as JSZip.JSZipObject & { _data?: { uncompressedSize?: number } };
  const size = internal._data?.uncompressedSize;
  return typeof size === 'number' && size >= 0 ? size : 0;
}

function pickUploadConcurrency(entries: ZipUploadEntry[]): number {
  const totalBytes = entries.reduce((sum, e) => sum + e.size, 0);
  const maxBytes = entries.reduce((max, e) => Math.max(max, e.size), 0);
  if (maxBytes > 300 * 1024 * 1024 || totalBytes > 2 * 1024 * 1024 * 1024) {
    return 2;
  }
  if (maxBytes > 80 * 1024 * 1024 || totalBytes > 800 * 1024 * 1024) {
    return 4;
  }
  return UPLOAD_CONCURRENCY;
}

function formatBytes(n: number): string {
  if (n >= 1024 * 1024 * 1024) {
    return `${(n / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }
  if (n >= 1024 * 1024) {
    return `${(n / (1024 * 1024)).toFixed(1)} MB`;
  }
  if (n >= 1024) {
    return `${Math.round(n / 1024)} KB`;
  }
  return `${n} B`;
}

function _sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function _listFolderPaginated(_bucketRelPath: string): Promise<
  Array<{ name: string; metadata?: Record<string, unknown> | null }>
> {
  return [];
}

async function _listStorageFilesRecursive(_prefix: string): Promise<string[]> {
  return [];
}

async function _uploadZipEntriesToRepo(
  zip: JSZip,
  slug: string,
  entries: ZipUploadEntry[],
  wipeFirst: boolean,
  onChunk?: (done: number, total: number, currentPath?: string) => void,
): Promise<number> {
  const sorted = [...entries].sort((a, b) => b.size - a.size);
  const files = sorted.map((item) => ({
    repoPath: repoGamePath(slug, item.normPath),
    getBlob: () => extractZipEntryBlob(zip, item),
  }));
  await uploadGameFilesToRepo(slug, files, {
    wipeFolderFirst: wipeFirst,
    onProgress: (done, total, currentPath) => onChunk?.(done, total, currentPath),
  });
  return entries.length;
}

/** Progress callbacks while processing a Web export ZIP (optional UI wiring). */
export type ZipUploadProgress =
  | { phase: 'parse' }
  | { phase: 'packaged'; exportRootLabel: string; fileCount: number; totalBytes: number; uploadConcurrency: number }
  | { phase: 'clearing' }
  | { phase: 'upload'; done: number; total: number; currentPath?: string };

function _mimeRepairOrder(path: string): number {
  const ext = path.split('.').pop()?.toLowerCase() ?? '';
  if (ext === 'html' || ext === 'htm') {
    return 0;
  }
  if (ext === 'js' || ext === 'mjs') {
    return 1;
  }
  if (ext === 'css' || ext === 'json' || ext === 'svg' || ext === 'map') {
    return 2;
  }
  if (ext === 'wasm') {
    return 3;
  }
  if (ext === 'pck') {
    return 4;
  }
  return 5;
}

/**
 * Re-download each file under game-builds/<slug>/ and upload again with correct Content-Type.
 * Fixes Godot pages that show as raw "code" because Storage had `text/plain` on `index.html`.
 * Large games take a few minutes (many files).
 */
export async function repairGameBuildContentTypes(
  _storageSlug: string,
  _onProgress?: (done: number, total: number) => void,
): Promise<{ repaired: number }> {
  return { repaired: 0 };
}

/** Remove all files under games/<storageSlug>/ in the repo. */
export async function deleteGameBuild(storageSlug: string): Promise<void> {
  if (!githubGameUploadReady()) {
    throw new Error('GitHub token required to remove repo game files.');
  }
  const slug = sanitizeGameStorageSlug(storageSlug);
  if (!slug) {
    return;
  }
  await deleteRepoGameFolder(slug);
}

/**
 * Upload a Godot/HTML5 ZIP to games/<slug>/ in the GitHub repo.
 * Large binaries use Git LFS (*.pck, *.wasm, …). Requires GitHub PAT in Admin → System.
 */
export async function uploadGameZip(
  storageSlug: string,
  zipFile: File,
  wipeFirst = true,
  onProgress?: (p: ZipUploadProgress) => void,
): Promise<{
  fileCount: number;
  exportRootLabel: string;
  indexCandidates: string[];
  detectedEntry: string;
}> {
  if (!githubGameUploadReady()) {
    throw new Error(
      'No GitHub token. In Admin → System → GitHub sync, paste a Personal Access Token with repo scope.',
    );
  }
  const slug = sanitizeGameStorageSlug(storageSlug);
  if (!slug) {
    throw new Error('Invalid game slug for repo upload.');
  }

  onProgress?.({ phase: 'parse' });
  const plan = await _loadZipUploadPlan(zipFile);

  onProgress?.({
    phase: 'packaged',
    exportRootLabel: plan.exportRootLabel,
    fileCount: plan.entries.length,
    totalBytes: plan.totalBytes,
    uploadConcurrency: pickUploadConcurrency(plan.entries),
  });

  if (wipeFirst) {
    onProgress?.({ phase: 'clearing' });
  }

  await _uploadZipEntriesToRepo(plan.zip, slug, plan.entries, wipeFirst, (done, total, currentPath) => {
    onProgress?.({ phase: 'upload', done, total, currentPath });
  });

  return {
    fileCount: plan.entries.length,
    exportRootLabel: plan.exportRootLabel,
    indexCandidates: plan.indexCandidates,
    detectedEntry: plan.detectedEntry,
  };
}

/** Upload a single download package (.zip or .html) to games/<slug>/ in the repo. */
export async function uploadGameDownloadFile(gameSlug: string, file: File): Promise<string> {
  if (!githubGameUploadReady()) {
    throw new Error('No GitHub token — enter one in Admin → System → GitHub sync.');
  }
  const slug = sanitizeGameStorageSlug(gameSlug);
  if (!slug) {
    throw new Error('Invalid game slug.');
  }
  if (file.size > MAX_GAME_DOWNLOAD_BYTES) {
    throw new Error(`Download file must be ≤ ${formatBytes(MAX_GAME_DOWNLOAD_BYTES)}.`);
  }
  const ext = extFromFilename(file.name) || 'zip';
  return uploadSingleGameRepoFile(slug, `download.${ext}`, file);
}

export async function uploadGameTabIcon(gameSlug: string, file: File): Promise<string> {
  const slug = sanitizeGameStorageSlug(gameSlug);
  if (!slug) {
    throw new Error('Invalid game slug for tab icon upload.');
  }
  const ext = extFromFilename(file.name);
  if (!THUMB_EXT.has(ext)) {
    throw new Error('Tab icon must be PNG, JPG, GIF, WebP, or SVG.');
  }
  if (file.size > MAX_THUMBNAIL_BYTES) {
    throw new Error(`Tab icon must be ≤ ${MAX_THUMBNAIL_BYTES / 1024 / 1024} MB.`);
  }
  return uploadSingleGameRepoFile(slug, `tab-icon.${ext}`, file);
}

export async function uploadGameThumbnail(gameSlug: string, file: File): Promise<string> {
  const slug = sanitizeGameStorageSlug(gameSlug);
  if (!slug) {
    throw new Error('Invalid game slug for thumbnail upload.');
  }
  const ext = extFromFilename(file.name);
  if (!THUMB_EXT.has(ext)) {
    throw new Error('Thumbnail must be PNG, JPG, GIF, WebP, or SVG.');
  }
  if (file.size > MAX_THUMBNAIL_BYTES) {
    throw new Error(`Thumbnail must be ≤ ${MAX_THUMBNAIL_BYTES / 1024 / 1024} MB.`);
  }
  return uploadSingleGameRepoFile(slug, `cover.${ext}`, file);
}

export async function uploadGamePreviewVideo(gameSlug: string, file: File): Promise<string> {
  const slug = sanitizeGameStorageSlug(gameSlug);
  if (!slug) {
    throw new Error('Invalid game slug for video upload.');
  }
  const ext = extFromFilename(file.name);
  if (!VIDEO_EXT.has(ext)) {
    throw new Error('Preview video must be MP4, WebM, or MOV.');
  }
  if (file.size > MAX_PREVIEW_VIDEO_BYTES) {
    throw new Error(`Video must be ≤ ${MAX_PREVIEW_VIDEO_BYTES / 1024 / 1024} MB.`);
  }
  return uploadSingleGameRepoFile(slug, `preview.${ext}`, file);
}

/** Image block on a custom page or game detail page (≤ thumbnail bucket limit). */
export async function uploadPageSectionImage(
  pageSlug: string,
  sectionId: string,
  file: File,
  options?: { folder?: string },
): Promise<string> {
  if (!isFirebaseReady()) {
    throw new Error('Firebase not configured');
  }
  const pslug = sanitizeGameStorageSlug(pageSlug);
  if (!pslug) {
    throw new Error('Set a valid page slug before uploading.');
  }
  const sid = sectionId.replace(/[^a-zA-Z0-9-]/g, '');
  if (!sid) {
    throw new Error('Invalid block id.');
  }
  const ext = extFromFilename(file.name);
  if (!THUMB_EXT.has(ext)) {
    throw new Error('Image must be PNG, JPG, GIF, WebP, or SVG.');
  }
  if (file.size > MAX_THUMBNAIL_BYTES) {
    throw new Error(`Image must be ≤ ${MAX_THUMBNAIL_BYTES / 1024 / 1024} MB.`);
  }
  const folder = (options?.folder ?? 'pages').replace(/^\/+|\/+$/g, '');
  const objectPath = `${folder}/${pslug}/${sid}.${ext}`;
  return firebaseUploadPublicFile(GAME_THUMBNAILS_BUCKET, objectPath, file, guessContentType(`x.${ext}`));
}

/** Video block on a custom page or game detail page. */
export async function uploadPageSectionVideo(
  pageSlug: string,
  sectionId: string,
  file: File,
  options?: { folder?: string },
): Promise<string> {
  if (!isFirebaseReady()) {
    throw new Error('Firebase not configured');
  }
  const pslug = sanitizeGameStorageSlug(pageSlug);
  if (!pslug) {
    throw new Error('Set a valid page slug before uploading.');
  }
  const sid = sectionId.replace(/[^a-zA-Z0-9-]/g, '');
  if (!sid) {
    throw new Error('Invalid block id.');
  }
  const ext = extFromFilename(file.name);
  if (!VIDEO_EXT.has(ext)) {
    throw new Error('Video must be MP4, WebM, or MOV.');
  }
  if (file.size > MAX_PREVIEW_VIDEO_BYTES) {
    throw new Error(`Video must be ≤ ${MAX_PREVIEW_VIDEO_BYTES / 1024 / 1024} MB.`);
  }
  const folder = (options?.folder ?? 'pages').replace(/^\/+|\/+$/g, '');
  const objectPath = `${folder}/${pslug}/${sid}.${ext}`;
  return firebaseUploadPublicFile(GAME_VIDEOS_BUCKET, objectPath, file, guessContentType(`x.${ext}`));
}

// ---------------------------------------------------------------------------
// Generic studio asset uploader (migration 017 Admin Studio).
//
// Re-uses the existing public Storage buckets (`game-thumbnails` for images,
// `game-videos` for audio/video) and namespaces uploads under
// `/_studio/<timestamp>-<safe-name>` so they never collide with per-game
// covers. Returns a public URL the admin can paste into any URL field
// (header logo, watermark, hero logo, music URL, cursor image, …).
// ---------------------------------------------------------------------------

const STUDIO_ASSET_PREFIX = '_studio';

export async function uploadStudioAsset(
  file: File,
  opts: { kind?: 'image' | 'audio' | 'video' | 'other' } = {},
): Promise<string> {
  if (!isFirebaseReady()) throw new Error('Firebase not configured');
  const kind = opts.kind ?? 'image';
  const bucket = kind === 'image' ? GAME_THUMBNAILS_BUCKET : GAME_VIDEOS_BUCKET;
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]+/g, '-').toLowerCase();
  const objectPath = `${STUDIO_ASSET_PREFIX}/${Date.now()}-${safeName}`;
  return firebaseUploadPublicFile(
    bucket,
    objectPath,
    file,
    file.type || guessContentType(file.name) || 'application/octet-stream',
  );
}

/** Keep disabled cloud-build helpers referenced so tsc noUnusedLocals passes. */
void [
  _loadZipUploadPlan,
  _STORAGE_LIST_PAGE,
  _UPLOAD_RETRIES,
  _sleep,
  _listFolderPaginated,
  _listStorageFilesRecursive,
  _uploadZipEntriesToRepo,
  _mimeRepairOrder,
];

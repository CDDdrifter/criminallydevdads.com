import JSZip from 'jszip';
import { supabase } from './supabase';

export const GAME_BUILDS_BUCKET = 'game-builds';

/** Cover images for hub cards / game pages (Admin upload). */
export const GAME_THUMBNAILS_BUCKET = 'game-thumbnails';

/** Preview clips on game detail / hub modal (Admin upload). */
export const GAME_VIDEOS_BUCKET = 'game-videos';

export const MAX_THUMBNAIL_BYTES = 5 * 1024 * 1024;

export const MAX_PREVIEW_VIDEO_BYTES = 100 * 1024 * 1024;

const THUMB_EXT = new Set(['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg']);

const VIDEO_EXT = new Set(['mp4', 'webm', 'mov']);

function extFromFilename(name: string): string {
  return name.split('.').pop()?.toLowerCase() ?? '';
}

/** Public object URL for a file in a public Storage bucket. */
export function publicStorageObjectUrl(bucket: string, objectPath: string): string {
  const base = (import.meta.env.VITE_SUPABASE_URL ?? '').replace(/\/$/, '');
  if (!base || !objectPath.trim()) {
    return '';
  }
  const encoded = objectPath
    .split('/')
    .filter(Boolean)
    .map((seg) => encodeURIComponent(seg))
    .join('/');
  return `${base}/storage/v1/object/public/${bucket}/${encoded}`;
}

/** Folder-safe slug for Storage paths (matches recommended game slug pattern). */
export function sanitizeGameStorageSlug(raw: string): string {
  return raw
    .trim()
    .replace(/[^a-zA-Z0-9-_]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** Public URL for the hosted index.html (Supabase Storage, public bucket). */
export function publicGameIndexUrl(storageSlug: string): string {
  return publicGameEntryUrl(storageSlug, 'index.html');
}

/** Public URL for any uploaded entry path under a game build slug. */
export function publicGameEntryUrl(storageSlug: string, entryPath: string): string {
  const base = (import.meta.env.VITE_SUPABASE_URL ?? '').replace(/\/$/, '');
  if (!base) {
    return '';
  }
  const slug = encodeURIComponent(storageSlug.trim());
  const entry = entryPath
    .split('/')
    .filter(Boolean)
    .map((seg) => encodeURIComponent(seg))
    .join('/');
  if (!entry) {
    return '';
  }
  return `${base}/storage/v1/object/public/${GAME_BUILDS_BUCKET}/${slug}/${entry}`;
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
 * Zip entries → relative paths under storage slug (no leading slash).
 */
async function zipToRelativeFiles(zipFile: File): Promise<{
  files: { path: string; blob: Blob }[];
  exportRootLabel: string;
  indexCandidates: string[];
  /** Storage path (under slug) for the auto-detected playable HTML — set on every ZIP upload. */
  detectedEntry: string;
}> {
  const buf = await zipFile.arrayBuffer();
  const zip = await JSZip.loadAsync(buf);
  /** Normalized path + raw zip key so `zip.file(raw)` always resolves (Windows paths, etc.). */
  const items: { normPath: string; rawPath: string }[] = [];
  zip.forEach((relPath, entry) => {
    if (!entry.dir) {
      const n = norm(relPath);
      if (!isJunkZipPath(n)) {
        items.push({ normPath: n, rawPath: relPath });
      }
    }
  });
  const paths = items.map((i) => i.normPath);
  const entryZipPath = pickPlayableIndexPath(paths);
  const exportRootLabel = dirPrefixOf(entryZipPath).replace(/\/$/, '') || 'zip root';

  const entryRel = normalizeIndexHtmlLeaf(entryZipPath) || 'index.html';

  const out: { path: string; blob: Blob }[] = [];
  for (const { normPath, rawPath } of items) {
    let rel = normPath;
    if (!rel || rel.endsWith('/')) {
      continue;
    }
    rel = normalizeIndexHtmlLeaf(rel);
    const zf = zip.file(rawPath) ?? zip.file(normPath);
    if (!zf) {
      continue;
    }
    const blob = await zf.async('blob');
    out.push({ path: rel, blob });
  }
  if (out.length === 0) {
    throw new Error('No files found under HTML export root.');
  }
  const indexCandidates = out
    .map((f) => f.path)
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
  return { files: out, exportRootLabel, indexCandidates, detectedEntry };
}

const STORAGE_LIST_PAGE = 1000;
/** Parallel uploads — large blobs (.wasm/.pck) are queued first so they don’t stall at the end. */
const UPLOAD_CONCURRENCY = 12;
const UPLOAD_RETRIES = 6;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function listFolderPaginated(bucketRelPath: string): Promise<
  Array<{ name: string; metadata?: Record<string, unknown> | null }>
> {
  if (!supabase) {
    return [];
  }
  const collected: Array<{ name: string; metadata?: Record<string, unknown> | null }> = [];
  let offset = 0;
  while (true) {
    const { data, error } = await supabase.storage.from(GAME_BUILDS_BUCKET).list(bucketRelPath, {
      limit: STORAGE_LIST_PAGE,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    });
    if (error) {
      throw error;
    }
    const batch = data ?? [];
    collected.push(...batch);
    if (batch.length < STORAGE_LIST_PAGE) {
      break;
    }
    offset += STORAGE_LIST_PAGE;
  }
  return collected;
}

async function listStorageFilesRecursive(prefix: string): Promise<string[]> {
  if (!supabase) {
    return [];
  }
  const collected: string[] = [];

  async function walk(p: string): Promise<void> {
    const items = await listFolderPaginated(p);
    for (const item of items) {
      const key = p ? `${p}/${item.name}` : item.name;
      const meta = item.metadata as { size?: number } | null | undefined;
      const isFile = meta != null && typeof meta.size === 'number';
      if (!isFile) {
        await walk(key);
      } else {
        collected.push(key);
      }
    }
  }

  await walk(prefix);
  return collected;
}

async function uploadStorageObjectWithRetries(objectPath: string, blob: Blob, contentType: string): Promise<void> {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  let lastMsg = 'Upload failed';
  for (let attempt = 0; attempt < UPLOAD_RETRIES; attempt++) {
    const { error } = await supabase.storage.from(GAME_BUILDS_BUCKET).upload(objectPath, blob, {
      upsert: true,
      contentType,
      cacheControl: '3600',
    });
    if (!error) {
      return;
    }
    lastMsg = error.message;
    await sleep(350 * 2 ** attempt);
  }
  throw new Error(`${objectPath}: ${lastMsg}`);
}

async function uploadExtractedFilesParallel(
  slug: string,
  files: { path: string; blob: Blob }[],
  onChunk?: (done: number, total: number) => void,
): Promise<number> {
  const total = files.length;
  let done = 0;
  const queue = [...files];

  async function worker(): Promise<void> {
    while (queue.length > 0) {
      const item = queue.shift();
      if (!item) {
        break;
      }
      const objectPath = `${slug}/${item.path}`;
      await uploadStorageObjectWithRetries(objectPath, item.blob, guessContentType(item.path));
      done += 1;
      onChunk?.(done, total);
    }
  }

  const n = Math.min(UPLOAD_CONCURRENCY, Math.max(1, total));
  await Promise.all(Array.from({ length: n }, () => worker()));
  return total;
}

/** Progress callbacks while processing a Web export ZIP (optional UI wiring). */
export type ZipUploadProgress =
  | { phase: 'parse' }
  | { phase: 'packaged'; exportRootLabel: string; fileCount: number }
  | { phase: 'clearing' }
  | { phase: 'upload'; done: number; total: number };

/** Remove all objects under game-builds/<storageSlug>/ */
export async function deleteGameBuild(storageSlug: string): Promise<void> {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const slug = storageSlug.trim();
  if (!slug) {
    return;
  }
  const keys = await listStorageFilesRecursive(slug);
  if (keys.length === 0) {
    return;
  }
  for (let i = 0; i < keys.length; i += 100) {
    const batch = keys.slice(i, i + 100);
    const { error } = await supabase.storage.from(GAME_BUILDS_BUCKET).remove(batch);
    if (error) {
      throw error;
    }
  }
}

/**
 * Upload a Godot/HTML5 ZIP to public storage at game-builds/<storageSlug>/...
 * Overwrites paths that appear in the ZIP; optional wipe first removes orphans.
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
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const slug = sanitizeGameStorageSlug(storageSlug);
  if (!slug) {
    throw new Error('Invalid game slug for upload.');
  }
  onProgress?.({ phase: 'parse' });
  const { files, exportRootLabel, indexCandidates, detectedEntry } = await zipToRelativeFiles(zipFile);
  /** Start big binaries first so parallel workers aren’t idle while the last .wasm/.pck trickles in. */
  files.sort((a, b) => b.blob.size - a.blob.size);
  onProgress?.({ phase: 'packaged', exportRootLabel, fileCount: files.length });
  if (wipeFirst) {
    onProgress?.({ phase: 'clearing' });
    await deleteGameBuild(slug);
  }
  onProgress?.({ phase: 'upload', done: 0, total: files.length });
  await uploadExtractedFilesParallel(slug, files, (done, total) => {
    onProgress?.({ phase: 'upload', done, total });
  });
  return { fileCount: files.length, exportRootLabel, indexCandidates, detectedEntry };
}

export async function uploadGameThumbnail(gameSlug: string, file: File): Promise<string> {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
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
  const objectPath = `${slug}/cover.${ext}`;
  const { error } = await supabase.storage.from(GAME_THUMBNAILS_BUCKET).upload(objectPath, file, {
    upsert: true,
    contentType: guessContentType(`x.${ext}`),
    cacheControl: '3600',
  });
  if (error) {
    throw new Error(error.message);
  }
  return publicStorageObjectUrl(GAME_THUMBNAILS_BUCKET, objectPath);
}

export async function uploadGamePreviewVideo(gameSlug: string, file: File): Promise<string> {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
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
  const objectPath = `${slug}/preview.${ext}`;
  const { error } = await supabase.storage.from(GAME_VIDEOS_BUCKET).upload(objectPath, file, {
    upsert: true,
    contentType: guessContentType(`x.${ext}`),
    cacheControl: '3600',
  });
  if (error) {
    throw new Error(error.message);
  }
  return publicStorageObjectUrl(GAME_VIDEOS_BUCKET, objectPath);
}

/** Image block on a custom page (≤ thumbnail bucket limit). */
export async function uploadPageSectionImage(pageSlug: string, sectionId: string, file: File): Promise<string> {
  if (!supabase) {
    throw new Error('Supabase not configured');
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
  const objectPath = `pages/${pslug}/${sid}.${ext}`;
  const { error } = await supabase.storage.from(GAME_THUMBNAILS_BUCKET).upload(objectPath, file, {
    upsert: true,
    contentType: guessContentType(`x.${ext}`),
    cacheControl: '3600',
  });
  if (error) {
    throw new Error(error.message);
  }
  return publicStorageObjectUrl(GAME_THUMBNAILS_BUCKET, objectPath);
}

/** Video block on a custom page. */
export async function uploadPageSectionVideo(pageSlug: string, sectionId: string, file: File): Promise<string> {
  if (!supabase) {
    throw new Error('Supabase not configured');
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
  const objectPath = `pages/${pslug}/${sid}.${ext}`;
  const { error } = await supabase.storage.from(GAME_VIDEOS_BUCKET).upload(objectPath, file, {
    upsert: true,
    contentType: guessContentType(`x.${ext}`),
    cacheControl: '3600',
  });
  if (error) {
    throw new Error(error.message);
  }
  return publicStorageObjectUrl(GAME_VIDEOS_BUCKET, objectPath);
}

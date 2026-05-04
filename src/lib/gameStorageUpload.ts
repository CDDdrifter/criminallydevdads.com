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
  const base = (import.meta.env.VITE_SUPABASE_URL ?? '').replace(/\/$/, '');
  if (!base) {
    return '';
  }
  const safe = encodeURIComponent(storageSlug.trim());
  return `${base}/storage/v1/object/public/${GAME_BUILDS_BUCKET}/${safe}/index.html`;
}

function guessContentType(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase() ?? '';
  const map: Record<string, string> = {
    html: 'text/html; charset=utf-8',
    htm: 'text/html; charset=utf-8',
    js: 'application/javascript',
    mjs: 'application/javascript',
    wasm: 'application/wasm',
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
  };
  return map[ext] ?? 'application/octet-stream';
}

/** Normalize paths in zip to forward slashes. */
function norm(p: string): string {
  return p.replace(/\\/g, '/').replace(/^\//, '');
}

/**
 * Finds the folder prefix that contains the shallowest index.html (Godot export in a subfolder).
 */
function detectHtmlRoot(paths: string[]): string {
  const htmlPaths = paths.filter((p) => p.endsWith('index.html'));
  if (htmlPaths.length === 0) {
    throw new Error('ZIP must contain index.html (Godot Web export root).');
  }
  htmlPaths.sort((a, b) => a.split('/').length - b.split('/').length);
  const shallow = htmlPaths[0];
  if (!shallow) {
    return '';
  }
  const idx = shallow.lastIndexOf('/');
  return idx >= 0 ? shallow.slice(0, idx + 1) : '';
}

/**
 * Zip entries → relative paths under storage slug (no leading slash).
 */
async function zipToRelativeFiles(zipFile: File): Promise<{ path: string; blob: Blob }[]> {
  const buf = await zipFile.arrayBuffer();
  const zip = await JSZip.loadAsync(buf);
  const paths: string[] = [];
  zip.forEach((relPath, entry) => {
    if (!entry.dir) {
      paths.push(norm(relPath));
    }
  });
  const root = detectHtmlRoot(paths);
  const out: { path: string; blob: Blob }[] = [];
  for (const p of paths) {
    if (root && !p.startsWith(root)) {
      continue;
    }
    const rel = root ? p.slice(root.length) : p;
    if (!rel || rel.endsWith('/')) {
      continue;
    }
    const entry = zip.file(p);
    if (!entry) {
      continue;
    }
    const blob = await entry.async('blob');
    out.push({ path: rel, blob });
  }
  if (out.length === 0) {
    throw new Error('No files found under HTML export root.');
  }
  const hasIndex = out.some((f) => f.path === 'index.html');
  if (!hasIndex) {
    throw new Error('Missing index.html next to export assets.');
  }
  return out;
}

async function listStorageFilesRecursive(prefix: string): Promise<string[]> {
  if (!supabase) {
    return [];
  }
  const collected: string[] = [];

  async function walk(p: string): Promise<void> {
    const { data, error } = await supabase!.storage.from(GAME_BUILDS_BUCKET).list(p, {
      limit: 1000,
      sortBy: { column: 'name', order: 'asc' },
    });
    if (error) {
      throw error;
    }
    for (const item of data ?? []) {
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
export async function uploadGameZip(storageSlug: string, zipFile: File, wipeFirst = true): Promise<number> {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const slug = sanitizeGameStorageSlug(storageSlug);
  if (!slug) {
    throw new Error('Invalid game slug for upload.');
  }
  const files = await zipToRelativeFiles(zipFile);
  if (wipeFirst) {
    await deleteGameBuild(slug);
  }
  let uploaded = 0;
  for (const { path: rel, blob } of files) {
    const objectPath = `${slug}/${rel}`;
    const { error } = await supabase.storage.from(GAME_BUILDS_BUCKET).upload(objectPath, blob, {
      upsert: true,
      contentType: guessContentType(rel),
      cacheControl: '3600',
    });
    if (error) {
      throw new Error(`${objectPath}: ${error.message}`);
    }
    uploaded += 1;
  }
  return uploaded;
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

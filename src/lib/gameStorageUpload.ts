import JSZip from 'jszip';
import { supabase } from './supabase';

export const GAME_BUILDS_BUCKET = 'game-builds';

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
    webp: 'image/webp',
    svg: 'image/svg+xml',
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

import JSZip from 'jszip';
import { resolvePublicAssetUrl } from './paths';

const FALLBACK_FILES = [
  'index.html',
  'index.js',
  'index.wasm',
  'index.pck',
  'index.png',
  'index.icon.png',
  'index.apple-touch-icon.png',
  'index.audio.worklet.js',
  'index.audio.position.worklet.js',
  'manifest.json',
  'pwa-boot.js',
  'offline-sw.js',
  'offline-cache.json',
  'cover.png',
];

export function postedGameFolder(localFolder: string, launchPath: string): string | null {
  const folder = localFolder.trim();
  if (folder) {
    return folder.replace(/^games\//, '').replace(/\/$/, '');
  }
  const m = launchPath.trim().match(/^games\/([^/]+)/i);
  return m?.[1] ?? null;
}

async function listPostedFiles(folder: string): Promise<string[]> {
  const cacheUrl = resolvePublicAssetUrl(`games/${folder}/offline-cache.json`);
  try {
    const res = await fetch(cacheUrl);
    if (res.ok) {
      const json = (await res.json()) as { assets?: unknown };
      if (Array.isArray(json.assets) && json.assets.every((n) => typeof n === 'string')) {
        const names = json.assets.map((n) => String(n).replace(/^\.\//, '')).filter((n) => n && !n.includes('..'));
        if (names.length) {
          return names;
        }
      }
    }
  } catch {
    /* use fallback */
  }
  return FALLBACK_FILES;
}

function triggerDownload(blob: Blob, filename: string): void {
  const href = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = href;
  a.download = filename;
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(href);
}

/** Zip the live `/games/<folder>/` build (Godot HTML5 + PWA files) for admins. */
export async function downloadPostedGameFiles(opts: {
  folder: string;
  title?: string;
  onProgress?: (done: number, total: number, name: string) => void;
}): Promise<{ fileCount: number; skipped: string[] }> {
  const folder = opts.folder.replace(/^games\//, '').replace(/\/$/, '');
  if (!folder || folder.includes('..')) {
    throw new Error('Missing game folder.');
  }
  const names = await listPostedFiles(folder);
  const zip = new JSZip();
  const skipped: string[] = [];
  let done = 0;
  for (const name of names) {
    opts.onProgress?.(done, names.length, name);
    const url = resolvePublicAssetUrl(`games/${folder}/${name}`);
    const res = await fetch(url);
    if (!res.ok) {
      skipped.push(name);
      done += 1;
      continue;
    }
    zip.file(name, await res.arrayBuffer());
    done += 1;
    opts.onProgress?.(done, names.length, name);
  }
  const packed = Object.keys(zip.files).length;
  if (!packed) {
    throw new Error(`No files found at games/${folder}/ on this site.`);
  }
  const blob = await zip.generateAsync({ type: 'blob', compression: 'DEFLATE', compressionOptions: { level: 6 } });
  const slug = folder.replace(/[^\w.-]+/g, '-');
  triggerDownload(blob, `${slug}-web-build.zip`);
  return { fileCount: packed, skipped };
}

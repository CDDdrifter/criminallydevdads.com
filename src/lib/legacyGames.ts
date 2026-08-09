/**
 * LEGACY GAME CATALOG (file-based, no Supabase required)
 * =======================================================
 *
 * The hub builds its game list from:
 *
 * 1. `games.json` (repo root) — title, description, thumbnail, optional play URL (`url` or `external_url`).
 * 2. Folders under `games/<slug>/` — especially `index.html` + Godot/Web export files, discovered via the
 *    GitHub Contents API (so the live site knows which folders exist without bundling every file at build time).
 *
 * WHY `url` / `external_url` MATTERS
 * ----------------------------------
 * GitHub’s website caps uploads (~25 MB) and discourages huge repos. Godot HTML5 exports (WASM + pck) are often
 * much larger. You do NOT have to commit those binaries: host the build on itch.io, Netlify Drop, Cloudflare Pages,
 * or any static host, then paste the **https** link to the playable page in `games.json`. No giant Git upload.
 *
 * See: docs/SITE_MANUAL.md
 */

import type { GameView } from '../types';
import { donationPresetsFromUnknown, gamePricingModelFromRecord } from './gamePricing';
import { defaultRouteFxOverride } from './routeFx';
import { normalizeVisualPresetInput } from './visualPresets';
import { resolvePublicAssetUrl } from './paths';
import { firestoreGetGamesCatalog } from './firestoreData';

const REPO_OWNER = import.meta.env.VITE_GITHUB_REPO_OWNER ?? 'CDDdrifter';
const REPO_NAME = import.meta.env.VITE_GITHUB_REPO_NAME ?? 'criminallydevdads.com';

/** One row from root `games.json` (all fields optional except what deriveId() needs). */
type LegacyMeta = {
  id?: string;
  /** Alias for `id` — same string used in URLs: /#/play/my-game-slug */
  slug?: string;
  title?: string;
  type?: string;
  description?: string;
  details?: string;
  thumbnail?: string;
  /** Optional promo clip URL or repo-relative path under site root. */
  preview_video?: string;
  /** Legacy zip name; used only to guess slug when `id` is missing: "my-game.zip" → "my-game" */
  filename?: string;
  /**
   * Full https URL where the game runs (itch.io HTML5, Netlify, your CDN…). If set, the hub does not need
   * `games/<slug>/` in the repo for that title to be playable.
   */
  url?: string;
  /** Same as `url` — use whichever name you prefer in JSON. */
  external_url?: string;
  /** Firebase Storage folder under game-builds/ (set by Admin ZIP upload). */
  storage_slug?: string;
  storage_entry_in_zip?: string;
  /** Direct link to offline .zip / .html download (Firebase Storage or repo path). */
  download_url?: string;
  pricing_model?: string;
  price_cents?: number;
  purchase_url?: string;
  gumroad_url?: string;
  stripe_price_id?: string;
  pwyw_min_cents?: number;
  pwyw_suggested_cents?: number;
  donation_presets_cents?: number[];
  /** Same preset ids as Site Settings / Admin (ember, aurora, …). */
  visual_preset?: string;
  /** Gallery images on the game detail page (repo paths or https URLs). */
  screenshots?: string[];
};

/** Prefer `url`, fall back to `external_url`. */
function playUrl(meta: LegacyMeta): string {
  return (meta.url ?? meta.external_url ?? '').trim();
}

function slugFromFilename(filename = ''): string {
  return filename.replace(/\.zip$/i, '');
}

function titleFromId(id = ''): string {
  return id
    .split('-')
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/** URL-safe slug from title when user added `url` + `title` but forgot `id`. */
function slugFromTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/**
 * Stable slug for routing: prefer explicit `id` / `slug`, then filename stem, then title (if `url` exists).
 */
function deriveId(meta: LegacyMeta): string {
  const explicit = (meta.id ?? meta.slug ?? '').trim();
  if (explicit) {
    return explicit;
  }
  const fromFile = slugFromFilename(meta.filename ?? '');
  if (fromFile) {
    return fromFile;
  }
  const u = playUrl(meta);
  const t = (meta.title ?? '').trim();
  if (u && t) {
    const s = slugFromTitle(t);
    if (s) {
      return s;
    }
  }
  return '';
}

export async function pathExists(path: string): Promise<boolean> {
  const url = /^https?:\/\//i.test(path) ? path : resolvePublicAssetUrl(path);
  try {
    const response = await fetch(url, { cache: 'no-store', signal: AbortSignal.timeout(4000) });
    if (!response.ok) {
      return false;
    }
    /** Wrong Play URL: JSON error body, JS MIME, etc. — don’t mark playable (avoids iframe full of “code”). */
    const ct = response.headers.get('content-type') ?? '';
    if (/\.supabase\.co\/storage\//i.test(url)) {
      if (/application\/json/i.test(ct) || /(javascript|ecmascript)/i.test(ct)) {
        return false;
      }
    }
    return true;
  } catch {
    return false;
  }
}

async function resolveThumbnailFromIndexHtml(
  launchPath: string,
  folderId: string,
): Promise<string> {
  try {
    const fetchUrl = /^https?:\/\//i.test(launchPath) ? launchPath : resolvePublicAssetUrl(launchPath);
    const response = await fetch(fetchUrl, { cache: 'no-store' });
    if (!response.ok) {
      return '';
    }
    const html = await response.text();
    const candidates: string[] = [];
    const splashMatch = html.match(/id=["']status-splash["'][^>]*src=["']([^"']+)["']/i);
    if (splashMatch?.[1]) {
      candidates.push(`games/${folderId}/${splashMatch[1]}`);
    }
    const iconMatch = html.match(/id=["']-gd-engine-icon["'][^>]*href=["']([^"']+)["']/i);
    if (iconMatch?.[1]) {
      candidates.push(`games/${folderId}/${iconMatch[1]}`);
    }
    for (const candidate of candidates) {
      if (await pathExists(candidate)) {
        return candidate;
      }
    }
    return '';
  } catch {
    return '';
  }
}

async function loadOptionalMetadata(): Promise<LegacyMeta[]> {
  try {
    const fromFirestore = await firestoreGetGamesCatalog();
    if (Array.isArray(fromFirestore) && fromFirestore.length > 0) {
      return fromFirestore as LegacyMeta[];
    }
  } catch {
    // Fall through to static games.json
  }
  try {
    const response = await fetch('/games.json', { cache: 'no-store' });
    if (!response.ok) {
      return [];
    }
    const data: unknown = await response.json();
    return Array.isArray(data) ? (data as LegacyMeta[]) : [];
  } catch {
    return [];
  }
}

/**
 * Lists subfolders of `games/` on the default branch via GitHub’s API.
 * If this fails (rate limit, private repo, wrong owner/name), we return [] and rely on `games.json` + any
 * folders you still sync at build time under `games/` locally — the live list may be incomplete until API works.
 */
async function discoverGameFolders(): Promise<string[]> {
  try {
    const apiUrl = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/games`;
    const response = await fetch(apiUrl, { cache: 'no-store' });
    if (!response.ok) {
      console.warn(
        `[hub] Could not list repo games/ via GitHub API (${response.status}). ` +
          `Catalog will use games.json and local games/ copy only. Check VITE_GITHUB_REPO_OWNER / VITE_GITHUB_REPO_NAME.`,
      );
      return [];
    }
    const items: unknown = await response.json();
    if (!Array.isArray(items)) {
      return [];
    }
    return items
      .filter(
        (item): item is { type: string; name: string } =>
          Boolean(item && typeof item === 'object' && 'type' in item && 'name' in item) &&
          (item as { type: string }).type === 'dir' &&
          typeof (item as { name: string }).name === 'string' &&
          !(item as { name: string }).name.startsWith('.'),
      )
      .map((item) => item.name);
  } catch (e) {
    console.warn('[hub] GitHub games/ listing failed:', e);
    return [];
  }
}

async function buildGameFromFolder(
  folderId: string,
  metadataById: Record<string, LegacyMeta>,
): Promise<GameView> {
  const metadata = metadataById[folderId] ?? {};
  const external = playUrl(metadata);
  const entryRel = (metadata.storage_entry_in_zip ?? 'index.html').trim() || 'index.html';
  const downloadUrl = (metadata.download_url ?? '').trim();
  const localLaunch = `games/${folderId}/${entryRel}`;
  const isLocalPlayable = await pathExists(localLaunch);
  const thumbnailCandidates = [
    `games/${folderId}/cover.png`,
    `games/${folderId}/cover.jpg`,
    `games/${folderId}/cover.jpeg`,
    `games/${folderId}/cover.webp`,
    `games/${folderId}/cover.gif`,
    `games/${folderId}/cover.svg`,
    `games/${folderId}/index.png`,
    `games/${folderId}/index.icon.png`,
    `games/${folderId}/icon.png`,
    `games/${folderId}/icon.svg`,
  ];
  const metadataThumb = String(metadata.thumbnail ?? '').trim();
  let resolvedThumbnail = metadataThumb;
  if (!resolvedThumbnail) {
    for (const candidate of thumbnailCandidates) {
      if (await pathExists(candidate)) {
        resolvedThumbnail = candidate;
        break;
      }
    }
  }
  if (!resolvedThumbnail && isLocalPlayable) {
    resolvedThumbnail = await resolveThumbnailFromIndexHtml(localLaunch, folderId);
  }
  const id = metadata.id ?? folderId;
  const previewRaw = (metadata.preview_video ?? '').trim();
  const priceCents = Math.max(0, Math.round(Number(metadata.price_cents ?? 0)));
  return {
    id,
    slug: folderId,
    title: metadata.title ?? titleFromId(folderId),
    type: metadata.type ?? 'game',
    description: metadata.description ?? 'Auto-discovered game build from the games folder.',
    details:
      metadata.details ??
      'This game was auto-added because a web build was detected in the games directory.',
    thumbnail: resolvedThumbnail,
    tab_icon: '',
    preview_video: previewRaw ? resolvePublicAssetUrl(previewRaw) : '',
    external_url: external,
    local_folder: folderId,
    storage_slug: '',
    storage_entry_in_zip: entryRel,
    download_url: downloadUrl,
    launchPath: external || localLaunch,
    isPlayable: Boolean(external || isLocalPlayable || downloadUrl),
    sections: [],
    visual_preset: normalizeVisualPresetInput(metadata.visual_preset),
    pricing_model: gamePricingModelFromRecord(metadata.pricing_model, priceCents),
    price_cents: priceCents,
    purchase_url: String(metadata.purchase_url ?? '').trim(),
    gumroad_url: String(metadata.gumroad_url ?? '').trim(),
    stripe_price_id: String(metadata.stripe_price_id ?? '').trim(),
    pwyw_min_cents: Math.max(0, Math.round(Number(metadata.pwyw_min_cents ?? 0))),
    pwyw_suggested_cents: Math.max(0, Math.round(Number(metadata.pwyw_suggested_cents ?? 0))),
    donation_presets_cents: donationPresetsFromUnknown(metadata.donation_presets_cents),
    in_vault: false,
    published: true,
    immersive_layout: false,
    custom_mood_css: '',
    route_fx: defaultRouteFxOverride(),
    tags: [],
    release_date: '',
    platforms: [],
    screenshots: Array.isArray(metadata.screenshots)
      ? metadata.screenshots.map(String).filter(Boolean)
      : [],
    features: [],
    controls: [],
    credits: [],
    changelog: [],
    system_requirements: [],
  };
}

/** Shared in-memory cache — avoids re-probing every game asset on each route. */
let legacyGamesPromise: Promise<GameView[]> | null = null;

export function resetLegacyGamesCache(): void {
  legacyGamesPromise = null;
}

export async function loadLegacyGames(): Promise<GameView[]> {
  if (!legacyGamesPromise) {
    legacyGamesPromise = loadLegacyGamesUncached().catch((err) => {
      legacyGamesPromise = null;
      throw err;
    });
  }
  return legacyGamesPromise;
}

async function loadLegacyGamesUncached(): Promise<GameView[]> {
  const metadataList = await loadOptionalMetadata();
  const metadataById = metadataList.reduce<Record<string, LegacyMeta>>((acc, raw) => {
    const merged: LegacyMeta = { ...raw, url: playUrl(raw) || undefined };
    const id = deriveId(merged);
    if (id) {
      acc[id] = { ...merged, id };
    }
    return acc;
  }, {});

  const folderIds = await discoverGameFolders();
  const folderSet = new Set(folderIds);

  const discoveredGames = await Promise.all(
    folderIds.map((folderId) => buildGameFromFolder(folderId, metadataById)),
  );

  const orphanIds = Object.keys(metadataById).filter((id) => !folderSet.has(id));
  const orphanGames =
    orphanIds.length > 0
      ? await Promise.all(orphanIds.map((id) => buildGameFromFolder(id, metadataById)))
      : [];

  const bySlug = new Map<string, GameView>();
  for (const g of discoveredGames) {
    bySlug.set(g.slug, g);
  }
  for (const g of orphanGames) {
    if (!bySlug.has(g.slug)) {
      bySlug.set(g.slug, g);
    }
  }

  return [...bySlug.values()].sort((a, b) => a.title.localeCompare(b.title));
}

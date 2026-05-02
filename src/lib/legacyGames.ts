import type { GameView } from '../types';
import { resolvePublicAssetUrl } from './paths';

const REPO_OWNER = import.meta.env.VITE_GITHUB_REPO_OWNER ?? 'CDDdrifter';
const REPO_NAME = import.meta.env.VITE_GITHUB_REPO_NAME ?? 'criminallydevdads.com';

type LegacyMeta = {
  id?: string;
  title?: string;
  type?: string;
  description?: string;
  details?: string;
  thumbnail?: string;
  filename?: string;
  url?: string;
};

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

export async function pathExists(path: string): Promise<boolean> {
  const url = /^https?:\/\//i.test(path) ? path : resolvePublicAssetUrl(path);
  try {
    const response = await fetch(url, { cache: 'no-store' });
    return response.ok;
  } catch {
    return false;
  }
}

async function resolveThumbnailFromIndexHtml(
  launchPath: string,
  folderId: string,
): Promise<string> {
  try {
    const response = await fetch(launchPath, { cache: 'no-store' });
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

async function discoverGameFolders(): Promise<string[]> {
  const apiUrl = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/games`;
  const response = await fetch(apiUrl, { cache: 'no-store' });
  if (!response.ok) {
    throw new Error(`Could not load game folders (${response.status})`);
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
}

async function buildGameFromFolder(
  folderId: string,
  metadataById: Record<string, LegacyMeta>,
): Promise<GameView> {
  const metadata = metadataById[folderId] ?? {};
  const launchPath = `games/${folderId}/index.html`;
  const isPlayable = await pathExists(launchPath);
  const thumbnailCandidates = [
    `games/${folderId}/index.png`,
    `games/${folderId}/index.icon.png`,
    `games/${folderId}/icon.png`,
    `games/${folderId}/icon.svg`,
  ];
  let resolvedThumbnail = '';
  for (const candidate of thumbnailCandidates) {
    if (await pathExists(candidate)) {
      resolvedThumbnail = candidate;
      break;
    }
  }
  if (!resolvedThumbnail && isPlayable) {
    resolvedThumbnail = await resolveThumbnailFromIndexHtml(launchPath, folderId);
  }
  const id = metadata.id ?? folderId;
  return {
    id,
    slug: folderId,
    title: metadata.title ?? titleFromId(folderId),
    type: metadata.type ?? 'game',
    description: metadata.description ?? 'Auto-discovered game build from the games folder.',
    details:
      metadata.details ??
      'This game was auto-added because a web build was detected in the games directory.',
    thumbnail: resolvedThumbnail || metadata.thumbnail || '',
    external_url: metadata.url ?? '',
    local_folder: folderId,
    launchPath: metadata.url || launchPath,
    isPlayable: Boolean(metadata.url) || isPlayable,
  };
}

export async function loadLegacyGames(): Promise<GameView[]> {
  const metadataList = await loadOptionalMetadata();
  const metadataById = metadataList.reduce<Record<string, LegacyMeta>>((acc, game) => {
    const id = game.id ?? slugFromFilename(game.filename ?? '');
    if (id) {
      acc[id] = game;
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

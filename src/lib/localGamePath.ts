/** True when this title is a repo-hosted web build under `games/`, not an external itch/CDN URL. */
export function isLocalRepoGamePath(launchPath: string): boolean {
  const p = launchPath.trim();
  return p.startsWith('games/') && !/^https?:\/\//i.test(p);
}

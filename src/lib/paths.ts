/** Resolve playable URL for iframe / window (works with HashRouter + relative site base). */
export function resolveGameUrl(launchPath: string): string {
  if (/^https?:\/\//i.test(launchPath)) {
    return launchPath;
  }
  return new URL(launchPath, window.location.href).href;
}

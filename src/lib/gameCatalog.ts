/** Where the public game list comes from. See docs/WEBSITE_WORKFLOW.md */
export type GameCatalogMode = 'auto' | 'legacy' | 'cms';

export function gameCatalogMode(): GameCatalogMode {
  const v = (import.meta.env.VITE_GAME_CATALOG ?? 'auto').toLowerCase().trim();
  if (v === 'legacy' || v === 'cms') {
    return v;
  }
  return 'auto';
}

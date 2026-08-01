/** Where the public game list comes from. Default: legacy (games.json + games/ folder). */
export type GameCatalogMode = 'auto' | 'legacy' | 'cms';

export function gameCatalogMode(): GameCatalogMode {
  const v = (import.meta.env.VITE_GAME_CATALOG ?? 'legacy').toLowerCase().trim();
  if (v === 'legacy' || v === 'cms') {
    return v;
  }
  return 'auto';
}

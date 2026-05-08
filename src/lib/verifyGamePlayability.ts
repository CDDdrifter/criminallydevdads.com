import type { GameView } from '../types';
import { pathExists } from './legacyGames';

/** HEAD/GET check that `launchPath` resolves (Storage URL or static games/ path). */
export async function verifyGamePlayability(games: GameView[]): Promise<GameView[]> {
  return Promise.all(
    games.map(async (g) => {
      const ok = await pathExists(g.launchPath);
      return { ...g, isPlayable: ok };
    }),
  );
}

import { useEffect, useState } from 'react';
import type { GameView } from '../types';
import { fetchPublishedGames } from '../lib/cmsData';
import { supabaseConfigured } from '../lib/supabase';
import { loadLegacyGames, pathExists } from '../lib/legacyGames';

async function verifyPlayability(games: GameView[]): Promise<GameView[]> {
  return Promise.all(
    games.map(async (g) => {
      if (g.external_url) {
        return { ...g, isPlayable: true, launchPath: g.external_url };
      }
      const ok = await pathExists(g.launchPath);
      return { ...g, isPlayable: ok };
    }),
  );
}

export function useGames() {
  const [games, setGames] = useState<GameView[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        // Website-only catalog: when Supabase env is present, games come only from Admin/CMS + ZIP storage.
        // No fallback to GitHub folders / games.json (avoids repo edits per release).
        if (supabaseConfigured) {
          const cms = await fetchPublishedGames();
          const verified = await verifyPlayability(cms);
          if (!cancelled) {
            setGames(verified);
          }
          return;
        }
        const legacy = await loadLegacyGames();
        if (!cancelled) {
          setGames(legacy);
        }
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : 'Failed to load games');
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return { games, loading, error };
}

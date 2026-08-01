/**
 * Loads the public game list (CMS and/or legacy file catalog).
 * How to add games without huge Git uploads: docs/SITE_MANUAL.md
 */
import { useEffect, useState } from 'react';
import type { GameView } from '../types';
import { fetchPublishedGames } from '../lib/cmsData';
import { gameCatalogMode } from '../lib/gameCatalog';
import { backendConfigured } from '../lib/backend';
import { loadLegacyGames } from '../lib/legacyGames';
import { verifyGamePlayability } from '../lib/verifyGamePlayability';

export function useGames() {
  const [games, setGames] = useState<GameView[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const mode = gameCatalogMode();

        if (mode === 'legacy' || !backendConfigured()) {
          const legacy = await loadLegacyGames();
          if (!cancelled) {
            setGames(legacy);
          }
          return;
        }

        if (mode === 'cms') {
          const cms = await fetchPublishedGames();
          const verified = await verifyGamePlayability(cms);
          if (!cancelled) {
            setGames(verified);
          }
          return;
        }

        // auto: prefer CMS when it returns games; otherwise games.json + games/ (never brick the hub).
        let cms: GameView[] = [];
        if (backendConfigured()) {
          try {
            cms = await fetchPublishedGames();
          } catch (cmsErr) {
            console.warn('Game catalog: CMS fetch failed, using games.json', cmsErr);
          }
        }
        if (cms.length > 0) {
          const verified = await verifyGamePlayability(cms);
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

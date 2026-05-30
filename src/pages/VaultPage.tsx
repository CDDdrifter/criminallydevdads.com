import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { GameCardMetaChips } from '../components/GameCardMetaChips';
import { GameCardThumbnail } from '../components/GameCardThumbnail';
import { PageSectionsView } from '../components/PageSectionsView';
import { SiteChrome } from '../components/SiteChrome';
import { useSiteSettings } from '../hooks/useSiteSettings';
import { fetchVaultGames } from '../lib/cmsData';
import { supabaseConfigured } from '../lib/supabase';
import { verifyGamePlayability } from '../lib/verifyGamePlayability';
import type { GameView } from '../types';

/**
 * Secondary catalog at <code>/#/vault</code> — games with <code>in_vault</code> set in Admin.
 * Can include titles not on the main hub (<code>published</code> false).
 */
export function VaultPage() {
  const { settings } = useSiteSettings();
  const cfg = settings.prebuilt_pages.vault;
  const [games, setGames] = useState<GameView[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const raw = await fetchVaultGames();
        const verified = await verifyGamePlayability(raw);
        if (!cancelled) {
          setGames(verified);
        }
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : 'Failed to load vault');
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

  return (
    <SiteChrome>
      <header>
        {cfg.eyebrow ? <div className="services-hero__eyebrow">{cfg.eyebrow}</div> : null}
        <div className="header-title">{cfg.heading}</div>
        {cfg.subtitle ? <div className="header-subtitle">{cfg.subtitle}</div> : null}
      </header>

      {cfg.intro_sections.length > 0 ? <PageSectionsView sections={cfg.intro_sections} /> : null}

      {!supabaseConfigured ? (
        <div className="empty-state">Vault requires Supabase (CMS mode).</div>
      ) : null}
      {loading && <div className="empty-state">Loading vault…</div>}
      {error && <div className="empty-state">Error: {error}</div>}

      {!loading && !error && games.length === 0 ? (
        <div className="empty-state">
          <p>No vault games yet.</p>
          <p className="admin-muted" style={{ marginTop: 12 }}>
            In <Link to="/admin">Admin</Link> → Games, enable <strong>List in Vault library</strong> on a row. You can
            leave <strong>Published on main hub</strong> off for vault-only titles.
          </p>
        </div>
      ) : null}

      {!loading && !error && games.length > 0 ? (
        <div className="game-grid">
          {games.map((game, index) => (
            <Link
              key={game.slug}
              to={`/game/${game.slug}`}
              className="game-card game-card--link"
              style={{ ['--i' as string]: index }}
            >
              <GameCardThumbnail game={game} />
              <div className="game-info">
                <div className="game-type">{game.type}</div>
                <div className="game-title">{game.title}</div>
                <GameCardMetaChips tags={game.tags} platforms={game.platforms} />
                <div className="game-description">{game.description}</div>
              </div>
            </Link>
          ))}
        </div>
      ) : null}

      {cfg.outro_sections.length > 0 ? <PageSectionsView sections={cfg.outro_sections} /> : null}

      <p style={{ textAlign: 'center', marginTop: 32 }} className="admin-muted">
        <Link to="/">← Main hub</Link>
      </p>
    </SiteChrome>
  );
}

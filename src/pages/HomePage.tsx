import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { useGames } from '../hooks/useGames';
import { gameCatalogMode } from '../lib/gameCatalog';
import { supabaseConfigured } from '../lib/supabase';
import { useSiteSettings } from '../hooks/useSiteSettings';

export function HomePage() {
  const { games, loading, error } = useGames();
  const settings = useSiteSettings();
  const [filter, setFilter] = useState<'all' | 'game' | 'asset'>('all');

  useEffect(() => {
    delete document.documentElement.dataset.visualPreset;
  }, []);

  const filtered =
    filter === 'all' ? games : games.filter((g) => g.type.toLowerCase() === filter);

  return (
    <SiteChrome>
      <header>
        <div className="header-title">{settings.hero_title}</div>
        <div className="header-subtitle">{settings.hero_subtitle}</div>
      </header>

      <div className="filter-buttons">
        <button type="button" className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>
          ALL
        </button>
        <button
          type="button"
          className={filter === 'game' ? 'active' : ''}
          onClick={() => setFilter('game')}
        >
          GAMES
        </button>
        <button
          type="button"
          className={filter === 'asset' ? 'active' : ''}
          onClick={() => setFilter('asset')}
        >
          ASSETS
        </button>
      </div>

      {loading && <div className="empty-state">Loading catalog…</div>}
      {error && <div className="empty-state">Error: {error}</div>}

      {!loading && !error && filtered.length === 0 && (
        <div className="empty-state">
          <p>No games found in this category.</p>
          {games.length === 0 && filter === 'all' ? (
            <p style={{ marginTop: 16 }} className="admin-muted">
              {supabaseConfigured && gameCatalogMode() === 'cms' ? (
                <>
                  <Link to="/admin">Open Admin</Link> to add games, or set{' '}
                  <code>VITE_GAME_CATALOG=auto</code> in the build to use <code>games.json</code> again.
                </>
              ) : (
                <>
                  Edit <code>games.json</code> and put builds in <code>games/&lt;slug&gt;/</code>, then push.
                  {supabaseConfigured ? (
                    <>
                      {' '}
                      Or <Link to="/admin">Admin</Link> once your team login works.
                    </>
                  ) : null}{' '}
                  See <code>docs/WEBSITE_WORKFLOW.md</code>.
                </>
              )}
            </p>
          ) : null}
        </div>
      )}

      {!loading && !error && filtered.length > 0 && (
        <div className="game-grid">
          {filtered.map((game, index) => (
            <Link
              key={game.slug}
              to={`/game/${game.slug}`}
              className="game-card game-card--link"
              style={{ ['--i' as string]: index }}
            >
              <div className="game-thumbnail">
                {game.thumbnail ? (
                  <img src={game.thumbnail} alt={game.title} />
                ) : (
                  '🎮'
                )}
              </div>
              <div className="game-info">
                <div className="game-type">{game.type}</div>
                <div className="game-title">{game.title}</div>
                <div className="game-description">{game.description}</div>
              </div>
            </Link>
          ))}
        </div>
      )}

      <div className="support-section">
        <div className="support-title">{settings.support_title}</div>
        <p style={{ marginBottom: 30, color: '#aaa', fontSize: '0.95rem' }} className="prose">
          {settings.support_body}
        </p>
        <div className="support-buttons">
          <button type="button" className="btn-support" disabled style={{ opacity: 0.5 }}>
            💰 Donate
          </button>
          <button type="button" className="btn-support" disabled style={{ opacity: 0.5 }}>
            🛒 Merch Shop
          </button>
          <button
            type="button"
            className="btn-support"
            onClick={() => {
              window.location.href = 'mailto:contact@criminallydevdads.com';
            }}
          >
            📧 Contact Us
          </button>
        </div>
      </div>

      <footer>{settings.footer_text}</footer>
    </SiteChrome>
  );
}

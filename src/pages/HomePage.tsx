import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { useGames } from '../hooks/useGames';
import { gameCatalogMode } from '../lib/gameCatalog';
import { supabaseConfigured } from '../lib/supabase';
import { useSiteSettings } from '../hooks/useSiteSettings';
import type { GameView } from '../types';

export function HomePage() {
  const { games, loading, error } = useGames();
  const settings = useSiteSettings();
  const [filter, setFilter] = useState<'all' | 'game' | 'asset'>('all');
  const [modalGame, setModalGame] = useState<GameView | null>(null);

  useEffect(() => {
    if (modalGame) {
      document.body.classList.add('modal-open');
    } else {
      document.body.classList.remove('modal-open');
    }
  }, [modalGame]);

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
            <div key={game.slug} className="game-card" style={{ ['--i' as string]: index }}>
              <Link to={`/game/${game.slug}`} style={{ textDecoration: 'none', color: 'inherit' }}>
                <div className="game-thumbnail">
                  {game.thumbnail ? (
                    <img src={game.thumbnail} alt={game.title} />
                  ) : (
                    '🎮'
                  )}
                </div>
              </Link>
              <div className="game-info">
                <div className="game-type">{game.type}</div>
                <div className="game-title">{game.title}</div>
                <div className="game-description">{game.description}</div>
                <div className="game-actions">
                  <Link to={`/play/${game.slug}`} className="btn-play" style={{ textAlign: 'center' }}>
                    {game.isPlayable ? 'Play Now' : 'Setup Needed'}
                  </Link>
                  <button type="button" className="btn-download" onClick={() => setModalGame(game)}>
                    Info
                  </button>
                </div>
              </div>
            </div>
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

      <div
        className={`modal${modalGame ? ' open' : ''}`}
        onClick={(e) => {
          if (e.target === e.currentTarget) {
            setModalGame(null);
            document.body.classList.remove('modal-open');
          }
        }}
        role="presentation"
      >
        {modalGame && (
          <div className="modal-content">
            <button type="button" className="close" onClick={() => setModalGame(null)} aria-label="Close">
              &times;
            </button>
            <h2 style={{ color: 'var(--accent)', marginBottom: 20 }}>{modalGame.title}</h2>
            {modalGame.thumbnail ? (
              <img
                src={modalGame.thumbnail}
                alt=""
                style={{ width: '100%', maxHeight: 300, objectFit: 'cover', borderRadius: 6, marginBottom: 20 }}
                onError={(e) => {
                  e.currentTarget.style.display = 'none';
                }}
              />
            ) : null}
            {modalGame.preview_video ? (
              <video
                src={modalGame.preview_video}
                controls
                playsInline
                style={{
                  width: '100%',
                  maxHeight: 280,
                  borderRadius: 6,
                  marginBottom: 20,
                  background: '#070b12',
                }}
              />
            ) : null}
            <p style={{ marginBottom: 15, lineHeight: 1.6 }}>{modalGame.details || modalGame.description}</p>
            <div style={{ marginTop: 30, paddingTop: 20, borderTop: '1px solid var(--accent)' }}>
              <p style={{ color: '#aaa', fontSize: '0.9rem', marginBottom: 20 }}>
                <strong>Type:</strong> {modalGame.type.toUpperCase()} | <strong>Slug:</strong> {modalGame.slug}
              </p>
              <div style={{ display: 'flex', gap: 15, flexWrap: 'wrap' }}>
                <Link
                  to={`/play/${modalGame.slug}`}
                  className="btn-play"
                  style={{ flex: 1, textAlign: 'center', padding: 12 }}
                >
                  {modalGame.isPlayable ? 'PLAY NOW' : 'SETUP NEEDED'}
                </Link>
                <button
                  type="button"
                  style={{
                    flex: 1,
                    padding: 12,
                    background: '#555',
                    color: '#fff',
                    border: 'none',
                    borderRadius: 6,
                    cursor: 'pointer',
                    fontWeight: 'bold',
                  }}
                  onClick={() => setModalGame(null)}
                >
                  CLOSE
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </SiteChrome>
  );
}

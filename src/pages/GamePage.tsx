import { Link, useParams } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { useGames } from '../hooks/useGames';

export function GamePage() {
  const { slug } = useParams<{ slug: string }>();
  const { games, loading, error } = useGames();
  const game = games.find((g) => g.slug === slug);

  if (loading) {
    return (
      <SiteChrome>
        <div className="empty-state">Loading…</div>
      </SiteChrome>
    );
  }

  if (error || !game) {
    return (
      <SiteChrome>
        <div className="empty-state">{error ?? 'Game not found.'}</div>
        <p style={{ textAlign: 'center' }}>
          <Link to="/">← Back to hub</Link>
        </p>
      </SiteChrome>
    );
  }

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <header>
        <div className="header-title" style={{ fontSize: '2rem' }}>
          {game.title}
        </div>
        <div className="header-subtitle">{game.type.toUpperCase()} · {game.slug}</div>
      </header>

      <div className="admin-panel" style={{ marginBottom: 24 }}>
        {game.thumbnail ? (
          <img
            src={game.thumbnail}
            alt=""
            style={{ width: '100%', maxHeight: 360, objectFit: 'cover', borderRadius: 8, marginBottom: 16 }}
          />
        ) : null}
        <div className="prose" style={{ marginBottom: 20 }}>
          {game.details || game.description}
        </div>
        <div className="game-actions" style={{ maxWidth: 420 }}>
          <Link to={`/play/${game.slug}`} className="btn-play" style={{ textAlign: 'center' }}>
            {game.isPlayable ? 'Play in browser' : 'Setup needed'}
          </Link>
          {game.external_url ? (
            <a className="btn-download" href={game.external_url} target="_blank" rel="noreferrer">
              External link
            </a>
          ) : null}
        </div>
      </div>
    </SiteChrome>
  );
}

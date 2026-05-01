import { Link, useParams } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { useGames } from '../hooks/useGames';
import { resolveGameUrl } from '../lib/paths';

export function PlayPage() {
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
          <Link to="/">← Back</Link>
        </p>
      </SiteChrome>
    );
  }

  if (!game.isPlayable) {
    return (
      <SiteChrome navExtra={<Link to={`/game/${game.slug}`}>← Details</Link>}>
        <div className="admin-panel danger-zone">
          <p className="admin-muted">
            This build is not reachable at <code>{game.launchPath}</code>. Upload the web export to{' '}
            <code>games/{game.local_folder}/</code> or set an external URL in the admin.
          </p>
        </div>
      </SiteChrome>
    );
  }

  const src = resolveGameUrl(game.launchPath);

  return (
    <SiteChrome
      navExtra={
        <>
          <Link to={`/game/${game.slug}`}>Details</Link>
          <Link to="/">Hub</Link>
        </>
      }
    >
      <div className="admin-muted" style={{ marginBottom: 12 }}>
        Playing: <strong>{game.title}</strong>
      </div>
      <div className="game-embed-wrap">
        <iframe title={game.title} src={src} allow="fullscreen; gamepad; autoplay" />
      </div>
    </SiteChrome>
  );
}

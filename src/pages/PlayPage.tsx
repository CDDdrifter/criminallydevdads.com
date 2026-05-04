import { Link, useParams } from 'react-router-dom';
import { GamePlayerEmbed } from '../components/GamePlayerEmbed';
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
            This build is not reachable at <code>{game.launchPath}</code>. Fix it by: (1) adding{' '}
            <code>&quot;url&quot;: &quot;https://…&quot;</code> in <code>games.json</code> for big games hosted on itch /
            Netlify / etc., (2) putting <code>index.html</code> under <code>games/{game.local_folder}/</code> and
            pushing (use Git CLI if files are over 25MB — see <code>docs/SITE_MANUAL.md</code>), or (3) using Admin +
            Supabase if you use that setup. If the link opens fine in a new tab but the hub still says this, trigger
            a refresh; for Godot 4 HTML5 with threads enabled, upload may not be enough — use an external host and{' '}
            <strong>External play URL</strong>.
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
        <GamePlayerEmbed title={game.title} src={src} />
      </div>
    </SiteChrome>
  );
}

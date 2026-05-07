import { useEffect } from 'react';
import { Link, useParams } from 'react-router-dom';
import { GameEmbedSection } from '../components/GameEmbedSection';
import { SiteChrome } from '../components/SiteChrome';
import { useGames } from '../hooks/useGames';
import { normalizeVisualPresetInput } from '../lib/visualPresets';

export function PlayPage() {
  const { slug } = useParams<{ slug: string }>();
  const { games, loading, error } = useGames();
  const game = games.find((g) => g.slug === slug);

  useEffect(() => {
    const preset = normalizeVisualPresetInput(game?.visual_preset);
    if (preset) {
      document.documentElement.dataset.visualPreset = preset;
    } else {
      delete document.documentElement.dataset.visualPreset;
    }
    return () => {
      delete document.documentElement.dataset.visualPreset;
    };
  }, [game?.visual_preset]);

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
          <p className="admin-muted" style={{ marginTop: 12 }}>
            <strong>GitHub Actions secrets:</strong> <code>VITE_SUPABASE_URL</code> must be the full{' '}
            <code>https://YOUR_REF.supabase.co</code> from <strong>Project Settings → API → Project URL</strong> (not the
            Project ID alone, not the dashboard link). See <code>docs/SUPABASE_COPY_THESE_TWO_VALUES.md</code>.
          </p>
        </div>
      </SiteChrome>
    );
  }

  return (
    <SiteChrome
      navExtra={
        <>
          <Link to={`/game/${game.slug}`}>Details</Link>
          <Link to="/">Hub</Link>
        </>
      }
    >
      <GameEmbedSection game={game} />
    </SiteChrome>
  );
}

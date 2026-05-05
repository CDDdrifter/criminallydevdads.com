import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { GamePlayerEmbed } from '../components/GamePlayerEmbed';
import { SiteChrome } from '../components/SiteChrome';
import { useGames } from '../hooks/useGames';
import { probeGamePlayUrl } from '../lib/playUrlProbe';
import { resolveGameUrl } from '../lib/paths';

export function PlayPage() {
  const { slug } = useParams<{ slug: string }>();
  const { games, loading, error } = useGames();
  const game = games.find((g) => g.slug === slug);

  const [probeState, setProbeState] = useState<'idle' | 'checking' | 'ready' | 'failed'>('idle');
  const [iframeSrc, setIframeSrc] = useState<string | null>(null);
  const [probeError, setProbeError] = useState<{ summary: string; detail: string } | null>(null);

  useEffect(() => {
    if (!game?.isPlayable) {
      setProbeState('idle');
      setIframeSrc(null);
      setProbeError(null);
      return;
    }
    const url = resolveGameUrl(game.launchPath);
    let cancelled = false;
    setProbeState('checking');
    setIframeSrc(null);
    setProbeError(null);
    void probeGamePlayUrl(url).then((result) => {
      if (cancelled) {
        return;
      }
      if (result.ok) {
        setIframeSrc(result.url);
        setProbeState('ready');
      } else {
        setProbeError({ summary: result.summary, detail: result.detail });
        setProbeState('failed');
      }
    });
    return () => {
      cancelled = true;
    };
  }, [game?.slug, game?.launchPath, game?.isPlayable]);

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

  const resolvedUrl = resolveGameUrl(game.launchPath);

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
        {' · '}
        <a href={resolvedUrl} target="_blank" rel="noreferrer">
          Open play URL in new tab
        </a>
      </div>

      {probeState === 'checking' ? (
        <div className="empty-state">Checking game link…</div>
      ) : null}

      {probeState === 'failed' && probeError ? (
        <div className="admin-panel danger-zone" style={{ marginBottom: 16 }}>
          <p style={{ marginTop: 0 }}>
            <strong>{probeError.summary}</strong>
          </p>
          <p className="admin-muted" style={{ whiteSpace: 'pre-wrap', marginBottom: 12 }}>
            {probeError.detail}
          </p>
          <p className="admin-muted" style={{ marginBottom: 0 }}>
            Play URL:{' '}
            <a href={resolvedUrl} target="_blank" rel="noreferrer">
              <code style={{ wordBreak: 'break-all' }}>{resolvedUrl}</code>
            </a>
          </p>
        </div>
      ) : null}

      {probeState === 'ready' && iframeSrc ? (
        <div className="game-embed-wrap">
          <GamePlayerEmbed title={game.title} src={iframeSrc} />
        </div>
      ) : null}
    </SiteChrome>
  );
}

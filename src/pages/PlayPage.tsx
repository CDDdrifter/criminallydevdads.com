import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { GameEmbedSection } from '../components/GameEmbedSection';
import { RouteScopedCss } from '../components/RouteScopedCss';
import { SiteChrome } from '../components/SiteChrome';
import { fetchGameViewBySlug } from '../lib/cmsData';
import { useRouteBranding } from '../hooks/useRouteBranding';
import { useRouteFxSync } from '../hooks/useRouteFxSync';
import { resolveGameTabIcon } from '../lib/routeBranding';
import { useSiteSettings } from '../hooks/useSiteSettings';
import { useAuth } from '../context/AuthContext';
import { applyVisualPresetToDocument, resolveVisualPreset } from '../lib/routeFx';
import { trackGamePlay } from '../lib/analytics';
import type { GameView } from '../types';

export function PlayPage() {
  const { slug } = useParams<{ slug: string }>();
  const { settings } = useSiteSettings();
  const { isAdmin } = useAuth();
  const [game, setGame] = useState<GameView | null | undefined>(undefined);
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    if (!slug?.trim()) {
      setGame(null);
      setLoadError('Missing game slug.');
      return;
    }
    let cancelled = false;
    setGame(undefined);
    setLoadError(null);
    (async () => {
      const row = await fetchGameViewBySlug(slug.trim());
      if (cancelled) {
        return;
      }
      if (!row) {
        setGame(null);
        setLoadError('Game not found, or it is a draft.');
        return;
      }
      if (!cancelled) {
        setGame(row);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [slug]);

  useRouteFxSync(game?.route_fx);

  useRouteBranding({
    active: Boolean(game?.title),
    title: game?.title ? `${game.title} — Play` : null,
    faviconUrl: game ? resolveGameTabIcon(game, settings) : null,
  });

  useEffect(() => {
    const preset = resolveVisualPreset(game?.visual_preset, settings.site_visual_preset);
    applyVisualPresetToDocument(preset);
    return () => {
      delete document.documentElement.dataset.visualPreset;
    };
  }, [game?.visual_preset, settings.site_visual_preset]);

  useEffect(() => {
    if (game?.immersive_layout) {
      document.documentElement.dataset.immersiveLayout = 'on';
    } else {
      delete document.documentElement.dataset.immersiveLayout;
    }
    return () => {
      delete document.documentElement.dataset.immersiveLayout;
    };
  }, [game?.immersive_layout]);

  useEffect(() => {
    if (!game?.slug || !game.isPlayable) return;
    void trackGamePlay(game.slug);
  }, [game?.slug, game?.isPlayable]);

  if (game === undefined) {
    return (
      <SiteChrome>
        <div className="empty-state">Loading…</div>
      </SiteChrome>
    );
  }

  if (!game) {
    return (
      <SiteChrome>
        <div className="empty-state">{loadError ?? 'Game not found.'}</div>
        <p style={{ textAlign: 'center' }}>
          <Link to="/">← Back</Link>
        </p>
      </SiteChrome>
    );
  }

  if (game.published === false && !isAdmin) {
    return (
      <SiteChrome>
        <div
          className="admin-panel"
          style={{ maxWidth: 520, margin: '24px auto', textAlign: 'center', borderColor: 'rgba(115, 248, 255, 0.45)' }}
        >
          <h2 style={{ marginTop: 0, color: 'var(--accent)' }}>This game isn’t live yet</h2>
          <p className="admin-muted" style={{ margin: 0, lineHeight: 1.6 }}>
            We’re polishing it up — check back soon. <Link to="/">Back to hub</Link>.
          </p>
        </div>
      </SiteChrome>
    );
  }

  if (!game.isPlayable) {
    return (
      <SiteChrome navExtra={<Link to={`/game/${game.slug}`}>← Details</Link>}>
        <RouteScopedCss id={`play-${game.slug}`} css={game.custom_mood_css} />
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
      immersive={game.immersive_layout}
      navExtra={
        <>
          <Link to={`/game/${game.slug}`}>Details</Link>
          <Link to="/">Hub</Link>
        </>
      }
    >
      <RouteScopedCss id={`play-${game.slug}`} css={game.custom_mood_css} />
      <GameEmbedSection game={game} />
    </SiteChrome>
  );
}

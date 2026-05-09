import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { GameEmbedSection } from '../components/GameEmbedSection';
import { GamePurchaseBlock } from '../components/GamePurchaseBlock';
import { PageSectionsView } from '../components/PageSectionsView';
import { RouteScopedCss } from '../components/RouteScopedCss';
import { SiteChrome } from '../components/SiteChrome';
import { fetchGameViewBySlug } from '../lib/cmsData';
import { formatGamePriceLabel, gameHasGumroadUrl } from '../lib/gamePricing';
import { normalizeVisualPresetInput } from '../lib/visualPresets';
import { verifyGamePlayability } from '../lib/verifyGamePlayability';
import type { GameView } from '../types';

export function GamePage() {
  const { slug } = useParams<{ slug: string }>();
  const [game, setGame] = useState<GameView | null | undefined>(undefined);
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    if (!slug?.trim()) {
      setGame(null);
      setLoadError('Missing game slug in URL.');
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
        setLoadError('Game not found, or it is a draft (not on hub / vault).');
        return;
      }
      const [verified] = await verifyGamePlayability([row]);
      if (!cancelled) {
        setGame(verified ?? row);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [slug]);

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
          <Link to="/">← Back to hub</Link>
        </p>
      </SiteChrome>
    );
  }

  const hasBlocks = game.sections.length > 0;
  const priceText = formatGamePriceLabel(game);
  const cssId = `game-${game.slug}`;

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>} immersive={game.immersive_layout}>
      <RouteScopedCss id={cssId} css={game.custom_mood_css} />
      <GameEmbedSection game={game} showPlayingLabel={false} />

      <article className="admin-panel page-article game-detail-article">
        <h1 className="header-title" style={{ fontSize: '2rem', textAlign: 'left', marginBottom: 8 }}>
          {game.title}
        </h1>
        <p className="admin-muted" style={{ marginBottom: 24 }}>
          {game.type.toUpperCase()} · {game.slug} · {priceText}
          {game.in_vault ? ' · Vault library' : ''}
        </p>

        {!game.isPlayable ? (
          <div className="admin-panel danger-zone" style={{ marginBottom: 24 }}>
            <p className="admin-muted" style={{ margin: 0, lineHeight: 1.55 }}>
              This title does not have a working play URL yet (nothing found at{' '}
              <code>{game.launchPath}</code>). Use Admin → Games to add a hosted ZIP, external URL, or a build under{' '}
              <code>games/&lt;folder&gt;/</code> in the repo.
            </p>
          </div>
        ) : null}

        {hasBlocks ? (
          <PageSectionsView sections={game.sections} />
        ) : (
          <>
            {game.thumbnail ? (
              <div
                className={gameHasGumroadUrl(game) ? 'game-detail-cover game-detail-cover--gumroad' : 'game-detail-cover'}
                style={{ marginBottom: 16 }}
              >
                <img
                  src={game.thumbnail}
                  alt=""
                  style={{
                    width: '100%',
                    maxHeight: 360,
                    objectFit: 'cover',
                    borderRadius: 8,
                    display: 'block',
                  }}
                />
                {gameHasGumroadUrl(game) ? (
                  <span
                    className="game-thumbnail__gumroad-star game-thumbnail__gumroad-star--detail"
                    title="Available on Gumroad"
                    role="img"
                    aria-label="Gumroad"
                  >
                    ★
                  </span>
                ) : null}
              </div>
            ) : null}
            {game.preview_video ? (
              <video
                src={game.preview_video}
                controls
                playsInline
                style={{
                  width: '100%',
                  maxHeight: 420,
                  borderRadius: 8,
                  marginBottom: 16,
                  background: '#070b12',
                }}
              />
            ) : null}
            <div className="prose" style={{ marginBottom: 20, whiteSpace: 'pre-wrap' }}>
              {game.details || game.description}
            </div>
          </>
        )}

        <div className="game-actions" style={{ maxWidth: 480, marginTop: 24, flexWrap: 'wrap' }}>
          <Link to={`/play/${game.slug}`} className="btn-download" style={{ textAlign: 'center' }}>
            Full-screen player page
          </Link>
          {game.external_url ? (
            <a className="btn-download" href={game.external_url} target="_blank" rel="noreferrer">
              External link
            </a>
          ) : null}
          <GamePurchaseBlock game={game} />
        </div>
      </article>
    </SiteChrome>
  );
}

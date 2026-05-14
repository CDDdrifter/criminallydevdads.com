import { Fragment, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { GameEmbedSection } from '../components/GameEmbedSection';
import { GamePurchaseBlock } from '../components/GamePurchaseBlock';
import { PageSectionsView } from '../components/PageSectionsView';
import { RouteScopedCss } from '../components/RouteScopedCss';
import { ShareStrip } from '../components/ShareStrip';
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
  const [screenshotLightbox, setScreenshotLightbox] = useState<number | null>(null);

  useEffect(() => {
    if (!slug?.trim()) {
      setGame(null);
      setLoadError('Missing game slug in URL.');
      setScreenshotLightbox(null);
      return;
    }
    let cancelled = false;
    setGame(undefined);
    setLoadError(null);
    setScreenshotLightbox(null);
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

  useEffect(() => {
    if (screenshotLightbox === null) {
      return;
    }
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setScreenshotLightbox(null);
      }
      if (!game || game.screenshots.length <= 1) {
        return;
      }
      if (e.key === 'ArrowLeft') {
        e.preventDefault();
        setScreenshotLightbox((i) =>
          i === null ? null : (i - 1 + game.screenshots.length) % game.screenshots.length,
        );
      }
      if (e.key === 'ArrowRight') {
        e.preventDefault();
        setScreenshotLightbox((i) => (i === null ? null : (i + 1) % game.screenshots.length));
      }
    };
    window.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener('keydown', onKey);
    };
  }, [screenshotLightbox, game]);

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
        <p className="admin-muted" style={{ marginBottom: 12 }}>
          {game.type.toUpperCase()} · {game.slug} · {priceText}
          {game.in_vault ? ' · Vault library' : ''}
          {game.release_date ? ` · ${game.release_date}` : ''}
        </p>

        {/* Tags + platforms chip rows — only render when admin filled them in. */}
        {(game.tags.length > 0 || game.platforms.length > 0) ? (
          <div className="admin-row" style={{ flexWrap: 'wrap', gap: 6, marginBottom: 16 }}>
            {game.platforms.map((p) => (
              <span key={p} className="game-platform">{p}</span>
            ))}
            {game.tags.map((t) => (
              <span key={t} className="page-section-tag is-accent">{t}</span>
            ))}
          </div>
        ) : null}

        <ShareStrip title={game.title} surface="game" />

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

        {/* ===== Per-game enrichment panels (migration 018) =================
            Each panel only renders if the admin filled in that array, so a
            stub-imported game shows nothing here at all. */}
        {game.screenshots.length > 0 ? (
          <section style={{ marginTop: 24 }}>
            <h3 className="page-section-title" style={{ fontSize: '0.85rem', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
              Screenshots
            </h3>
            <p className="admin-muted" style={{ fontSize: '0.78rem', margin: '0 0 10px', lineHeight: 1.45 }}>
              Click an image to view large. Use ← → while open. Ctrl+click (or middle-click) still opens the image URL in a new tab.
            </p>
            <div
              className="page-section-gallery"
              style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 10 }}
            >
              {game.screenshots.map((src, i) => (
                <a
                  key={i}
                  href={src}
                  target="_blank"
                  rel="noreferrer"
                  className="page-section-gallery-cell game-screenshot-thumb"
                  onClick={(e) => {
                    if (!e.ctrlKey && !e.metaKey && !e.shiftKey && e.button === 0) {
                      e.preventDefault();
                      setScreenshotLightbox(i);
                    }
                  }}
                >
                  <img src={src} alt={`${game.title} screenshot ${i + 1}`} loading="lazy" />
                </a>
              ))}
            </div>
          </section>
        ) : null}

        {(game.features.length > 0 ||
          game.controls.length > 0 ||
          game.system_requirements.length > 0 ||
          game.credits.length > 0) ? (
          <div className="game-meta-grid">
            {game.features.length > 0 ? (
              <section className="game-meta-panel">
                <h3>Key features</h3>
                <ul className="game-feature-list">
                  {game.features.map((f, i) => <li key={i}>{f}</li>)}
                </ul>
              </section>
            ) : null}
            {game.controls.length > 0 ? (
              <section className="game-meta-panel">
                <h3>Controls</h3>
                <div className="game-controls-table">
                  {game.controls.map((c) => (
                    <Fragment key={c.id}>
                      <span className="game-controls-key">{c.key}</span>
                      <span>{c.desc}</span>
                    </Fragment>
                  ))}
                </div>
              </section>
            ) : null}
            {game.system_requirements.length > 0 ? (
              <section className="game-meta-panel">
                <h3>System requirements</h3>
                <ul className="game-feature-list">
                  {game.system_requirements.map((r, i) => <li key={i}>{r}</li>)}
                </ul>
              </section>
            ) : null}
            {game.credits.length > 0 ? (
              <section className="game-meta-panel">
                <h3>Credits</h3>
                <div className="game-controls-table">
                  {game.credits.map((c) => (
                    <Fragment key={c.id}>
                      <span className="admin-muted" style={{ fontSize: '0.82rem' }}>{c.role}</span>
                      <span>
                        {c.href ? (
                          <a href={c.href} target="_blank" rel="noreferrer">{c.name}</a>
                        ) : (
                          c.name
                        )}
                      </span>
                    </Fragment>
                  ))}
                </div>
              </section>
            ) : null}
          </div>
        ) : null}

        {game.changelog.length > 0 ? (
          <section style={{ marginTop: 16 }}>
            <h3 className="page-section-title" style={{ fontSize: '0.85rem', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
              Changelog
            </h3>
            <div className="admin-panel">
              {game.changelog.map((c) => (
                <div key={c.id} className="game-changelog-row">
                  <div className="admin-row" style={{ gap: 10, alignItems: 'baseline' }}>
                    <span className="game-changelog-version">v{c.version}</span>
                    {c.date ? <span className="game-changelog-date">{c.date}</span> : null}
                  </div>
                  <div className="page-section-pre" style={{ marginTop: 4 }}>{c.notes}</div>
                </div>
              ))}
            </div>
          </section>
        ) : null}

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

      {screenshotLightbox !== null && game.screenshots[screenshotLightbox] ? (
        <div
          className="game-screenshot-lightbox"
          role="dialog"
          aria-modal="true"
          aria-label={`Screenshot ${screenshotLightbox + 1} of ${game.screenshots.length}`}
          onClick={() => setScreenshotLightbox(null)}
        >
          <div className="game-screenshot-lightbox__inner" onClick={(e) => e.stopPropagation()}>
            <button
              type="button"
              className="game-screenshot-lightbox__close"
              aria-label="Close"
              onClick={() => setScreenshotLightbox(null)}
            >
              ×
            </button>
            {game.screenshots.length > 1 ? (
              <>
                <button
                  type="button"
                  className="game-screenshot-lightbox__nav game-screenshot-lightbox__nav--prev"
                  aria-label="Previous screenshot"
                  onClick={() =>
                    setScreenshotLightbox(
                      (i) =>
                        i === null
                          ? null
                          : (i - 1 + game.screenshots.length) % game.screenshots.length,
                    )
                  }
                >
                  ‹
                </button>
                <button
                  type="button"
                  className="game-screenshot-lightbox__nav game-screenshot-lightbox__nav--next"
                  aria-label="Next screenshot"
                  onClick={() =>
                    setScreenshotLightbox((i) => (i === null ? null : (i + 1) % game.screenshots.length))
                  }
                >
                  ›
                </button>
              </>
            ) : null}
            <img
              src={game.screenshots[screenshotLightbox]}
              alt={`${game.title} screenshot ${screenshotLightbox + 1}`}
              className="game-screenshot-lightbox__img"
            />
            <div className="game-screenshot-lightbox__footer admin-muted">
              {screenshotLightbox + 1} / {game.screenshots.length} · Escape to close · ← →
            </div>
          </div>
        </div>
      ) : null}
    </SiteChrome>
  );
}

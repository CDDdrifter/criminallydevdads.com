import { useEffect } from 'react';
import { Link, useParams } from 'react-router-dom';
import { GameEmbedSection } from '../components/GameEmbedSection';
import { PageSectionsView } from '../components/PageSectionsView';
import { SiteChrome } from '../components/SiteChrome';
import { useGames } from '../hooks/useGames';

export function GamePage() {
  const { slug } = useParams<{ slug: string }>();
  const { games, loading, error } = useGames();
  const game = games.find((g) => g.slug === slug);

  useEffect(() => {
    const preset = game?.visual_preset?.trim();
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
          <Link to="/">← Back to hub</Link>
        </p>
      </SiteChrome>
    );
  }

  const hasBlocks = game.sections.length > 0;

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <GameEmbedSection game={game} showPlayingLabel={false} />

      <article className="admin-panel page-article game-detail-article">
        <h1 className="header-title" style={{ fontSize: '2rem', textAlign: 'left', marginBottom: 8 }}>
          {game.title}
        </h1>
        <p className="admin-muted" style={{ marginBottom: 24 }}>
          {game.type.toUpperCase()} · {game.slug}
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
              <img
                src={game.thumbnail}
                alt=""
                style={{
                  width: '100%',
                  maxHeight: 360,
                  objectFit: 'cover',
                  borderRadius: 8,
                  marginBottom: 16,
                }}
              />
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
        </div>
      </article>
    </SiteChrome>
  );
}

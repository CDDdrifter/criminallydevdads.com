import type { GameView } from '../types';
import { useGameEmbed } from '../hooks/useGameEmbed';
import { GamePlayerEmbed } from './GamePlayerEmbed';

type Props = {
  game: GameView;
  /** When false, omit the “Playing: … / open in tab” helper row (game detail page). */
  showPlayingLabel?: boolean;
};

export function GameEmbedSection({ game, showPlayingLabel = true }: Props) {
  const { probeState, iframeSrc, probeError, compatibilityNote, resolvedUrl } = useGameEmbed(game);

  if (!game.isPlayable) {
    return null;
  }

  return (
    <>
      {showPlayingLabel ? (
        <div className="admin-muted" style={{ marginBottom: 12 }}>
          Playing: <strong>{game.title}</strong>
          {' · '}
          <a href={resolvedUrl} target="_blank" rel="noreferrer">
            Open play URL in new tab
          </a>
        </div>
      ) : null}

      {compatibilityNote ? (
        <p className="admin-muted" style={{ marginBottom: 12, lineHeight: 1.5, fontSize: '0.88rem' }}>
          {compatibilityNote}
        </p>
      ) : null}

      {probeState === 'checking' ? <div className="empty-state">Checking game link…</div> : null}

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
    </>
  );
}

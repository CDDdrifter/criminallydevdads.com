import { forwardRef } from 'react';
import type { GameView } from '../types';
import { useGameEmbed } from '../hooks/useGameEmbed';
import { GamePlayerEmbed, type GamePlayerHandle } from './GamePlayerEmbed';
import { isLocalRepoGamePath } from '../lib/localGamePath';

type Props = {
  game: GameView;
  /** When false, omit the “Playing: …” helper row (game detail page). */
  showPlayingLabel?: boolean;
};

export const GameEmbedSection = forwardRef<GamePlayerHandle, Props>(function GameEmbedSection(
  { game, showPlayingLabel = true },
  ref,
) {
  const { probeState, iframeSrc, probeError, resolvedUrl } = useGameEmbed(game);
  const canInstallOffline = isLocalRepoGamePath(game.launchPath);

  if (!game.isPlayable) {
    return null;
  }

  return (
    <>
      {showPlayingLabel ? (
        <div className="admin-muted" style={{ marginBottom: 12 }}>
          Playing: <strong>{game.title}</strong>
        </div>
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
        <div className="game-embed-wrap" id="game-player">
          <GamePlayerEmbed
            ref={ref}
            title={game.title}
            src={iframeSrc}
            installHref={canInstallOffline ? resolvedUrl : undefined}
          />
        </div>
      ) : null}

      {canInstallOffline ? (
        <div className="game-offline-install">
          <p>
            <strong>iPhone / no signal:</strong> tap <em>Save to iPhone</em>. Wait until that page says the
            game is saved. Then tap Share → Add to Home Screen. After that it opens with no cell service.
            Use Safari. This does not restart the game you are already playing.
          </p>
        </div>
      ) : null}
    </>
  );
});

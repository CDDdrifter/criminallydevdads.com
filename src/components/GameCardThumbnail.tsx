import { useCallback, useRef, useState } from 'react';
import type { GameView } from '../types';
import { gameHasGumroadUrl } from '../lib/gamePricing';
import { useSiteSettings } from '../hooks/useSiteSettings';

type Props = {
  game: GameView;
  /** Decorative cover — use game title for screen readers. */
  imageAlt?: string;
};

/**
 * Hub / vault card thumbnail with optional ★ when a Gumroad listing URL is set.
 *
 * When the Behavior studio enables `homepage_autoplay_previews` and the game
 * has a `preview_video_url`, the thumbnail swaps to a muted-loop video on
 * hover (and on focus, for keyboard users) and back to the still on leave.
 */
export function GameCardThumbnail({ game, imageAlt }: Props) {
  const { settings } = useSiteSettings();
  const showGumroadStar = gameHasGumroadUrl(game);
  const alt = imageAlt ?? game.title;
  const previewUrl = (game.preview_video ?? '').trim();
  const autoplay = settings.behavior?.homepage_autoplay_previews && Boolean(previewUrl);
  const [showVideo, setShowVideo] = useState(false);
  const vidRef = useRef<HTMLVideoElement | null>(null);
  const play = useCallback(() => {
    if (!autoplay) return;
    setShowVideo(true);
    queueMicrotask(() => {
      const v = vidRef.current;
      if (!v) return;
      try {
        v.currentTime = 0;
        v.play().catch(() => undefined);
      } catch {
        /* mid-mount race — ignore. */
      }
    });
  }, [autoplay]);
  const stop = useCallback(() => {
    setShowVideo(false);
    const v = vidRef.current;
    if (v) {
      try {
        v.pause();
      } catch {
        /* nothing — element will be removed anyway. */
      }
    }
  }, []);
  return (
    <div
      className={`game-thumbnail${showGumroadStar ? ' game-thumbnail--badged' : ''}`}
      onMouseEnter={play}
      onMouseLeave={stop}
      onFocus={play}
      onBlur={stop}
    >
      {showVideo && autoplay ? (
        <video
          ref={vidRef}
          src={previewUrl}
          muted
          loop
          playsInline
          preload="metadata"
          aria-label={`${game.title} preview`}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        />
      ) : game.thumbnail ? (
        <img src={game.thumbnail} alt={alt} />
      ) : (
        '🎮'
      )}
      {showGumroadStar ? (
        <span className="game-thumbnail__gumroad-star" title="Available on Gumroad" role="img" aria-label="Gumroad">
          ★
        </span>
      ) : null}
    </div>
  );
}

import type { GameView } from '../types';
import { gameHasGumroadUrl } from '../lib/gamePricing';

type Props = {
  game: GameView;
  /** Decorative cover — use game title for screen readers. */
  imageAlt?: string;
};

/**
 * Hub / vault card thumbnail with optional ★ when a Gumroad listing URL is set.
 */
export function GameCardThumbnail({ game, imageAlt }: Props) {
  const showGumroadStar = gameHasGumroadUrl(game);
  const alt = imageAlt ?? game.title;
  return (
    <div className={`game-thumbnail${showGumroadStar ? ' game-thumbnail--badged' : ''}`}>
      {game.thumbnail ? <img src={game.thumbnail} alt={alt} /> : '🎮'}
      {showGumroadStar ? (
        <span className="game-thumbnail__gumroad-star" title="Available on Gumroad" role="img" aria-label="Gumroad">
          ★
        </span>
      ) : null}
    </div>
  );
}

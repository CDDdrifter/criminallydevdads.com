/**
 * Compact platform + tag row for catalog cards (hub, vault, page game grids).
 */
export type GameCardMetaChipsProps = {
  tags?: string[] | null;
  platforms?: string[] | null;
  /** Total chips cap — platforms are listed first (up to 2), then tags. */
  max?: number;
};

export function GameCardMetaChips({ tags, platforms, max = 6 }: GameCardMetaChipsProps) {
  const plat = (platforms ?? []).filter(Boolean);
  const tagList = (tags ?? []).filter(Boolean);
  if (!plat.length && !tagList.length) {
    return null;
  }

  const chips: { key: string; label: string; kind: 'platform' | 'tag' }[] = [];
  for (const p of plat.slice(0, 2)) {
    chips.push({ key: `p-${p}`, label: p, kind: 'platform' });
  }
  const room = Math.max(0, max - chips.length);
  for (const t of tagList.slice(0, room)) {
    chips.push({ key: `t-${t}`, label: t, kind: 'tag' });
  }

  return (
    <div className="game-card-chips" aria-label="Platforms and tags">
      {chips.map((c) =>
        c.kind === 'platform' ? (
          <span key={c.key} className="game-platform game-platform--chip">
            {c.label}
          </span>
        ) : (
          <span key={c.key} className="page-section-tag is-accent game-card-chips__tag">
            {c.label}
          </span>
        ),
      )}
    </div>
  );
}

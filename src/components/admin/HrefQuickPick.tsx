import { useMemo } from 'react';

export type HrefPickOption = { value: string; label: string };

type Props = {
  pages: { slug: string; title: string }[];
  games: { slug: string; title: string }[];
  onPick: (href: string) => void;
  disabled?: boolean;
};

const CORE_LINKS: HrefPickOption[] = [
  { value: '/', label: 'Home (hub)' },
  { value: '/devlog', label: 'Dev log list' },
  { value: '/purchase/terms', label: 'Purchase terms' },
  { value: '/admin', label: 'Admin' },
];

export function HrefQuickPick({ pages, games, onPick, disabled }: Props) {
  const pageOpts = useMemo(
    () =>
      [...pages]
        .sort((a, b) => a.title.localeCompare(b.title))
        .map((p) => ({ value: `/p/${p.slug}`, label: `Page: ${p.title || p.slug}` })),
    [pages],
  );
  const gameOpts = useMemo(
    () =>
      [...games]
        .sort((a, b) => a.title.localeCompare(b.title))
        .map((g) => ({ value: `/game/${g.slug}`, label: `Game: ${g.title || g.slug}` })),
    [games],
  );

  return (
    <div className="admin-field" style={{ marginTop: 6 }}>
      <label className="admin-muted" style={{ fontSize: '0.8rem', display: 'block', marginBottom: 4 }}>
        Quick link (inserts path below)
      </label>
      <select
        disabled={disabled}
        defaultValue=""
        onChange={(e) => {
          const v = e.target.value;
          if (v) {
            onPick(v);
          }
          e.target.value = '';
        }}
        style={{ maxWidth: '100%', width: 360 }}
      >
        <option value="">Choose destination…</option>
        <optgroup label="Site">
          {CORE_LINKS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </optgroup>
        {pageOpts.length > 0 ? (
          <optgroup label="CMS pages">
            {pageOpts.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </optgroup>
        ) : null}
        {gameOpts.length > 0 ? (
          <optgroup label="Games">
            {gameOpts.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </optgroup>
        ) : null}
      </select>
    </div>
  );
}

import { githubCmsConfigured } from '../../lib/githubCms';

type Props = {
  onOpenTab: (tab: string) => void;
};

export function AdminPublishGuide({ onOpenTab }: Props) {
  const tokenOk = githubCmsConfigured();

  return (
    <div className="admin-panel" style={{ marginBottom: 20, borderColor: 'rgba(115, 248, 255, 0.45)' }}>
      <h2 style={{ fontSize: '1rem', margin: '0 0 8px', color: 'var(--accent)' }}>Publish it yourself</h2>
      <p className="admin-muted" style={{ marginTop: 0, lineHeight: 1.55, fontSize: '0.88rem' }}>
        Game files live in this GitHub repo. After a save or push, wait for{' '}
        <a href="https://github.com/CDDdrifter/criminallydevdads.com/actions" target="_blank" rel="noreferrer">
          Deploy to GitHub Pages
        </a>{' '}
        (green check), then hard-refresh. Written guide:{' '}
        <a
          href="https://github.com/CDDdrifter/criminallydevdads.com/blob/main/docs/HOW_TO_UPDATE.md"
          target="_blank"
          rel="noreferrer"
        >
          docs/HOW_TO_UPDATE.md
        </a>
        .
      </p>
      <ol className="admin-muted" style={{ margin: '0 0 12px', paddingLeft: 20, lineHeight: 1.6, fontSize: '0.88rem' }}>
        <li>
          <strong>Once:</strong> System tab → GitHub Personal Access Token with <code>repo</code> scope, branch{' '}
          <code>main</code>. Status:{' '}
          {tokenOk ? (
            <span style={{ color: '#3ecf8e' }}>token saved in this browser</span>
          ) : (
            <span style={{ color: '#ffbf5f' }}>no token yet — ZIP uploads will fail</span>
          )}
        </li>
        <li>
          <strong>New or updated game:</strong> Games tab → title → upload the Web export <code>.zip</code> (or paste an
          external play URL) → Save.
        </li>
        <li>
          <strong>New page:</strong> Pages tab → slug (public URL <code>/p/your-slug</code>) → Save. Optional: Show in
          top nav.
        </li>
        <li>
          <strong>Or on GitHub:</strong> edit <code>games.json</code> / drop files in <code>games/&lt;slug&gt;/</code> →
          commit to <code>main</code>.
        </li>
      </ol>
      <div className="admin-row" style={{ gap: 8, flexWrap: 'wrap' }}>
        <button type="button" onClick={() => onOpenTab('system')}>
          System → GitHub token
        </button>
        <button type="button" onClick={() => onOpenTab('games')}>
          Games → add / update
        </button>
        <button type="button" onClick={() => onOpenTab('pages')}>
          Pages → new page
        </button>
      </div>
    </div>
  );
}

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';
import { fetchSitePages } from '../lib/cmsData';
import type { SitePage } from '../types';

/**
 * Public index of HTML-app pages (`page_mode === 'html_app'` with
 * `show_on_apps_hub`). Each card links to `/#/p/{slug}`.
 */
export function AppsHubPage() {
  const [apps, setApps] = useState<SitePage[] | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const pages = await fetchSitePages();
      if (cancelled) return;
      const list = pages.filter((p) => p.page_mode === 'html_app' && p.show_on_apps_hub !== false);
      setApps(list);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <header style={{ textAlign: 'center', marginBottom: 28 }}>
        <h1 className="header-title">Apps & tools</h1>
        <p className="admin-muted" style={{ maxWidth: 560, margin: '0 auto', lineHeight: 1.55 }}>
          Stand-alone HTML exports you host as CMS pages. Add more under <strong>Admin → Pages</strong> — set page
          type to <strong>HTML app</strong> and toggle <strong>Show on Apps hub</strong>.
        </p>
      </header>

      {apps === null ? (
        <div className="empty-state">Loading…</div>
      ) : apps.length === 0 ? (
        <div className="empty-state">
          <p>No HTML apps listed yet.</p>
          <p className="admin-muted" style={{ marginTop: 12 }}>
            Create a page, choose <strong>HTML app</strong>, paste your file, save, then enable <strong>Show on Apps hub</strong>.
          </p>
        </div>
      ) : (
        <div className="apps-hub-grid">
          {apps.map((p) => (
            <Link key={p.slug} to={`/p/${p.slug}`} className="apps-hub-card admin-panel">
              <div className="apps-hub-card-title">{p.title}</div>
              <div className="apps-hub-card-slug admin-muted">/p/{p.slug}</div>
              {p.html_app_summary?.trim() ? (
                <p className="apps-hub-card-desc">{p.html_app_summary}</p>
              ) : (
                <p className="apps-hub-card-desc admin-muted">Open →</p>
              )}
            </Link>
          ))}
        </div>
      )}
    </SiteChrome>
  );
}

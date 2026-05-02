import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { PageSectionsView } from '../components/PageSectionsView';
import { SiteChrome } from '../components/SiteChrome';
import { fetchPageBySlug } from '../lib/cmsData';
import type { SitePage } from '../types';

export function StaticPage() {
  const { slug } = useParams<{ slug: string }>();
  const [page, setPage] = useState<SitePage | null | undefined>(undefined);

  useEffect(() => {
    let cancelled = false;
    if (!slug) {
      setPage(null);
      return;
    }
    fetchPageBySlug(slug).then((p) => {
      if (!cancelled) {
        setPage(p);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [slug]);

  if (page === undefined) {
    return (
      <SiteChrome>
        <div className="empty-state">Loading…</div>
      </SiteChrome>
    );
  }

  if (!page) {
    return (
      <SiteChrome>
        <div className="empty-state">Page not found.</div>
        <p style={{ textAlign: 'center' }}>
          <Link to="/">← Hub</Link>
        </p>
      </SiteChrome>
    );
  }

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <article className="admin-panel page-article">
        <h1 className="header-title" style={{ fontSize: '2.2rem', textAlign: 'left' }}>
          {page.title}
        </h1>
        {page.sections.length > 0 ? (
          <div style={{ marginTop: 24 }}>
            <PageSectionsView sections={page.sections} />
          </div>
        ) : (
          <div className="prose" style={{ marginTop: 24, whiteSpace: 'pre-wrap' }}>
            {page.body}
          </div>
        )}
      </article>
    </SiteChrome>
  );
}

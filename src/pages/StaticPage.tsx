import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { PageSectionsView } from '../components/PageSectionsView';
import { RouteScopedCss } from '../components/RouteScopedCss';
import { ShareStrip } from '../components/ShareStrip';
import { SiteChrome } from '../components/SiteChrome';
import { fetchPageBySlug } from '../lib/cmsData';
import { normalizeVisualPresetInput } from '../lib/visualPresets';
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
    setPage(undefined);
    fetchPageBySlug(slug).then((p) => {
      if (!cancelled) {
        setPage(p);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [slug]);

  useEffect(() => {
    if (page === undefined) {
      return;
    }
    if (!page) {
      delete document.documentElement.dataset.visualPreset;
      return;
    }
    const preset = normalizeVisualPresetInput(page.visual_preset);
    if (preset) {
      document.documentElement.dataset.visualPreset = preset;
    } else {
      delete document.documentElement.dataset.visualPreset;
    }
    return () => {
      delete document.documentElement.dataset.visualPreset;
    };
  }, [page]);

  useEffect(() => {
    if (page === undefined || !page) {
      delete document.documentElement.dataset.immersiveLayout;
      return;
    }
    if (page.immersive_layout) {
      document.documentElement.dataset.immersiveLayout = 'on';
    } else {
      delete document.documentElement.dataset.immersiveLayout;
    }
    return () => {
      delete document.documentElement.dataset.immersiveLayout;
    };
  }, [page]);

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
    <SiteChrome navExtra={<Link to="/">← Hub</Link>} immersive={Boolean(page.immersive_layout)}>
      <RouteScopedCss id={`page-${page.slug}`} css={page.custom_mood_css ?? ''} />
      <article className="admin-panel page-article">
        <h1 className="header-title" style={{ fontSize: '2.2rem', textAlign: 'left' }}>
          {page.title}
        </h1>
        <ShareStrip title={page.title} surface="page" />
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

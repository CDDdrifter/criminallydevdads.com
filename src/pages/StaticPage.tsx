import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { CommentSection } from '../components/CommentSection';
import { HtmlAppEmbed } from '../components/HtmlAppEmbed';
import { PageSectionsView } from '../components/PageSectionsView';
import { RouteScopedCss } from '../components/RouteScopedCss';
import { ShareStrip } from '../components/ShareStrip';
import { SiteChrome } from '../components/SiteChrome';
import { fetchPageBySlug } from '../lib/cmsData';
import { normalizeVisualPresetInput } from '../lib/visualPresets';
import { trackAppOpen } from '../lib/analytics';
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

  /** Unlisted pages: ask crawlers not to index (does not hide the URL). */
  useEffect(() => {
    const id = 'cdd-static-page-noindex';
    if (!page?.unlisted) {
      return;
    }
    if (!document.getElementById(id)) {
      const meta = document.createElement('meta');
      meta.id = id;
      meta.name = 'robots';
      meta.content = 'noindex, nofollow';
      document.head.appendChild(meta);
    }
    return () => {
      document.getElementById(id)?.remove();
    };
  }, [page?.unlisted, slug]);

  useEffect(() => {
    if (!slug?.trim() || page === undefined || !page || page.page_mode !== 'html_app') {
      return;
    }
    void trackAppOpen(slug.trim());
  }, [page, slug]);

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

  const isHtmlApp = page.page_mode === 'html_app';

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>} immersive={Boolean(page.immersive_layout)}>
      <RouteScopedCss id={`page-${page.slug}`} css={page.custom_mood_css ?? ''} />
      <article className={`admin-panel page-article${isHtmlApp ? ' page-article--html-app' : ''}`}>
        <div className="page-article-head">
          <h1 className="header-title" style={{ fontSize: '2.2rem', textAlign: 'left' }}>
            {page.title}
          </h1>
          {page.unlisted ? (
            <span className="admin-muted" style={{ fontSize: '0.75rem' }}>
              Unlisted · share URL only
            </span>
          ) : null}
        </div>

        {isHtmlApp ? (
          <div style={{ marginTop: 16 }}>
            <p className="admin-muted" style={{ fontSize: '0.82rem', marginBottom: 12, lineHeight: 1.5 }}>
              Standalone HTML runs in a sandboxed frame (Gemini / single-file exports). If something breaks, enable{' '}
              <strong>Compat sandbox</strong> on this page in Admin — only for code you trust. You can also add the same
              app as a <strong>Mini app (HTML)</strong> block on a regular page, or list it on{' '}
              <Link to="/apps">/apps</Link> when <strong>Show on Apps hub</strong> is on.
            </p>
            <HtmlAppEmbed page={page} />
          </div>
        ) : (
          <>
            <ShareStrip title={page.title} surface="page" />
            {page.sections.length > 0 ? (
              <div style={{ marginTop: 24 }}>
                <PageSectionsView
                  sections={page.sections}
                  commentContext={{ target_type: 'page', target_key: page.slug }}
                />
              </div>
            ) : (
              <div className="prose" style={{ marginTop: 24, whiteSpace: 'pre-wrap' }}>
                {page.body}
              </div>
            )}
          </>
        )}

        {!isHtmlApp && slug ? (
          <CommentSection targetType="page" targetKey={slug} />
        ) : null}
      </article>
    </SiteChrome>
  );
}

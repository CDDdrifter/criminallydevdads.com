import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { CommentSection } from '../components/CommentSection';
import { HtmlAppEmbed } from '../components/HtmlAppEmbed';
import { PageSectionsView } from '../components/PageSectionsView';
import { RouteScopedCss } from '../components/RouteScopedCss';
import { ShareStrip } from '../components/ShareStrip';
import { SiteChrome } from '../components/SiteChrome';
import { useAuth } from '../context/AuthContext';
import { fetchPageBySlug } from '../lib/cmsData';
import { useRouteBranding } from '../hooks/useRouteBranding';
import { useRouteFxSync } from '../hooks/useRouteFxSync';
import { useSiteSettings } from '../hooks/useSiteSettings';
import { applyVisualPresetToDocument, resolveVisualPreset } from '../lib/routeFx';
import { trackAppOpen } from '../lib/analytics';
import type { SitePage } from '../types';

export function StaticPage() {
  const { slug } = useParams<{ slug: string }>();
  const { settings } = useSiteSettings();
  const { isAdmin } = useAuth();
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
    const preset = resolveVisualPreset(page.visual_preset, settings.site_visual_preset);
    applyVisualPresetToDocument(preset);
    return () => {
      delete document.documentElement.dataset.visualPreset;
    };
  }, [page, settings.site_visual_preset]);

  useRouteFxSync(page?.route_fx);

  useRouteBranding({
    active: Boolean(page?.title),
    title: page?.title ?? null,
    faviconUrl: null,
  });

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

  if (page.published === false && !isAdmin) {
    return (
      <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
        <div className="admin-panel" style={{ maxWidth: 480, margin: '24px auto', textAlign: 'center' }}>
          <p className="admin-muted" style={{ margin: 0, lineHeight: 1.6 }}>
            This page is not published yet. Sign in as a site editor to preview drafts in Admin.
          </p>
        </div>
      </SiteChrome>
    );
  }

  const isHtmlApp = page.page_mode === 'html_app';

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>} immersive={Boolean(page.immersive_layout)}>
      <RouteScopedCss id={`page-${page.slug}`} css={page.custom_mood_css ?? ''} />
      <article className={`admin-panel page-article${isHtmlApp ? ' page-article--html-app' : ''}`}>
        <div className="page-article-head">
          <h1 className="header-title" style={{ fontSize: 'clamp(1.6rem, 4vw, 2.1rem)', textAlign: 'left' }}>
            {page.title}
          </h1>
          {page.published === false ? (
            <span className="admin-muted" style={{ fontSize: '0.75rem', color: 'var(--warning)' }}>
              Draft · admins only
            </span>
          ) : null}
          {page.unlisted ? (
            <span className="admin-muted" style={{ fontSize: '0.75rem' }}>
              Unlisted · share URL only
            </span>
          ) : null}
        </div>

        {isHtmlApp ? (
          <div style={{ marginTop: 16 }}>
            <p className="html-app-notice">
              Paste a full <strong>single-file HTML</strong> export (e.g. from Gemini) in Admin, save, then open this URL.
              Scripts run in a <strong>sandboxed iframe</strong> on our domain. If the app is blank or APIs fail, turn on{' '}
              <strong>Compat sandbox</strong> in Admin (only for HTML you trust). API keys in pasted HTML are visible to
              anyone with the link; use a test key for personal experiments. List on <Link to="/apps">/apps</Link> when{' '}
              <strong>Show on Apps hub</strong> is enabled.
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

        {!isHtmlApp && slug && page.comments_enabled !== false ? (
          <CommentSection targetType="page" targetKey={slug} />
        ) : null}
      </article>
    </SiteChrome>
  );
}

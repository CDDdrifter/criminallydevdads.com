/**
 * PageSectionsView — universal block renderer.
 *
 * Renders every block type from the `PageSection` union. Used by:
 *   - Game detail pages   (`<GamePage>`)
 *   - Custom CMS pages    (`<StaticPage>`)
 *   - The homepage        (`<HomePage>` via `homepage_sections`)
 *
 * Style notes:
 *   - All visual styling lives in `index.css` under `.page-section-*` rules.
 *   - For interactive blocks (accordion, tabs, gallery lightbox) we keep
 *     state locally in tiny subcomponents instead of bubbling up.
 *   - `sandbox_html` blocks import `htmlAppSandbox` from `HtmlAppEmbed` so
 *     pasting Gemini HTML matches full-page app security.
 */
import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { CommentSection } from './CommentSection';
import type { CommentTargetType } from '../lib/communityData';
import { SupportTipButton } from './SupportTipButton';
import type { PageSection } from '../types';
import { useGames } from '../hooks/useGames';
import { useSiteSettings } from '../hooks/useSiteSettings';
import { resolveTipHref } from '../lib/tipLink';
import { GameCardMetaChips } from './GameCardMetaChips';
import { GameCardThumbnail } from './GameCardThumbnail';
import { htmlAppSandbox } from './HtmlAppEmbed';

// ===========================================================================
// Tiny renderers for sub-content used by multiple block types.
// ===========================================================================

function renderCtaButton(
  cta: { label: string; href: string; external?: boolean } | undefined,
  variant: 'primary' | 'secondary' = 'primary',
  tipUrl = '',
) {
  if (!cta || !cta.label.trim()) return null;
  const resolved = resolveTipHref(cta.href, tipUrl);
  const href = resolved?.href ?? cta.href;
  const external = resolved?.external ?? cta.external;
  const className = `page-section-cta page-section-cta--${variant}`;
  if (external) {
    return (
      <a href={href} target="_blank" rel="noreferrer" className={className}>
        {cta.label}
      </a>
    );
  }
  return (
    <Link to={href || '/'} className={className}>
      {cta.label}
    </Link>
  );
}

/** Pretty-print a YT/Twitch/Vimeo URL as a real embed URL. */
function embedSrc(url: string, provider: string): string {
  if (!url) return '';
  const trimmed = url.trim();
  // If the admin already pasted a /embed/ URL, leave it alone.
  if (/\/(embed|player)\//.test(trimmed)) return trimmed;
  if (provider === 'youtube') {
    const m = trimmed.match(/(?:youtu\.be\/|v=)([\w-]{6,})/);
    if (m && m[1]) return `https://www.youtube.com/embed/${m[1]}`;
  }
  if (provider === 'vimeo') {
    const m = trimmed.match(/vimeo\.com\/(\d+)/);
    if (m && m[1]) return `https://player.vimeo.com/video/${m[1]}`;
  }
  if (provider === 'twitch') {
    const m = trimmed.match(/twitch\.tv\/(?:videos\/)?([\w-]+)/);
    if (m && m[1]) {
      const isVideo = /videos\//.test(trimmed);
      return `https://player.twitch.tv/?${isVideo ? 'video=' : 'channel='}${m[1]}&parent=${typeof window !== 'undefined' ? window.location.hostname : 'localhost'}`;
    }
  }
  return trimmed;
}

/**
 * Tiny zero-dep markdown renderer — supports headings, bold, italic, links,
 * inline code, lists, blockquotes, hr, paragraphs. Code fences are also
 * supported. Anything more advanced should use a `code` block directly.
 */
function renderMarkdown(src: string): string {
  // Escape raw HTML so the user can't break out unless they explicitly use an `html` block.
  let html = src
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  // Code fences first so we don't double-process their contents.
  html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (_, lang, body) => {
    return `<pre class="page-section-code"><code data-lang="${lang}">${body}</code></pre>`;
  });
  // Headings
  html = html.replace(/^###### (.*)$/gm, '<h6>$1</h6>');
  html = html.replace(/^##### (.*)$/gm, '<h5>$1</h5>');
  html = html.replace(/^#### (.*)$/gm, '<h4>$1</h4>');
  html = html.replace(/^### (.*)$/gm, '<h3>$1</h3>');
  html = html.replace(/^## (.*)$/gm, '<h2>$1</h2>');
  html = html.replace(/^# (.*)$/gm, '<h1>$1</h1>');
  // Horizontal rule
  html = html.replace(/^---$/gm, '<hr/>');
  // Blockquote
  html = html.replace(/^> ?(.*)$/gm, '<blockquote>$1</blockquote>');
  // Lists — wrap consecutive `-` / `*` lines in <ul>.
  html = html.replace(/(?:^|\n)((?:[-*] .*\n?)+)/g, (_full, block) => {
    const items = block
      .trim()
      .split('\n')
      .map((l: string) => l.replace(/^[-*] /, ''))
      .map((l: string) => `<li>${l}</li>`)
      .join('');
    return `\n<ul>${items}</ul>`;
  });
  // Inline code
  html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
  // Bold + italic
  html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  // Links
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" rel="noreferrer">$1</a>');
  // Paragraphs — wrap stray lines.
  html = html
    .split(/\n{2,}/)
    .map((chunk) =>
      /^<(h\d|ul|ol|blockquote|pre|hr)/.test(chunk.trim())
        ? chunk
        : `<p>${chunk.trim().replace(/\n/g, '<br/>')}</p>`,
    )
    .join('\n');
  return html;
}

// ===========================================================================
// Interactive sub-components for blocks with their own state.
// ===========================================================================

function AccordionRow({ title, body, open: openInitial }: { title: string; body: string; open: boolean }) {
  const [open, setOpen] = useState(openInitial);
  return (
    <details
      className="page-section-accordion-row"
      open={open}
      onToggle={(e) => setOpen((e.target as HTMLDetailsElement).open)}
    >
      <summary className="page-section-accordion-summary">
        <span>{title}</span>
        <span className="page-section-accordion-chevron" aria-hidden>
          {open ? '−' : '+'}
        </span>
      </summary>
      <div className="page-section-accordion-body prose">
        <div className="page-section-pre">{body}</div>
      </div>
    </details>
  );
}

function Tabs({ tabs }: { tabs: { id: string; label: string; sections: PageSection[] }[] }) {
  const initial = tabs[0]?.id ?? '';
  const [active, setActive] = useState(initial);
  if (tabs.length === 0) return null;
  const current = tabs.find((t) => t.id === active) ?? tabs[0];
  if (!current) return null;
  return (
    <div className="page-section-tabs">
      <div role="tablist" className="page-section-tabs-bar">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            role="tab"
            aria-selected={t.id === current.id}
            className={`page-section-tab ${t.id === current.id ? 'is-active' : ''}`}
            onClick={() => setActive(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>
      <div role="tabpanel" className="page-section-tabs-panel">
        <PageSectionsView sections={current.sections} />
      </div>
    </div>
  );
}

function Gallery({
  images,
  columns,
  lightbox,
}: {
  images: { id: string; url: string; alt?: string; caption?: string }[];
  columns: 2 | 3 | 4;
  lightbox: boolean;
}) {
  const [openIdx, setOpenIdx] = useState<number | null>(null);
  const close = () => setOpenIdx(null);
  const current = openIdx !== null ? images[openIdx] : null;
  return (
    <>
      <div
        className="page-section-gallery"
        style={{ gridTemplateColumns: `repeat(${columns}, 1fr)` }}
      >
        {images.map((img, idx) => (
          <button
            key={img.id}
            type="button"
            className="page-section-gallery-cell"
            onClick={() => lightbox && setOpenIdx(idx)}
            disabled={!lightbox}
          >
            <img src={img.url} alt={img.alt ?? ''} loading="lazy" />
            {img.caption ? <span className="page-section-gallery-caption">{img.caption}</span> : null}
          </button>
        ))}
      </div>
      {lightbox && current ? (
        <div
          className="page-section-lightbox"
          role="dialog"
          aria-modal="true"
          onClick={close}
        >
          <button
            type="button"
            className="page-section-lightbox-close"
            onClick={close}
            aria-label="Close gallery"
          >
            ✕
          </button>
          {openIdx !== null && openIdx > 0 ? (
            <button
              type="button"
              className="page-section-lightbox-prev"
              onClick={(e) => {
                e.stopPropagation();
                setOpenIdx((i) => (i !== null ? Math.max(0, i - 1) : 0));
              }}
              aria-label="Previous image"
            >
              ‹
            </button>
          ) : null}
          {openIdx !== null && openIdx < images.length - 1 ? (
            <button
              type="button"
              className="page-section-lightbox-next"
              onClick={(e) => {
                e.stopPropagation();
                setOpenIdx((i) => (i !== null ? Math.min(images.length - 1, i + 1) : 0));
              }}
              aria-label="Next image"
            >
              ›
            </button>
          ) : null}
          <img
            src={current.url}
            alt={current.alt ?? ''}
            onClick={(e) => e.stopPropagation()}
          />
          {current.caption ? (
            <div className="page-section-lightbox-caption">{current.caption}</div>
          ) : null}
        </div>
      ) : null}
    </>
  );
}

function GameGrid({ slugs, columns, title }: { slugs: string[]; columns: 2 | 3 | 4; title?: string }) {
  const { games } = useGames();
  const filtered = useMemo(() => {
    const set = new Set(slugs);
    return games.filter((g) => set.has(g.slug));
  }, [games, slugs]);
  if (filtered.length === 0) return null;
  return (
    <section className="page-section-game-grid">
      {title ? <h3 className="page-section-game-grid-title">{title}</h3> : null}
      <div
        className="game-grid"
        style={{ gridTemplateColumns: `repeat(auto-fill, minmax(${columns === 4 ? '220px' : columns === 3 ? '280px' : '340px'}, 1fr))` }}
      >
        {filtered.map((game, index) => (
          <Link
            key={game.slug}
            to={`/game/${game.slug}`}
            className="game-card game-card--link"
            style={{ ['--i' as string]: index }}
          >
            <GameCardThumbnail game={game} />
            <div className="game-info">
              <div className="game-type">{game.type}</div>
              <div className="game-title">{game.title}</div>
              <GameCardMetaChips tags={game.tags} platforms={game.platforms} />
              <div className="game-description">{game.description}</div>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}

// ===========================================================================
// Main renderer.
// ===========================================================================

export type CommentRenderContext = {
  target_type: CommentTargetType;
  target_key: string;
};

export function PageSectionsView({
  sections,
  commentContext = null,
  commentsEnabled = true,
}: {
  sections: PageSection[];
  commentContext?: CommentRenderContext | null;
  /** When false, comment blocks are hidden (e.g. policy pages). */
  commentsEnabled?: boolean;
}) {
  const { settings } = useSiteSettings();
  const tipUrl = settings.stripe_tip_url.trim();

  if (sections.length === 0) {
    return null;
  }

  return (
    <div className="page-sections">
      {sections.map((s) => {
        switch (s.kind) {
          // ===== Original 6 ===============================================
          case 'heading':
            return (
              <header
                key={s.id}
                className="page-section-heading"
                style={{ textAlign: s.align ?? 'left' }}
              >
                <h2 className="page-section-title">{s.title}</h2>
                {s.subtitle ? <p className="page-section-subtitle">{s.subtitle}</p> : null}
              </header>
            );
          case 'text':
            return (
              <div key={s.id} className="page-section-text prose">
                <div className="page-section-pre">{s.body}</div>
              </div>
            );
          case 'panel':
            return (
              <section
                key={s.id}
                className={`page-section-panel page-section-panel--${s.variant ?? 'default'}`}
              >
                <h3 className="page-section-panel-title">{s.title}</h3>
                <div className="page-section-panel-body prose">
                  <div className="page-section-pre">{s.body}</div>
                </div>
              </section>
            );
          case 'image':
            return (
              <figure key={s.id} className="page-section-figure">
                {s.url ? (
                  <img src={s.url} alt={s.alt ?? ''} className="page-section-img" loading="lazy" />
                ) : (
                  <div className="page-section-img-placeholder">Image URL missing</div>
                )}
                {s.caption ? <figcaption className="page-section-caption">{s.caption}</figcaption> : null}
              </figure>
            );
          case 'video':
            return (
              <figure key={s.id} className="page-section-figure page-section-video-wrap">
                {s.url ? (
                  <video src={s.url} controls playsInline className="page-section-video" />
                ) : (
                  <div className="page-section-img-placeholder">Video URL missing</div>
                )}
                {s.caption ? <figcaption className="page-section-caption">{s.caption}</figcaption> : null}
              </figure>
            );
          case 'divider':
            return <hr key={s.id} className="page-section-divider" />;

          // ===== Expansion ================================================
          case 'gallery':
            return (
              <Gallery
                key={s.id}
                images={s.images}
                columns={s.columns ?? 3}
                lightbox={s.lightbox !== false}
              />
            );
          case 'columns':
            return (
              <div
                key={s.id}
                className={`page-section-columns page-section-columns--gap-${s.gap ?? 'md'}`}
                style={{ gridTemplateColumns: `repeat(${s.columns.length}, 1fr)` }}
              >
                {s.columns.map((col) => (
                  <div key={col.id} className="page-section-columns-col">
                    <PageSectionsView sections={col.sections} />
                  </div>
                ))}
              </div>
            );
          case 'callout':
            return (
              <aside key={s.id} className={`page-section-callout page-section-callout--${s.tone}`}>
                {s.icon ? <span className="page-section-callout-icon">{s.icon}</span> : null}
                <div className="page-section-callout-body">
                  {s.title ? <strong className="page-section-callout-title">{s.title}</strong> : null}
                  <div className="prose">
                    <div className="page-section-pre">{s.body}</div>
                  </div>
                </div>
              </aside>
            );
          case 'quote':
            return (
              <figure key={s.id} className="page-section-quote">
                <blockquote className="page-section-quote-body">“{s.body}”</blockquote>
                {(s.author || s.role) ? (
                  <figcaption className="page-section-quote-author">
                    {s.avatar_url ? (
                      <img src={s.avatar_url} alt="" className="page-section-quote-avatar" />
                    ) : null}
                    <span>
                      <strong>{s.author}</strong>
                      {s.role ? <span className="admin-muted"> · {s.role}</span> : null}
                    </span>
                  </figcaption>
                ) : null}
              </figure>
            );
          case 'code':
            return (
              <pre key={s.id} className="page-section-code">
                {s.filename ? <div className="page-section-code-filename">{s.filename}</div> : null}
                <code data-lang={s.language ?? ''}>{s.body}</code>
              </pre>
            );
          case 'feature_list':
            return (
              <div
                key={s.id}
                className="page-section-features"
                style={{ gridTemplateColumns: `repeat(${s.columns ?? 3}, 1fr)` }}
              >
                {s.items.map((item) => {
                  const Inner = (
                    <>
                      {item.icon ? <div className="page-section-feature-icon">{item.icon}</div> : null}
                      <strong>{item.title}</strong>
                      <p>{item.body}</p>
                    </>
                  );
                  return item.href ? (
                    <a key={item.id} href={item.href} className="page-section-feature">
                      {Inner}
                    </a>
                  ) : (
                    <div key={item.id} className="page-section-feature">{Inner}</div>
                  );
                })}
              </div>
            );
          case 'stats':
            return (
              <div
                key={s.id}
                className="page-section-stats"
                style={{ gridTemplateColumns: `repeat(${s.columns ?? 3}, 1fr)` }}
              >
                {s.items.map((it) => (
                  <div key={it.id} className="page-section-stat">
                    <div className="page-section-stat-value">{it.value ?? '—'}</div>
                    <div className="page-section-stat-label">{it.title}</div>
                    {it.body ? <div className="page-section-stat-sub admin-muted">{it.body}</div> : null}
                  </div>
                ))}
              </div>
            );
          case 'timeline':
            return (
              <ol key={s.id} className="page-section-timeline">
                {s.items.map((it) => (
                  <li key={it.id} className={`page-section-timeline-item is-${it.status ?? 'planned'}`}>
                    <div className="page-section-timeline-dot" aria-hidden>
                      {it.icon ?? '●'}
                    </div>
                    <div className="page-section-timeline-content">
                      <div className="page-section-timeline-head">
                        <strong>{it.title}</strong>
                        {it.status ? (
                          <span className={`page-section-timeline-status is-${it.status}`}>
                            {it.status}
                          </span>
                        ) : null}
                      </div>
                      <p>{it.body}</p>
                    </div>
                  </li>
                ))}
              </ol>
            );
          case 'accordion':
            return (
              <div key={s.id} className="page-section-accordion">
                {s.items.map((it) => (
                  <AccordionRow
                    key={it.id}
                    title={it.title}
                    body={it.body}
                    open={it.id === s.default_open_id}
                  />
                ))}
              </div>
            );
          case 'tabs':
            return <Tabs key={s.id} tabs={s.tabs} />;
          case 'cta':
            return (
              <section
                key={s.id}
                className="page-section-cta-block"
                style={
                  s.bg_image_url
                    ? {
                        backgroundImage: `linear-gradient(rgba(0,0,0,0.55), rgba(0,0,0,0.55)), url(${s.bg_image_url})`,
                        backgroundSize: 'cover',
                        backgroundPosition: 'center',
                      }
                    : undefined
                }
              >
                <h2 className="page-section-cta-title">{s.title}</h2>
                {s.body ? <p className="page-section-cta-body">{s.body}</p> : null}
                <div className="page-section-cta-buttons">
                  {renderCtaButton(s.primary, 'primary', tipUrl)}
                  {renderCtaButton(s.secondary, 'secondary', tipUrl)}
                </div>
              </section>
            );
          case 'embed': {
            const src = embedSrc(s.url, s.provider ?? 'custom');
            return (
              <figure key={s.id} className={`page-section-embed page-section-embed--${s.aspect ?? '16/9'}`}>
                {src ? (
                  <iframe
                    src={src}
                    title="Embedded content"
                    loading="lazy"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                    allowFullScreen
                  />
                ) : (
                  <div className="page-section-img-placeholder">Embed URL missing</div>
                )}
                {s.caption ? <figcaption className="page-section-caption">{s.caption}</figcaption> : null}
              </figure>
            );
          }
          case 'markdown':
            return (
              <div
                key={s.id}
                className="page-section-markdown prose"
                // Markdown was already HTML-escaped and re-emitted as a strict subset by `renderMarkdown`,
                // so the dangerouslySetInnerHTML usage here is safe.
                dangerouslySetInnerHTML={{ __html: renderMarkdown(s.body) }}
              />
            );
          case 'html':
            return (
              <div
                key={s.id}
                className="page-section-html"
                // Admin trust — same model as `custom_head_html` / page custom CSS.
                dangerouslySetInnerHTML={{ __html: s.html }}
              />
            );
          case 'spacer': {
            const px = s.size === 'xs' ? 8 : s.size === 'sm' ? 16 : s.size === 'md' ? 32 : s.size === 'lg' ? 64 : 128;
            return <div key={s.id} style={{ height: px }} aria-hidden />;
          }
          case 'hero': {
            const heightStyle =
              s.height === 'screen'
                ? { minHeight: '70vh' }
                : s.height === 'lg'
                  ? { minHeight: 420 }
                  : s.height === 'sm'
                    ? { minHeight: 220 }
                    : { minHeight: 320 };
            return (
              <section
                key={s.id}
                className="page-section-block-hero"
                style={{
                  ...heightStyle,
                  textAlign: s.align ?? 'center',
                  ...(s.bg_image_url
                    ? {
                        backgroundImage: `linear-gradient(rgba(0,0,0,${s.overlay ?? 0.4}), rgba(0,0,0,${s.overlay ?? 0.4})), url(${s.bg_image_url})`,
                        backgroundSize: 'cover',
                        backgroundPosition: 'center',
                      }
                    : {}),
                }}
              >
                {s.bg_video_url ? (
                  <video
                    src={s.bg_video_url}
                    autoPlay
                    muted
                    loop
                    playsInline
                    className="page-section-block-hero-video"
                  />
                ) : null}
                <div className="page-section-block-hero-content">
                  <h1>{s.title}</h1>
                  {s.subtitle ? <p>{s.subtitle}</p> : null}
                  {renderCtaButton(s.cta, 'primary', tipUrl)}
                </div>
              </section>
            );
          }
          case 'download':
            return (
              <a
                key={s.id}
                href={s.href || '#'}
                download
                target={s.href.startsWith('http') ? '_blank' : undefined}
                rel="noreferrer"
                className="page-section-download"
              >
                <span className="page-section-download-icon">{s.icon ?? '⬇️'}</span>
                <span className="page-section-download-body">
                  <strong>{s.title}</strong>
                  <span>{s.body}</span>
                </span>
                <span className="page-section-download-meta">
                  {s.format ? <span className="page-section-download-format">{s.format}</span> : null}
                  {s.size ? <span className="page-section-download-size">{s.size}</span> : null}
                </span>
              </a>
            );
          case 'tip_button':
            return (
              <div
                key={s.id}
                className="page-section-buttons page-section-tip-button"
                style={{
                  justifyContent:
                    s.align === 'center' ? 'center' : s.align === 'right' ? 'flex-end' : 'flex-start',
                }}
              >
                <SupportTipButton
                  label={s.label}
                  className={s.variant === 'secondary' ? 'btn-support btn-support--secondary' : 'btn-support'}
                />
              </div>
            );
          case 'buttons':
            return (
              <div
                key={s.id}
                className="page-section-buttons"
                style={{
                  justifyContent:
                    s.align === 'center' ? 'center' : s.align === 'right' ? 'flex-end' : 'flex-start',
                }}
              >
                {s.buttons.map((b) =>
                  renderCtaButton(
                    { label: b.label, href: b.href, external: b.external },
                    b.variant === 'secondary' || b.variant === 'ghost' ? 'secondary' : 'primary',
                    tipUrl,
                  ),
                )}
              </div>
            );
          case 'faq':
            return (
              <section key={s.id} className="page-section-faq">
                {s.intro ? <p className="page-section-faq-intro admin-muted">{s.intro}</p> : null}
                {s.items.map((it) => (
                  <div key={it.id} className="page-section-faq-row">
                    <strong className="page-section-faq-q">{it.title}</strong>
                    <p className="page-section-faq-a">{it.body}</p>
                  </div>
                ))}
              </section>
            );
          case 'sandbox_html': {
            const doc = s.html?.trim() ?? '';
            const height = s.height_px ?? 560;
            if (!doc) {
              return (
                <div key={s.id} className="page-section-img-placeholder">
                  Mini-app HTML missing — edit this block in Admin.
                </div>
              );
            }
            return (
              <figure key={s.id} className="page-section-sandbox-html">
                <iframe
                  title="Mini app"
                  className="html-app-embed"
                  style={{ height, minHeight: height, width: '100%' }}
                  srcDoc={doc}
                  sandbox={htmlAppSandbox(Boolean(s.iframe_compat))}
                  referrerPolicy="no-referrer"
                />
                {s.caption ? <figcaption className="page-section-caption">{s.caption}</figcaption> : null}
              </figure>
            );
          }
          case 'iframe':
            return (
              <figure key={s.id} className="page-section-iframe">
                {s.url ? (
                  <iframe
                    src={s.url}
                    title="Embedded tool"
                    style={{ width: '100%', height: s.height_px ?? 480, border: 0, borderRadius: 8 }}
                    allow={s.allow ?? 'fullscreen; autoplay; clipboard-write'}
                  />
                ) : (
                  <div className="page-section-img-placeholder">Iframe URL missing</div>
                )}
                {s.caption ? <figcaption className="page-section-caption">{s.caption}</figcaption> : null}
              </figure>
            );
          case 'image_text':
            return (
              <section
                key={s.id}
                className={`page-section-image-text page-section-image-text--${s.image_side ?? 'left'}`}
              >
                <div className="page-section-image-text-image">
                  {s.image_url ? (
                    <img src={s.image_url} alt={s.image_alt ?? ''} loading="lazy" />
                  ) : (
                    <div className="page-section-img-placeholder">Image URL missing</div>
                  )}
                </div>
                <div className="page-section-image-text-body prose">
                  <h3>{s.title}</h3>
                  <div className="page-section-pre">{s.body}</div>
                  {renderCtaButton(s.cta, 'primary', tipUrl)}
                </div>
              </section>
            );
          case 'pricing':
            return (
              <div
                key={s.id}
                className="page-section-pricing"
                style={{ gridTemplateColumns: `repeat(${s.columns.length}, 1fr)` }}
              >
                {s.columns.map((col) => (
                  <div
                    key={col.id}
                    className={`page-section-pricing-col${col.featured ? ' is-featured' : ''}`}
                  >
                    <div className="page-section-pricing-title">{col.title}</div>
                    <div className="page-section-pricing-price">
                      <strong>{col.price}</strong>
                      {col.period ? <span className="admin-muted">{col.period}</span> : null}
                    </div>
                    <ul className="page-section-pricing-features">
                      {col.features.map((f, i) => <li key={i}>{f}</li>)}
                    </ul>
                    {renderCtaButton(col.cta, col.featured ? 'primary' : 'secondary', tipUrl)}
                  </div>
                ))}
              </div>
            );
          case 'team':
            return (
              <div
                key={s.id}
                className="page-section-team"
                style={{ gridTemplateColumns: `repeat(${s.columns ?? 3}, 1fr)` }}
              >
                {s.members.map((m) => {
                  const Avatar = (
                    <>
                      {m.avatar_url ? (
                        <img src={m.avatar_url} alt="" className="page-section-team-avatar" />
                      ) : (
                        <div className="page-section-team-avatar page-section-team-avatar--placeholder">
                          {m.name.slice(0, 1).toUpperCase()}
                        </div>
                      )}
                      <strong>{m.name}</strong>
                      <span className="admin-muted">{m.role}</span>
                      {m.bio ? <p>{m.bio}</p> : null}
                    </>
                  );
                  return m.href ? (
                    <a key={m.id} href={m.href} target="_blank" rel="noreferrer" className="page-section-team-card">
                      {Avatar}
                    </a>
                  ) : (
                    <div key={m.id} className="page-section-team-card">{Avatar}</div>
                  );
                })}
              </div>
            );
          case 'newsletter':
            return (
              <form
                key={s.id}
                action={s.action_url || '#'}
                method="post"
                target="_blank"
                className="page-section-newsletter"
              >
                <h3>{s.title}</h3>
                {s.body ? <p>{s.body}</p> : null}
                <div className="page-section-newsletter-row">
                  <input type="email" name="email" required placeholder="you@example.com" />
                  <button type="submit">{s.button_label ?? 'Subscribe'}</button>
                </div>
              </form>
            );
          case 'game_grid':
            return (
              <GameGrid
                key={s.id}
                slugs={s.slugs}
                columns={s.columns ?? 3}
                title={s.title}
              />
            );
          case 'tags':
            return (
              <div key={s.id} className="page-section-tags">
                {s.items.map((t) =>
                  t.href ? (
                    <a key={t.id} href={t.href} className={`page-section-tag is-${t.tone ?? 'default'}`}>
                      {t.label}
                    </a>
                  ) : (
                    <span key={t.id} className={`page-section-tag is-${t.tone ?? 'default'}`}>
                      {t.label}
                    </span>
                  ),
                )}
              </div>
            );
          case 'comments': {
            if (!commentsEnabled) return null;
            const tt = s.target_type ?? commentContext?.target_type;
            const tk = (s.target_key ?? commentContext?.target_key ?? '').trim();
            if (!tt || !tk) return null;
            return (
              <CommentSection
                key={s.id}
                targetType={tt}
                targetKey={tk}
                title={s.title ?? 'Comments'}
              />
            );
          }
          default:
            return null;
        }
      })}
    </div>
  );
}

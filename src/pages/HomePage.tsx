import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { GameCardMetaChips } from '../components/GameCardMetaChips';
import { GameCardThumbnail } from '../components/GameCardThumbnail';
import { PageSectionsView } from '../components/PageSectionsView';
import { SiteChrome } from '../components/SiteChrome';
import { SiteSocialFollow } from '../components/SiteSocialFollow';
import { useGames } from '../hooks/useGames';
import { gameCatalogMode } from '../lib/gameCatalog';
import { activePromoEvents } from '../lib/promoEvents';
import { backendConfigured } from '../lib/backend';
import { useSiteSettings } from '../hooks/useSiteSettings';

export function HomePage() {
  const { games, loading, error } = useGames();
  const { settings } = useSiteSettings();
  // Default filter — admin can pin a non-"all" filter from the Behavior tab.
  const [filter, setFilter] = useState<'all' | 'game' | 'asset'>(
    settings.behavior?.default_game_filter ?? 'all',
  );
  const showFilterBtns = settings.behavior?.show_filter_buttons !== false;
  const showSupport = settings.behavior?.show_support_section !== false;
  const showFooter = settings.behavior?.show_footer !== false;
  const intro = settings.behavior?.homepage_intro;

  const filtered =
    filter === 'all' ? games : games.filter((g) => g.type.toLowerCase() === filter);
  const promos = useMemo(
    () => activePromoEvents(settings.promo_events).filter((e) => e.title.trim()),
    [settings.promo_events],
  );
  const supportButtons = settings.support_buttons.map((btn) => {
    if ((btn.id === 'tip' || btn.id === 'donate') && settings.stripe_tip_url.trim()) {
      return { ...btn, href: settings.stripe_tip_url.trim(), external: true };
    }
    if (btn.id === 'contact' && settings.support_page_href.trim()) {
      return { ...btn, href: settings.support_page_href.trim(), external: false };
    }
    return btn;
  });

  // Admin-driven homepage sections (Studio → Homepage). `replace` mode lets
  // the admin own the entire page (no hero, no grid, no footer).
  const homepageSections = settings.homepage_sections ?? [];
  const layoutMode = settings.homepage_layout_mode ?? 'append';
  const showBuiltins = layoutMode !== 'replace';

  return (
    <SiteChrome>
      {/* Optional admin-managed HTML banner (Behavior → Homepage intro). */}
      {intro?.enabled && intro.html.trim() ? (
        <section
          className="admin-panel"
          style={{ marginBottom: 16 }}
          // Trusted admin content — same trust model as `custom_css` / `custom_head_html`.
          dangerouslySetInnerHTML={{ __html: intro.html }}
        />
      ) : null}

      {/* Admin-built top-of-page blocks. */}
      {layoutMode === 'prepend' && homepageSections.length > 0 ? (
        <PageSectionsView sections={homepageSections} />
      ) : null}

      {/* Replace-mode renders ONLY the admin blocks. */}
      {layoutMode === 'replace' ? (
        <PageSectionsView sections={homepageSections} />
      ) : null}

      {showBuiltins ? (
        <>
      {/* Hero — pulls in Studio hero config (badge / logo / CTAs / scroll
          indicator) layered on top of the original title + subtitle. */}
      <header style={{ position: 'relative' }}>
        {settings.hero?.badge?.enabled && settings.hero.badge.text.trim() ? (
          <div
            className="hero-badge"
            style={{
              display: 'inline-block',
              fontSize: '0.72rem',
              fontWeight: 700,
              letterSpacing: '0.12em',
              padding: '4px 10px',
              borderRadius: 999,
              marginBottom: 12,
            }}
          >
            {settings.hero.badge.text}
          </div>
        ) : null}
        {settings.hero?.logo_image_url ? (
          <img
            src={settings.hero.logo_image_url}
            alt={settings.hero_title || settings.branding?.site_name || 'Site logo'}
            className="hero-logo"
            style={{ display: 'block', margin: '0 auto 16px', maxWidth: '100%' }}
          />
        ) : null}
        {settings.hero?.show_title !== false ? (
          <div className="header-title">{settings.hero_title}</div>
        ) : null}
        {settings.hero?.show_subtitle !== false ? (
          <div className="header-subtitle">{settings.hero_subtitle}</div>
        ) : null}
        {settings.hero?.tagline?.trim() ? (
          <div className="hero-tagline admin-muted" style={{ marginTop: 6 }}>
            {settings.hero.tagline}
          </div>
        ) : null}
        {settings.hero?.buttons && settings.hero.buttons.length > 0 ? (
          <div className="hero-cta-row" style={{ display: 'flex', gap: 10, justifyContent: 'center', marginTop: 16, flexWrap: 'wrap' }}>
            {settings.hero.buttons.map((b) => {
              const variantStyles =
                b.variant === 'primary'
                  ? { background: 'var(--accent)', color: '#06070d' }
                  : b.variant === 'secondary'
                    ? { background: 'var(--panel)', color: 'var(--text)' }
                    : { background: 'transparent', color: 'var(--text)', border: '1px solid var(--border)' };
              const style: React.CSSProperties = {
                padding: '10px 18px',
                borderRadius: 8,
                fontWeight: 600,
                textDecoration: 'none',
                ...variantStyles,
              };
              return b.external ? (
                <a key={b.id} href={b.href} target="_blank" rel="noreferrer" style={style}>
                  {b.label}
                </a>
              ) : (
                <Link key={b.id} to={b.href || '/'} style={style}>
                  {b.label}
                </Link>
              );
            })}
          </div>
        ) : null}
        {settings.hero?.scroll_indicator?.enabled ? (
          <div
            className="hero-scroll-indicator"
            aria-hidden
            style={{
              textAlign: 'center',
              marginTop: 28,
              fontSize: '1.4rem',
              animation: 'studio-pulse 1.6s ease-in-out infinite',
            }}
          >
            {settings.hero.scroll_indicator.emoji || '↓'}
          </div>
        ) : null}
      </header>

      {promos.length > 0 ? (
        <section className="promo-events" aria-label="Announcements">
          {promos.map((ev) => (
            <article key={ev.id} className="promo-card">
              <div className="promo-card__title">{ev.title}</div>
              {ev.body.trim() ? <div className="promo-card__body">{ev.body}</div> : null}
              {ev.href.trim() ? (
                <div className="promo-card__cta">
                  {ev.external ? (
                    <a href={ev.href.trim()} target="_blank" rel="noreferrer" className="promo-card__link">
                      Learn more →
                    </a>
                  ) : (
                    <Link to={ev.href.trim()} className="promo-card__link">
                      Learn more →
                    </Link>
                  )}
                </div>
              ) : null}
            </article>
          ))}
        </section>
      ) : null}

      {showFilterBtns ? (
        <div className="filter-buttons">
          <button type="button" className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>
            ALL
          </button>
          <button
            type="button"
            className={filter === 'game' ? 'active' : ''}
            onClick={() => setFilter('game')}
          >
            GAMES
          </button>
          <button
            type="button"
            className={filter === 'asset' ? 'active' : ''}
            onClick={() => setFilter('asset')}
          >
            ASSETS
          </button>
        </div>
      ) : null}

      {loading && <div className="empty-state">Loading catalog…</div>}
      {error && <div className="empty-state">Error: {error}</div>}

      {!loading && !error && filtered.length === 0 && (
        <div className="empty-state">
          <p>No games found in this category.</p>
          {games.length === 0 && filter === 'all' ? (
            <p style={{ marginTop: 16 }} className="admin-muted">
              {backendConfigured() && gameCatalogMode() === 'cms' ? (
                <>
                  <Link to="/admin">Open Admin</Link> to add games, or set{' '}
                  <code>VITE_GAME_CATALOG=auto</code> in the build to use <code>games.json</code> again.
                </>
              ) : (
                <>
                  Edit <code>games.json</code> and put builds in <code>games/&lt;slug&gt;/</code>, then push.
                  {backendConfigured() ? (
                    <>
                      {' '}
                      Or <Link to="/admin">Admin</Link> once your team login works.
                    </>
                  ) : null}{' '}
                  See <code>docs/WEBSITE_WORKFLOW.md</code>.
                </>
              )}
            </p>
          ) : null}
        </div>
      )}

      {!loading && !error && filtered.length > 0 && (
        <div className="game-grid">
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
      )}

      {showSupport ? (
        <div className="support-section">
          <div className="support-title">{settings.support_title}</div>
          <p style={{ marginBottom: 30, color: '#aaa', fontSize: '0.95rem' }} className="prose">
            {settings.support_body}
          </p>
          <div className="support-buttons">
            {supportButtons.map((btn) => {
              const href = btn.href.trim();
              if (!href) {
                return (
                  <button key={btn.id} type="button" className="btn-support" disabled style={{ opacity: 0.5 }}>
                    {btn.label}
                  </button>
                );
              }
              if (btn.external) {
                return (
                  <a key={btn.id} href={href} target="_blank" rel="noreferrer" className="btn-support">
                    {btn.label}
                  </a>
                );
              }
              return (
                <Link key={btn.id} to={href} className="btn-support">
                  {btn.label}
                </Link>
              );
            })}
          </div>
        </div>
      ) : null}

      {showFooter ? (
        <footer style={{ display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'center' }}>
          {settings.footer_text ? <div>{settings.footer_text}</div> : null}
          {/* Auto-copyright — only renders when Brand studio enables it. */}
          {settings.branding?.footer_show_auto_copyright ? (
            <div className="admin-muted" style={{ fontSize: '0.82rem' }}>
              {settings.branding.footer_copyright_template
                .replace('{year}', String(new Date().getFullYear()))
                .replace('{name}', settings.branding.site_name || 'Site')}
            </div>
          ) : null}
          {settings.branding?.show_made_with ? (
            <div className="admin-muted" style={{ fontSize: '0.78rem' }}>
              Made with ❤ by indie devs.
            </div>
          ) : null}
          <SiteSocialFollow slot="footer" />
        </footer>
      ) : null}
        </>
      ) : null}

      {/* Admin-built blocks below the built-in hero + grid. */}
      {layoutMode === 'append' && homepageSections.length > 0 ? (
        <PageSectionsView sections={homepageSections} />
      ) : null}
    </SiteChrome>
  );
}

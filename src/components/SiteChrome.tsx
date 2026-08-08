import { useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { fetchNavItems, fetchSitePages } from '../lib/cmsData';
import { showAdminNavLink } from '../lib/envPublic';
import { backendConfigured } from '../lib/backend';
import { useAsyncMemo } from '../hooks/useAsyncMemo';
import { useSiteSettings } from '../hooks/useSiteSettings';
import type { BehaviorConfig } from '../types';
import { LegalFooter } from './LegalFooter';
import { AdSlot } from './AdSlot';
import { SiteSocialFollow } from './SiteSocialFollow';
import { StripeBuyButtonSlot } from './StripeBuyButtonSlot';
import { UserAuthNav } from './UserAuthNav';

export type SiteNavLink = { label: string; href: string; external: boolean };

/** Built-in hub entries (order: Home → optional Apps → Vault → Dev log). */
function buildCoreNavLinks(behavior: BehaviorConfig | undefined): SiteNavLink[] {
  const b = behavior;
  const out: SiteNavLink[] = [];
  if (b?.show_home_nav_link !== false) {
    out.push({ label: '🏠 Home', href: '/', external: false });
  }
  if (b?.show_apps_lab_link && b?.enable_apps_hub_page !== false) {
    out.push({ label: '⚡ Apps', href: '/apps', external: false });
  }
  if (b?.show_services_link !== false && b?.enable_services_page !== false) {
    out.push({ label: '💼 Services', href: '/services', external: false });
  }
  if (b?.show_vault_link !== false && b?.enable_vault_page !== false) {
    out.push({ label: '🔐 Vault', href: '/vault', external: false });
  }
  if (b?.show_devlog_link !== false && b?.enable_devlog_section !== false) {
    out.push({ label: '📝 Dev log', href: '/devlog', external: false });
  }
  return out;
}

/**
 * Builds the primary nav link list (Home / Vault / Dev log + CMS nav pages + custom nav).
 * Placement (top vs footer) is controlled in Behavior — this hook only computes the list.
 */
export function useSiteNavLinks(): SiteNavLink[] {
  const { settings } = useSiteSettings();
  const showApps = Boolean(settings.behavior?.show_apps_lab_link);
  const showServices = settings.behavior?.show_services_link !== false;
  const showHome = settings.behavior?.show_home_nav_link !== false;
  const showVault = settings.behavior?.show_vault_link !== false;
  const showDevlog = settings.behavior?.show_devlog_link !== false;
  const computed = useAsyncMemo(async () => {
    const [nav, pages] = await Promise.all([fetchNavItems(), fetchSitePages()]);
    const fromPages = pages
      .filter((p) => p.show_in_nav && p.published !== false)
      .map((p) => ({ label: p.title, href: `/p/${p.slug}`, external: false as const }));
    const custom = nav.map((n) => ({
      label: n.label,
      href: n.href,
      external: n.external,
    }));
    const filteredCore = buildCoreNavLinks(settings.behavior);
    if (!backendConfigured() || (nav.length === 0 && fromPages.length === 0)) {
      return filteredCore;
    }
    const seen = new Set<string>();
    const out: SiteNavLink[] = [];
    for (const item of [...filteredCore, ...fromPages, ...custom]) {
      const key = `${item.href}|${item.label}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      out.push(item);
    }
    return out;
  }, [showHome, showVault, showDevlog, showApps, showServices, settings.behavior]);
  return useMemo(() => computed ?? buildCoreNavLinks(settings.behavior), [computed, settings.behavior]);
}

function NavLinkList({ links }: { links: SiteNavLink[] }) {
  return (
    <>
      {links.map((l) =>
        l.external ? (
          <a key={l.href + l.label} href={l.href} target="_blank" rel="noreferrer">
            {l.label}
          </a>
        ) : (
          <Link key={l.href + l.label} to={l.href}>
            {l.label}
          </Link>
        ),
      )}
    </>
  );
}

function PrimaryNavRow({
  links,
  navExtra,
  adminLinkVisible,
  adminLabel,
  socialSlot,
  className,
}: {
  links: SiteNavLink[];
  navExtra?: React.ReactNode;
  adminLinkVisible: boolean;
  adminLabel: string;
  socialSlot: 'header' | 'footer';
  className: string;
}) {
  return (
    <nav className={className} style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
      <div className="top-nav__links" style={{ display: 'flex', gap: 12, flexWrap: 'wrap', flex: 1, minWidth: 0 }}>
        <NavLinkList links={links} />
        {navExtra}
        {adminLinkVisible ? (
          <Link to="/admin">{adminLabel}</Link>
        ) : null}
      </div>
      <div className="top-nav__meta" style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
        <UserAuthNav />
        <SiteSocialFollow slot={socialSlot} />
      </div>
    </nav>
  );
}

export function SiteChrome({
  children,
  navExtra,
  immersive = false,
}: {
  children: React.ReactNode;
  navExtra?: React.ReactNode;
  /** Wider, lighter layout for game/page “world” views (pairs with global immersive CSS). */
  immersive?: boolean;
}) {
  const links = useSiteNavLinks();
  const auth = useAuth();
  const { settings } = useSiteSettings();
  const b = settings.behavior;
  const brand = settings.branding;
  const skipLinkEnabled = settings.accessibility?.skip_link_enabled;

  const showBrandStrip = b?.show_header_brand_strip !== false;
  const showNavHeader = b?.show_primary_nav_header !== false;
  const showNavFooter = b?.show_primary_nav_footer === true;
  const adminLinkVisible = showAdminNavLink() || b?.show_admin_link_in_nav === true;
  const adminLabel = auth.isAdmin ? 'Admin' : 'Team login';

  const socialHeader = settings.social?.show_in_header && (settings.social?.links?.length ?? 0) > 0;

  useEffect(() => {
    const onMove = (event: MouseEvent) => {
      document.documentElement.style.setProperty('--cursor-x', `${event.clientX}px`);
      document.documentElement.style.setProperty('--cursor-y', `${event.clientY}px`);
    };
    document.addEventListener('mousemove', onMove);
    let scrollFxTimeout: ReturnType<typeof setTimeout>;
    const onScroll = () => {
      document.body.classList.add('scrolling');
      clearTimeout(scrollFxTimeout);
      scrollFxTimeout = setTimeout(() => {
        document.body.classList.remove('scrolling');
      }, 120);
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      document.removeEventListener('mousemove', onMove);
      window.removeEventListener('scroll', onScroll);
      clearTimeout(scrollFxTimeout);
    };
  }, []);

  return (
    <div className={immersive ? 'container container--immersive' : 'container'}>
      {skipLinkEnabled ? (
        <a href="#main-content" className="studio-skip-link">
          Skip to content
        </a>
      ) : null}
      {showBrandStrip && (brand.header_logo_url || brand.header_tagline) ? (
        <div
          className="site-header-brand"
          style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}
        >
          {brand.header_logo_url ? (
            <img
              src={brand.header_logo_url}
              alt={brand.site_name}
              style={{ height: brand.header_logo_height_px || 32 }}
            />
          ) : null}
          {brand.header_tagline ? (
            <span className="admin-muted" style={{ fontSize: '0.85rem' }}>
              {brand.header_tagline}
            </span>
          ) : null}
        </div>
      ) : null}

      {showNavHeader ? (
        <PrimaryNavRow
          links={links}
          navExtra={navExtra}
          adminLinkVisible={adminLinkVisible}
          adminLabel={adminLabel}
          socialSlot="header"
          className="top-nav"
        />
      ) : socialHeader ? (
        <div
          className="top-nav top-nav--social-only"
          style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', marginBottom: 4 }}
        >
          <SiteSocialFollow slot="header" />
        </div>
      ) : adminLinkVisible ? (
        <div className="site-chrome-admin-fallback" style={{ textAlign: 'right', marginBottom: 10 }}>
          <Link to="/admin">{adminLabel}</Link>
        </div>
      ) : null}

      <StripeBuyButtonSlot placement="site_top" />

      <div id="main-content">{children}</div>

      <StripeBuyButtonSlot placement="site_bottom" />

      {showNavFooter ? (
        <PrimaryNavRow
          links={links}
          navExtra={navExtra}
          adminLinkVisible={adminLinkVisible}
          adminLabel={adminLabel}
          socialSlot="footer"
          className="site-footer-nav"
        />
      ) : null}

      <AdSlot placement="site-footer" />
      <LegalFooter />
    </div>
  );
}

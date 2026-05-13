import { useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { fetchNavItems, fetchSitePages } from '../lib/cmsData';
import { showAdminNavLink } from '../lib/envPublic';
import { supabaseConfigured } from '../lib/supabase';
import { useAsyncMemo } from '../hooks/useAsyncMemo';
import { useSiteSettings } from '../hooks/useSiteSettings';

const coreNav = [
  { label: 'Home', href: '/', external: false as const },
  { label: 'Vault', href: '/vault', external: false as const },
  { label: 'Dev log', href: '/devlog', external: false as const },
];

/**
 * Builds the top-nav link list.
 *
 * Behaviour flags from `SiteSettings.behavior` can hide the built-in Vault /
 * Dev log entries — handy when those routes aren't ready for the public yet.
 * CMS pages with `show_in_nav` and custom nav items always render regardless.
 */
export function useSiteNavLinks() {
  const { settings } = useSiteSettings();
  const showVault = settings.behavior?.show_vault_link !== false;
  const showDevlog = settings.behavior?.show_devlog_link !== false;
  const computed = useAsyncMemo(async () => {
    const [nav, pages] = await Promise.all([fetchNavItems(), fetchSitePages()]);
    const fromPages = pages
      .filter((p) => p.show_in_nav)
      .map((p) => ({ label: p.title, href: `/p/${p.slug}`, external: false as const }));
    const custom = nav.map((n) => ({
      label: n.label,
      href: n.href,
      external: n.external,
    }));
    const filteredCore = coreNav.filter((item) => {
      if (item.href === '/vault') return showVault;
      if (item.href === '/devlog') return showDevlog;
      return true;
    });
    if (!supabaseConfigured || (nav.length === 0 && fromPages.length === 0)) {
      return filteredCore;
    }
    const seen = new Set<string>();
    const out: { label: string; href: string; external: boolean }[] = [];
    for (const item of [...filteredCore, ...fromPages, ...custom]) {
      const key = `${item.href}|${item.label}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      out.push(item);
    }
    return out;
  }, [showVault, showDevlog]);
  return useMemo(() => computed ?? coreNav, [computed]);
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
  // Either the build-time env flag OR the runtime CMS toggle reveals the admin link.
  const adminLinkVisible = showAdminNavLink() || settings.behavior?.show_admin_link_in_nav === true;

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
      <nav className="top-nav">
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
        {navExtra}
        {adminLinkVisible ? (
          <Link to="/admin">{auth.isAdmin ? 'Admin' : 'Team login'}</Link>
        ) : null}
      </nav>
      {children}
    </div>
  );
}

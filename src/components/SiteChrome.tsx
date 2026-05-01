import { useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { fetchNavItems, fetchSitePages } from '../lib/cmsData';
import { supabaseConfigured } from '../lib/supabase';
import { useAsyncMemo } from '../hooks/useAsyncMemo';

const coreNav = [
  { label: 'Home', href: '/', external: false as const },
  { label: 'Dev log', href: '/devlog', external: false as const },
];

export function useSiteNavLinks() {
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
    if (!supabaseConfigured || (nav.length === 0 && fromPages.length === 0)) {
      return coreNav;
    }
    const seen = new Set<string>();
    const out: { label: string; href: string; external: boolean }[] = [];
    for (const item of [...coreNav, ...fromPages, ...custom]) {
      const key = `${item.href}|${item.label}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      out.push(item);
    }
    return out;
  }, []);
  return useMemo(() => computed ?? coreNav, [computed]);
}

export function SiteChrome({
  children,
  navExtra,
}: {
  children: React.ReactNode;
  navExtra?: React.ReactNode;
}) {
  const links = useSiteNavLinks();
  const auth = useAuth();

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
    <div className="container">
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
        {supabaseConfigured && (
          <Link to="/admin">{auth.isAdmin ? 'Admin' : 'Team login'}</Link>
        )}
      </nav>
      {children}
    </div>
  );
}

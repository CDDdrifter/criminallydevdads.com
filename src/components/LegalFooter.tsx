/**
 * LegalFooter — site-wide footer with policy links + copyright, driven by
 * `site_settings.legal`. Rendered once at the bottom of every page via
 * SiteChrome. Internal hrefs (starting with `/`) use the client router.
 */
import { Link } from 'react-router-dom';
import { useSiteSettings } from '../hooks/useSiteSettings';

export function LegalFooter() {
  const { settings } = useSiteSettings();
  const legal = settings.legal;
  if (!legal?.show_footer) return null;

  const year = new Date().getFullYear();
  const name = legal.business_name?.trim() || settings.branding?.site_name?.trim() || 'This site';
  const links = legal.links ?? [];

  return (
    <footer className="legal-footer" style={{
      marginTop: 40,
      paddingTop: 18,
      borderTop: '1px solid var(--border)',
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      alignItems: 'center',
      textAlign: 'center',
    }}>
      {links.length > 0 ? (
        <nav className="legal-footer__links" style={{ display: 'flex', flexWrap: 'wrap', gap: 14, justifyContent: 'center' }}>
          {links.map((l) =>
            l.href.startsWith('/') ? (
              <Link key={l.id} to={l.href} className="admin-muted" style={{ fontSize: '0.82rem' }}>
                {l.label}
              </Link>
            ) : (
              <a
                key={l.id}
                href={l.href}
                target="_blank"
                rel="noreferrer"
                className="admin-muted"
                style={{ fontSize: '0.82rem' }}
              >
                {l.label}
              </a>
            ),
          )}
        </nav>
      ) : null}
      <p className="admin-muted" style={{ fontSize: '0.78rem', margin: 0, lineHeight: 1.5 }}>
        © {year} {name}. All rights reserved.
        {legal.contact_email?.trim() ? (
          <>
            {' · '}
            <a href={`mailto:${legal.contact_email.trim()}`} style={{ color: 'inherit' }}>
              {legal.contact_email.trim()}
            </a>
          </>
        ) : null}
      </p>
    </footer>
  );
}

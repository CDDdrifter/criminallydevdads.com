/**
 * FormPrivacyNote — small "how we use your info" line under forms that collect
 * an email. Links to the Privacy Policy from the legal footer config when set.
 */
import { Link } from 'react-router-dom';
import { useSiteSettings } from '../hooks/useSiteSettings';

export function FormPrivacyNote({ context = 'your message' }: { context?: string }) {
  const { settings } = useSiteSettings();
  const links = settings.legal?.links ?? [];
  const privacy = links.find((l) => /privacy/i.test(l.label) || /privacy/i.test(l.href));

  return (
    <p className="admin-muted" style={{ fontSize: '0.76rem', marginTop: 10, lineHeight: 1.45 }}>
      We use your email only to respond to {context} and never sell it.{' '}
      {privacy ? (
        privacy.href.startsWith('/') ? (
          <Link to={privacy.href} style={{ textDecoration: 'underline' }}>
            Privacy Policy
          </Link>
        ) : (
          <a href={privacy.href} target="_blank" rel="noreferrer" style={{ textDecoration: 'underline' }}>
            Privacy Policy
          </a>
        )
      ) : null}
    </p>
  );
}

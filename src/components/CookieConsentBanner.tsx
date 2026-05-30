/**
 * CookieConsentBanner — dismissible bottom banner shown until the visitor
 * acknowledges it. Purely informational consent (essential cookies only), so
 * it gates nothing; it records acknowledgement in localStorage. Controlled by
 * `site_settings.legal.cookie_banner_enabled`.
 */
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useSiteSettings } from '../hooks/useSiteSettings';

const STORAGE_KEY = 'cdd_cookie_ack_v1';

export function CookieConsentBanner() {
  const { settings, ready } = useSiteSettings();
  const legal = settings.legal;
  const [ack, setAck] = useState(true);

  useEffect(() => {
    try {
      setAck(localStorage.getItem(STORAGE_KEY) === '1');
    } catch {
      setAck(false);
    }
  }, []);

  if (!ready || !legal?.cookie_banner_enabled || ack) return null;

  const dismiss = () => {
    try {
      localStorage.setItem(STORAGE_KEY, '1');
    } catch {
      /* ignore */
    }
    setAck(true);
  };

  const cookieLink = legal.links?.find((l) => /cookie/i.test(l.label) || /cookie/i.test(l.href));

  return (
    <div
      role="dialog"
      aria-label="Cookie notice"
      style={{
        position: 'fixed',
        left: 12,
        right: 12,
        bottom: 12,
        zIndex: 9000,
        margin: '0 auto',
        maxWidth: 720,
        background: 'var(--panel, rgba(20,20,28,0.97))',
        border: '1px solid var(--border)',
        borderRadius: 12,
        padding: '14px 16px',
        display: 'flex',
        flexWrap: 'wrap',
        gap: 12,
        alignItems: 'center',
        justifyContent: 'space-between',
        boxShadow: '0 8px 30px rgba(0,0,0,0.45)',
      }}
    >
      <p style={{ margin: 0, fontSize: '0.84rem', lineHeight: 1.5, flex: '1 1 320px' }}>
        {legal.cookie_notice}{' '}
        {cookieLink ? (
          cookieLink.href.startsWith('/') ? (
            <Link to={cookieLink.href} style={{ textDecoration: 'underline' }}>
              Learn more
            </Link>
          ) : (
            <a href={cookieLink.href} target="_blank" rel="noreferrer" style={{ textDecoration: 'underline' }}>
              Learn more
            </a>
          )
        ) : null}
      </p>
      <button type="button" className="btn-play" onClick={dismiss} style={{ flex: '0 0 auto' }}>
        Got it
      </button>
    </div>
  );
}

/**
 * SiteWatermark — tiny brand watermark pinned to the bottom-right.
 *
 * Renders only when `branding.watermark_text` or `branding.watermark_url`
 * is set. Hidden on the admin route so we don't get watermark-in-watermark
 * while editing.
 */
import { useLocation } from 'react-router-dom';
import { useSiteSettings } from '../hooks/useSiteSettings';

export function SiteWatermark() {
  const { settings } = useSiteSettings();
  const { pathname, hash } = useLocation();
  const b = settings.branding;

  if (!b.watermark_text && !b.watermark_url) return null;
  if (pathname === '/admin' || hash === '#/admin') return null;

  return (
    <div
      aria-hidden
      style={{
        position: 'fixed',
        right: 12,
        bottom: 12,
        zIndex: 9000,
        pointerEvents: 'none',
        opacity: 0.5,
        fontSize: '0.72rem',
        color: 'var(--muted)',
        display: 'flex',
        alignItems: 'center',
        gap: 6,
      }}
    >
      {b.watermark_url ? (
        <img src={b.watermark_url} alt="" style={{ height: 18 }} />
      ) : null}
      {b.watermark_text ? <span>{b.watermark_text}</span> : null}
    </div>
  );
}

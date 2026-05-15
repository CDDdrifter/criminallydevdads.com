/**
 * MaintenanceGate
 *
 * Wraps the route tree. When `behavior.maintenance_mode.enabled` is true,
 * every non-/admin route renders a maintenance card instead of the real
 * page. Admins (with `allow_admin_bypass`) and the `/admin` route itself
 * always pass through, so site owners can flip the switch from the studio
 * without locking themselves out.
 */
import type { ReactNode } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useSiteSettings } from '../hooks/useSiteSettings';

export function MaintenanceGate({ children }: { children: ReactNode }) {
  const { settings } = useSiteSettings();
  const { hash, pathname } = useLocation();
  const auth = useAuth();

  const mode = settings.behavior?.maintenance_mode;
  const onAdminRoute = pathname === '/admin' || hash === '#/admin';
  const authRoute =
    pathname === '/auth/callback' ||
    pathname === '/oauth/consent' ||
    hash === '#/auth/callback' ||
    hash.startsWith('#/oauth/consent');

  // No maintenance, or this admin user is bypassing, or we're on /admin so
  // editors can fix things — render the real app.
  if (!mode?.enabled || onAdminRoute || authRoute || (mode.allow_admin_bypass && auth.isAdmin)) {
    return <>{children}</>;
  }

  return (
    <div className="container" role="alert" aria-live="assertive">
      <div className="admin-panel" style={{ marginTop: 60, textAlign: 'center', padding: 48 }}>
        <h1 className="header-title" style={{ fontSize: '2rem' }}>
          {mode.title || 'Maintenance'}
        </h1>
        <p className="admin-muted" style={{ marginTop: 16, lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>
          {mode.message || 'We’ll be right back.'}
        </p>
        <p className="admin-muted" style={{ marginTop: 24, fontSize: '0.8rem' }}>
          <a href="#/admin">Admin login</a>
        </p>
      </div>
    </div>
  );
}

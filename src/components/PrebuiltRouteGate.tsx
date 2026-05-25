import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useSiteSettings } from '../hooks/useSiteSettings';
import { useAuth } from '../context/AuthContext';
import type { BehaviorConfig } from '../types';
import { SiteChrome } from './SiteChrome';

export type PrebuiltRouteFlag =
  | 'enable_services_page'
  | 'enable_apps_hub_page'
  | 'enable_vault_page'
  | 'enable_devlog_section';

const ROUTE_LABELS: Record<PrebuiltRouteFlag, string> = {
  enable_services_page: 'Services page',
  enable_apps_hub_page: 'Apps lab',
  enable_vault_page: 'Vault',
  enable_devlog_section: 'Dev log',
};

function isRouteEnabled(behavior: BehaviorConfig | undefined, flag: PrebuiltRouteFlag): boolean {
  const v = behavior?.[flag];
  return v !== false;
}

type Props = {
  flag: PrebuiltRouteFlag;
  children: ReactNode;
};

/**
 * Hides built-in hub routes when turned off in Admin → Behavior → Built-in pages.
 * Public visitors see a short "unavailable" card. Site admins still see the page
 * with a yellow banner so they can keep editing while it is hidden from the public.
 */
export function PrebuiltRouteGate({ flag, children }: Props) {
  const { settings } = useSiteSettings();
  const { isAdmin } = useAuth();
  const enabled = isRouteEnabled(settings.behavior, flag);

  if (enabled) return <>{children}</>;

  if (isAdmin) {
    return (
      <>
        <div
          style={{
            position: 'sticky',
            top: 0,
            zIndex: 60,
            padding: '10px 16px',
            background: 'rgba(255, 191, 95, 0.18)',
            borderBottom: '1px solid rgba(255, 191, 95, 0.55)',
            color: '#ffd9a3',
            fontSize: '0.85rem',
            textAlign: 'center',
          }}
          role="status"
        >
          <strong>{ROUTE_LABELS[flag]} is hidden from the public.</strong> Only signed-in admins see this. Turn it back on
          in <Link to="/admin">Admin → Behavior → Built-in pages</Link>.
        </div>
        {children}
      </>
    );
  }

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <div
        className="admin-panel"
        style={{
          maxWidth: 520,
          margin: '24px auto',
          textAlign: 'center',
          borderColor: 'rgba(115, 248, 255, 0.45)',
        }}
      >
        <h2 style={{ marginTop: 0, color: 'var(--accent)' }}>{ROUTE_LABELS[flag]} is offline</h2>
        <p className="admin-muted" style={{ margin: 0, lineHeight: 1.6 }}>
          We are polishing this section right now. Check back soon — or head{' '}
          <Link to="/">back to the main hub</Link> to keep exploring.
        </p>
      </div>
    </SiteChrome>
  );
}

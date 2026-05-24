import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useSiteSettings } from '../hooks/useSiteSettings';
import type { BehaviorConfig } from '../types';
import { SiteChrome } from './SiteChrome';

export type PrebuiltRouteFlag =
  | 'enable_services_page'
  | 'enable_apps_hub_page'
  | 'enable_vault_page'
  | 'enable_devlog_section';

function isRouteEnabled(behavior: BehaviorConfig | undefined, flag: PrebuiltRouteFlag): boolean {
  const v = behavior?.[flag];
  return v !== false;
}

type Props = {
  flag: PrebuiltRouteFlag;
  children: ReactNode;
};

/** Hides built-in hub routes when turned off in Admin → Behavior (public cannot view while editing). */
export function PrebuiltRouteGate({ flag, children }: Props) {
  const { settings } = useSiteSettings();
  if (isRouteEnabled(settings.behavior, flag)) {
    return <>{children}</>;
  }
  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <div className="admin-panel" style={{ maxWidth: 520, margin: '24px auto', textAlign: 'center' }}>
        <p className="admin-muted" style={{ margin: 0, lineHeight: 1.6 }}>
          This section is turned off in <strong>Admin → Behavior → Built-in pages</strong>. Visitors cannot see it
          while you edit. Turn it back on when you are ready to publish.
        </p>
      </div>
    </SiteChrome>
  );
}

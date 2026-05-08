import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { SiteSettings } from '../types';
import { defaultSiteSettings } from '../types';
import { fetchSiteSettings } from '../lib/cmsData';

export type SiteSettingsState = {
  settings: SiteSettings;
  /** True only after the first shared `fetchSiteSettings()` completes. */
  ready: boolean;
};

const SiteSettingsContext = createContext<SiteSettingsState | null>(null);

/** One shared load for the whole app (StrictMode-safe; avoids duplicate network calls). */
let siteSettingsPromise: Promise<SiteSettings> | null = null;
function loadSiteSettingsOnce(): Promise<SiteSettings> {
  if (!siteSettingsPromise) {
    siteSettingsPromise = fetchSiteSettings();
  }
  return siteSettingsPromise;
}

function SiteBootstrapSplash() {
  return (
    <div className="site-bootstrap-splash" role="status" aria-live="polite">
      <p className="site-bootstrap-splash__text">Loading site…</p>
    </div>
  );
}

/**
 * Fetches site settings once, then mounts children. Avoids showing default CMS copy
 * (one “website”) and then swapping to real settings (another “website”).
 */
export function SiteSettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<SiteSettings>(defaultSiteSettings);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    loadSiteSettingsOnce().then((s) => {
      if (!cancelled) {
        setSettings(s);
        setReady(true);
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const value = useMemo<SiteSettingsState>(() => ({ settings, ready }), [settings, ready]);

  if (!ready) {
    return <SiteBootstrapSplash />;
  }

  return <SiteSettingsContext.Provider value={value}>{children}</SiteSettingsContext.Provider>;
}

/** @internal — prefer `useSiteSettings` from `../hooks/useSiteSettings`. */
export function useSiteSettingsContext(): SiteSettingsState {
  const ctx = useContext(SiteSettingsContext);
  if (!ctx) {
    throw new Error('useSiteSettings must be used within SiteSettingsProvider');
  }
  return ctx;
}

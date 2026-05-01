import { useEffect, useState } from 'react';
import type { SiteSettings } from '../types';
import { defaultSiteSettings } from '../types';
import { fetchSiteSettings } from '../lib/cmsData';

export function useSiteSettings() {
  const [settings, setSettings] = useState<SiteSettings>(defaultSiteSettings);
  useEffect(() => {
    let cancelled = false;
    fetchSiteSettings().then((s) => {
      if (!cancelled) {
        setSettings(s);
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);
  return settings;
}

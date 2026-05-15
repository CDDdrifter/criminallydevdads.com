import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { setFirstPartyAnalyticsEnabled, trackPageView } from '../lib/analytics';
import { supabaseConfigured } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useSiteSettings } from '../hooks/useSiteSettings';

/** Records hash-router page views when first-party analytics is enabled. */
export function SiteAnalytics() {
  const location = useLocation();
  const auth = useAuth();
  const { settings } = useSiteSettings();

  useEffect(() => {
    const on =
      supabaseConfigured && settings.behavior?.first_party_analytics_enabled !== false;
    setFirstPartyAnalyticsEnabled(on);
  }, [settings.behavior?.first_party_analytics_enabled]);

  useEffect(() => {
    if (!supabaseConfigured || settings.behavior?.first_party_analytics_enabled === false) {
      return;
    }
    const path = `${location.pathname}${location.search}`;
    void trackPageView(path, auth.user?.id ?? null);
  }, [location.pathname, location.search, auth.user?.id, settings.behavior?.first_party_analytics_enabled]);

  return null;
}

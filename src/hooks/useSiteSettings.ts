import { useSiteSettingsContext } from '../context/SiteSettingsContext';

export type { SiteSettingsState } from '../context/SiteSettingsContext';

export function useSiteSettings() {
  return useSiteSettingsContext();
}

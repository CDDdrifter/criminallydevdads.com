import { useEffect } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';

const STYLE_ID = 'site-custom-css';

/**
 * Applies `SiteSettings.custom_css` from CMS. Trusted site-owner content only.
 */
export function SiteCustomCss() {
  const { settings } = useSiteSettings();

  useEffect(() => {
    const css = settings.custom_css.trim();
    let el = document.getElementById(STYLE_ID) as HTMLStyleElement | null;
    if (!css) {
      if (el) {
        el.textContent = '';
      }
      return;
    }
    if (!el) {
      el = document.createElement('style');
      el.id = STYLE_ID;
      document.head.appendChild(el);
    }
    el.textContent = css;
  }, [settings.custom_css]);

  return null;
}

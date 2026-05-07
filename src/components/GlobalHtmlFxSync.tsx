/**
 * Keeps <html> data attributes aligned with Site Settings and the current route.
 * - FX layer toggles: always from CMS (or defaults when offline).
 * - data-visual-preset: GamePage + PlayPage set it from the game row; elsewhere we apply site_visual_preset.
 */
import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { useSiteSettings } from '../hooks/useSiteSettings';
import { setDocumentFxFlags, setGlobalVisualPreset } from '../lib/siteFx';

export function GlobalHtmlFxSync() {
  const { pathname } = useLocation();
  const settings = useSiteSettings();

  useEffect(() => {
    setDocumentFxFlags(settings);
  }, [settings]);

  useEffect(() => {
    if (pathname.startsWith('/game/') || pathname.startsWith('/play/')) {
      return;
    }
    setGlobalVisualPreset(settings.site_visual_preset);
  }, [pathname, settings.site_visual_preset]);

  return null;
}

/**
 * SiteThemeApply
 *
 * Listens to the shared `SiteSettings` and applies the entire Admin Studio
 * output (theme, typography, layout, components, effects, SEO meta + head HTML
 * + analytics + favicon) every time the settings object changes.
 *
 * Mount once, near the top of the tree (after `SiteSettingsProvider`).
 *
 * The applier is idempotent: it tracks its own `<style>` / `<link>` /
 * `<script>` nodes by stable ids and overwrites them on each call.
 */
import { useEffect } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';
import { applyStudioTheme } from '../lib/themeApply';

export function SiteThemeApply() {
  const { settings } = useSiteSettings();
  useEffect(() => {
    applyStudioTheme(settings);
  }, [settings]);
  return null;
}

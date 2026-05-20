/**
 * Applies draft SiteSettings while editing Admin studio tabs so mood/theme/FX
 * preview matches what visitors will see after Save.
 */
import { useEffect } from 'react';
import type { SiteSettings } from '../../types';
import { setDocumentFxFlags, setGlobalVisualPreset } from '../../lib/siteFx';
import { applyStudioTheme } from '../../lib/themeApply';

type Props = {
  settings: SiteSettings;
  active: boolean;
};

export function AdminStudioPreview({ settings, active }: Props) {
  useEffect(() => {
    if (!active) return;
    applyStudioTheme(settings);
    setDocumentFxFlags(settings);
    setGlobalVisualPreset(settings.site_visual_preset);
  }, [settings, active]);
  return null;
}

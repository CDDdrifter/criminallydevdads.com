/**
 * Applies Site Settings visual FX flags to <html data-fx-*>, matching rules in index.css.
 * Global page mood (hub, devlog, etc.) uses data-visual-preset; /game/:slug is owned by GamePage.
 */
import type { FxIntensity, SiteSettings } from '../types';
import { normalizeVisualPresetInput } from './visualPresets';

function normalizeIntensity(i: FxIntensity | string | undefined): FxIntensity {
  const s = String(i ?? '').toLowerCase();
  if (s === 'subtle' || s === 'intense') {
    return s;
  }
  return 'normal';
}

export function setDocumentFxFlags(s: SiteSettings): void {
  const root = document.documentElement;
  root.dataset.fxScanlines = s.fx_scanlines ? 'on' : 'off';
  root.dataset.fxNoise = s.fx_noise ? 'on' : 'off';
  root.dataset.fxVignette = s.fx_vignette ? 'on' : 'off';
  root.dataset.fxHueShift = s.fx_hue_shift ? 'on' : 'off';
  root.dataset.fxCursorSpotlight = s.fx_cursor_spotlight ? 'on' : 'off';
  const inten = normalizeIntensity(s.fx_intensity);
  root.dataset.fxIntensity = inten;
}

/** Call on non–game-detail routes so hub picks up Admin “Site mood”. */
export function setGlobalVisualPreset(raw: string | null | undefined): void {
  const id = normalizeVisualPresetInput(raw);
  if (id) {
    document.documentElement.dataset.visualPreset = id;
  } else {
    delete document.documentElement.dataset.visualPreset;
  }
}

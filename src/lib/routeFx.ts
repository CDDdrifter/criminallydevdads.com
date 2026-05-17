/**
 * Per-route FX overrides (games / CMS pages). `inherit` on a field = site settings.
 */
import type { RouteFxOverride, RouteFxTriState, SiteSettings } from '../types';
import { normalizeVisualPresetInput, type VisualPresetId } from './visualPresets';

export type { RouteFxOverride, RouteFxTriState } from '../types';

export const ROUTE_FX_KEYS = [
  'scanlines',
  'noise',
  'vignette',
  'hue_shift',
  'cursor_spotlight',
] as const;

export function defaultRouteFxOverride(): RouteFxOverride {
  return {
    scanlines: 'inherit',
    noise: 'inherit',
    vignette: 'inherit',
    hue_shift: 'inherit',
    cursor_spotlight: 'inherit',
    intensity: 'inherit',
  };
}

function triToBool(state: RouteFxTriState | undefined, siteOn: boolean): boolean {
  if (state === 'on') {
    return true;
  }
  if (state === 'off') {
    return false;
  }
  return siteOn;
}

export function normalizeRouteFxOverride(raw: unknown): RouteFxOverride {
  const base = defaultRouteFxOverride();
  if (!raw || typeof raw !== 'object') {
    return base;
  }
  const o = raw as Record<string, unknown>;
  const pickTri = (k: keyof RouteFxOverride): RouteFxTriState => {
    const v = String(o[k] ?? 'inherit').toLowerCase();
    if (v === 'on' || v === 'off') {
      return v;
    }
    return 'inherit';
  };
  const intensityRaw = String(o.intensity ?? 'inherit').toLowerCase();
  const intensity: RouteFxOverride['intensity'] =
    intensityRaw === 'subtle' || intensityRaw === 'normal' || intensityRaw === 'intense'
      ? intensityRaw
      : 'inherit';
  return {
    scanlines: pickTri('scanlines'),
    noise: pickTri('noise'),
    vignette: pickTri('vignette'),
    hue_shift: pickTri('hue_shift'),
    cursor_spotlight: pickTri('cursor_spotlight'),
    intensity,
  };
}

export function mergeSiteFxWithRouteOverride(
  site: SiteSettings,
  route?: RouteFxOverride | null,
): SiteSettings {
  if (!route) {
    return site;
  }
  const intensity =
    route.intensity && route.intensity !== 'inherit' ? route.intensity : site.fx_intensity;
  return {
    ...site,
    fx_scanlines: triToBool(route.scanlines, site.fx_scanlines),
    fx_noise: triToBool(route.noise, site.fx_noise),
    fx_vignette: triToBool(route.vignette, site.fx_vignette),
    fx_hue_shift: triToBool(route.hue_shift, site.fx_hue_shift),
    fx_cursor_spotlight: triToBool(route.cursor_spotlight, site.fx_cursor_spotlight),
    fx_intensity: intensity,
  };
}

/** Route preset wins; empty route uses site hub mood. */
export function resolveVisualPreset(
  routeRaw: string | null | undefined,
  siteRaw: string | null | undefined,
): VisualPresetId {
  const route = normalizeVisualPresetInput(routeRaw);
  if (route) {
    return route;
  }
  return normalizeVisualPresetInput(siteRaw);
}

export function applyVisualPresetToDocument(preset: VisualPresetId): void {
  if (preset) {
    document.documentElement.dataset.visualPreset = preset;
  } else {
    delete document.documentElement.dataset.visualPreset;
  }
}

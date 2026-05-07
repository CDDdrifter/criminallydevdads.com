/**
 * Visual “moods” for the hub: CSS lives in index.css under html[data-visual-preset='…'].
 * Keep this list in sync with those selectors; Admin + site settings use the same options.
 */
export type VisualPresetId = '' | 'ember' | 'aurora' | 'noir' | 'minimal';

export const VISUAL_PRESET_OPTIONS: { value: VisualPresetId; label: string; hint: string }[] = [
  { value: '', label: 'Default', hint: 'Cyan / violet accents, full cursor glow (see Site settings toggles).' },
  { value: 'ember', label: 'Ember', hint: 'Warm orange / pink accents; warmer spotlight.' },
  { value: 'aurora', label: 'Aurora', hint: 'Mint / ice accents; green-tinted spotlight.' },
  { value: 'noir', label: 'Noir', hint: 'Muted silver / blue-gray; softer spotlight.' },
  {
    value: 'minimal',
    label: 'Minimal',
    hint: 'Keeps preset accents but dims the cursor glow layer (body::after opacity in CSS).',
  },
];

/** Only allow values that have CSS — prevents typos from leaving stale data-* on <html>. */
export function normalizeVisualPresetInput(raw: string | null | undefined): VisualPresetId {
  const s = String(raw ?? '').trim().toLowerCase();
  if (s === 'ember' || s === 'aurora' || s === 'noir' || s === 'minimal') {
    return s;
  }
  return '';
}

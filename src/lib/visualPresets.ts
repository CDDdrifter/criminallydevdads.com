/**
 * Visual “moods” for the hub: CSS lives in index.css under html[data-visual-preset='…'].
 * Multiple named palettes + `custom` (admin “Custom mood CSS” on each game/page).
 * Keep keys in sync with index.css; Admin, site settings, games, and CMS pages share this list.
 */
export type VisualPresetId =
  | ''
  | 'ember'
  | 'aurora'
  | 'noir'
  | 'minimal'
  | 'dawn'
  | 'nebula'
  | 'terminal'
  | 'ocean'
  | 'bloodline'
  | 'chroma'
  | 'sandstorm'
  | 'custom';

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
  { value: 'dawn', label: 'Dawn', hint: 'Soft peach / gold highlights; gentle sunrise glow.' },
  { value: 'nebula', label: 'Nebula', hint: 'Violet / teal deep-space accents.' },
  { value: 'terminal', label: 'Terminal', hint: 'Phosphor green on dark; retro console vibe.' },
  { value: 'ocean', label: 'Ocean', hint: 'Cool aqua / sea-blue accents.' },
  { value: 'bloodline', label: 'Bloodline', hint: 'Deep red / crimson accents (still readable).' },
  { value: 'chroma', label: 'Chroma', hint: 'Magenta + cyan synth accents.' },
  { value: 'sandstorm', label: 'Sandstorm', hint: 'Warm sand / amber; desert HUD feel.' },
  {
    value: 'custom',
    label: 'Custom (CSS)',
    hint: 'No preset palette — style with the “Custom mood CSS” field on this game or page.',
  },
];

const ALLOWED = new Set(VISUAL_PRESET_OPTIONS.map((o) => o.value).filter(Boolean));

/** Only allow values that have CSS — prevents typos from leaving stale data-* on <html>. */
export function normalizeVisualPresetInput(raw: string | null | undefined): VisualPresetId {
  const s = String(raw ?? '').trim().toLowerCase();
  if (ALLOWED.has(s as VisualPresetId)) {
    return s as VisualPresetId;
  }
  return '';
}

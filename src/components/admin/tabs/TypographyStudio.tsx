/**
 * TypographyStudio
 *
 * Edits font families (with optional Google Fonts URL), sizes, weights,
 * spacing, and link styling. Writes into `SiteSettings.typography`.
 */
import type { SiteSettings } from '../../../types';
import {
  FieldGroup,
  NumberSliderField,
  SelectField,
  TextAreaField,
  TextField,
} from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

/** A short curated list of stacks that read well on a dark game-y hub. Admin can override with anything. */
const FONT_STACKS: { label: string; value: string }[] = [
  { label: 'Consolas (default)', value: "'Consolas', 'Space Mono', 'Courier New', monospace" },
  { label: 'Space Mono', value: "'Space Mono', 'Courier New', monospace" },
  { label: 'JetBrains Mono', value: "'JetBrains Mono', 'Fira Code', 'Courier New', monospace" },
  { label: 'Fira Code', value: "'Fira Code', 'Courier New', monospace" },
  { label: 'Inter (UI sans-serif)', value: "'Inter', system-ui, sans-serif" },
  { label: 'System UI', value: 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif' },
  { label: 'Press Start 2P (pixel)', value: "'Press Start 2P', monospace" },
  { label: 'Orbitron (sci-fi)', value: "'Orbitron', 'Space Mono', sans-serif" },
  { label: 'VT323 (terminal)', value: "'VT323', 'Courier New', monospace" },
  { label: 'Audiowide (cyber)', value: "'Audiowide', 'Orbitron', sans-serif" },
  { label: 'Rubik Mono One', value: "'Rubik Mono One', monospace" },
];

export function TypographyStudio({ settings, setSettings }: Props) {
  const t = settings.typography;
  const set = (patch: Partial<typeof t>) => setSettings({ ...settings, typography: { ...t, ...patch } });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Fonts"
        tone="accent"
        description={
          <>
            Pick a quick stack or paste your own. To use a Google Font, paste the full{' '}
            <code>https://fonts.googleapis.com/css2?…</code> URL — the studio injects it as a
            <code> &lt;link&gt;</code> before any other stylesheet.
          </>
        }
      >
        <TextField
          label="Google Fonts URL (optional)"
          placeholder="https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap"
          value={t.google_fonts_url}
          onChange={(google_fonts_url) => set({ google_fonts_url })}
          monospace
          help={
            <>
              Multiple families allowed (Google&apos;s URL supports <code>&amp;family=</code>). After
              pasting the URL, plug each family name into the stacks below in quotes.
            </>
          }
        />
        <SelectField
          label="Body font preset"
          value={t.font_family_base}
          onChange={(font_family_base) => set({ font_family_base })}
          options={FONT_STACKS}
          help="Pick a built-in stack, then edit below if needed."
        />
        <TextField
          label="Body font family"
          value={t.font_family_base}
          onChange={(font_family_base) => set({ font_family_base })}
          monospace
        />
        <TextField
          label="Heading font family"
          value={t.font_family_heading}
          onChange={(font_family_heading) => set({ font_family_heading })}
          monospace
        />
        <TextField
          label="Monospace / code font family"
          value={t.font_family_mono}
          onChange={(font_family_mono) => set({ font_family_mono })}
          monospace
        />
      </FieldGroup>

      <FieldGroup title="Sizes">
        <NumberSliderField label="Base font size" unit="px" min={12} max={22} step={1} value={t.base_font_size_px} onChange={(base_font_size_px) => set({ base_font_size_px })} />
        <NumberSliderField label="Base line height" min={1.1} max={2.0} step={0.05} value={t.base_line_height} onChange={(base_line_height) => set({ base_line_height })} />
        <NumberSliderField label="Hero title size" unit="rem" min={1.4} max={6} step={0.05} value={t.hero_title_size_rem} onChange={(hero_title_size_rem) => set({ hero_title_size_rem })} />
        <NumberSliderField label="Hero subtitle size" unit="rem" min={0.6} max={2} step={0.05} value={t.hero_subtitle_size_rem} onChange={(hero_subtitle_size_rem) => set({ hero_subtitle_size_rem })} />
        <NumberSliderField label="Card title size" unit="rem" min={0.8} max={2.4} step={0.05} value={t.card_title_size_rem} onChange={(card_title_size_rem) => set({ card_title_size_rem })} />
      </FieldGroup>

      <FieldGroup title="Weight + spacing">
        <NumberSliderField label="Heading weight" min={300} max={900} step={100} value={t.heading_weight} onChange={(heading_weight) => set({ heading_weight })} />
        <NumberSliderField label="Body weight" min={300} max={900} step={100} value={t.body_weight} onChange={(body_weight) => set({ body_weight })} />
        <NumberSliderField label="Body letter spacing" unit="em" min={-0.05} max={0.2} step={0.005} value={t.letter_spacing_em} onChange={(letter_spacing_em) => set({ letter_spacing_em })} />
        <NumberSliderField label="Heading letter spacing" unit="em" min={0} max={0.5} step={0.005} value={t.heading_letter_spacing_em} onChange={(heading_letter_spacing_em) => set({ heading_letter_spacing_em })} />
        <SelectField
          label="Heading text transform"
          value={t.heading_text_transform}
          onChange={(heading_text_transform) => set({ heading_text_transform })}
          options={[
            { value: 'uppercase', label: 'UPPERCASE' },
            { value: 'capitalize', label: 'Capitalize' },
            { value: 'lowercase', label: 'lowercase' },
            { value: 'none', label: 'None (preserve case)' },
          ]}
        />
        <SelectField
          label="Link underline"
          value={t.link_underline}
          onChange={(link_underline) => set({ link_underline })}
          options={[
            { value: 'hover', label: 'On hover only' },
            { value: 'always', label: 'Always' },
            { value: 'never', label: 'Never' },
          ]}
        />
      </FieldGroup>

      <FieldGroup title="Hero title glow" description="Shadow stack applied to the homepage title.">
        <TextAreaField
          label="Heading text-shadow (CSS)"
          rows={4}
          monospace
          value={t.heading_text_shadow}
          onChange={(heading_text_shadow) => set({ heading_text_shadow })}
          help={<>e.g. <code>0 0 12px rgba(115, 248, 255, 0.35), 0 0 26px rgba(166, 115, 255, 0.22)</code></>}
        />
      </FieldGroup>
    </div>
  );
}

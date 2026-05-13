/**
 * ComponentsStudio
 *
 * Fine details of buttons, cards, panels, modals, promo cards. Writes into
 * `SiteSettings.components`.
 */
import type { SiteSettings } from '../../../types';
import {
  ColorField,
  FieldGroup,
  NumberSliderField,
  SelectField,
  TextAreaField,
  ToggleField,
} from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

export function ComponentsStudio({ settings, setSettings }: Props) {
  const c = settings.components;
  const set = <K extends keyof typeof c>(k: K, v: Partial<(typeof c)[K]>) => {
    const current = c[k];
    const next: typeof c = {
      ...c,
      [k]: typeof current === 'object' && current !== null ? { ...current, ...v } : current,
    } as typeof c;
    setSettings({ ...settings, components: next });
  };

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Game cards"
        tone="accent"
        description="Box shadows, padding, and per-card detail. Hover behaviour lives in the Effects tab."
      >
        <TextAreaField label="Default shadow (CSS)" rows={3} monospace value={c.card.shadow} onChange={(shadow) => set('card', { shadow })} help="The shadow before hover." />
        <TextAreaField label="Hover shadow (CSS)" rows={3} monospace value={c.card.hover_shadow} onChange={(hover_shadow) => set('card', { hover_shadow })} />
        <NumberSliderField label="Border width" unit="px" min={0} max={6} step={1} value={c.card.border_width_px} onChange={(border_width_px) => set('card', { border_width_px })} />
        <NumberSliderField label="Internal padding" unit="px" min={0} max={48} step={2} value={c.card.padding_px} onChange={(padding_px) => set('card', { padding_px })} />
        <NumberSliderField label="Title letter spacing" unit="em" min={-0.05} max={0.4} step={0.005} value={c.card.title_letter_spacing_em} onChange={(title_letter_spacing_em) => set('card', { title_letter_spacing_em })} />
      </FieldGroup>

      <FieldGroup title="Buttons">
        <NumberSliderField label="Vertical padding" unit="px" min={2} max={24} step={1} value={c.button.padding_v_px} onChange={(padding_v_px) => set('button', { padding_v_px })} />
        <NumberSliderField label="Horizontal padding" unit="px" min={4} max={48} step={1} value={c.button.padding_h_px} onChange={(padding_h_px) => set('button', { padding_h_px })} />
        <NumberSliderField label="Font size" unit="rem" min={0.6} max={1.4} step={0.02} value={c.button.font_size_rem} onChange={(font_size_rem) => set('button', { font_size_rem })} />
        <NumberSliderField label="Border width" unit="px" min={0} max={4} step={1} value={c.button.border_width_px} onChange={(border_width_px) => set('button', { border_width_px })} />
        <NumberSliderField label="Letter spacing" unit="em" min={-0.05} max={0.3} step={0.005} value={c.button.letter_spacing_em} onChange={(letter_spacing_em) => set('button', { letter_spacing_em })} />
        <NumberSliderField label="Hover translate Y" unit="px" min={-6} max={6} step={1} value={c.button.hover_translate_y_px} onChange={(hover_translate_y_px) => set('button', { hover_translate_y_px })} help="Negative = lifts up on hover." />
        <SelectField
          label="Text transform"
          value={c.button.text_transform}
          onChange={(text_transform) => set('button', { text_transform })}
          options={[
            { value: 'uppercase', label: 'UPPERCASE' },
            { value: 'lowercase', label: 'lowercase' },
            { value: 'none', label: 'None' },
          ]}
        />
      </FieldGroup>

      <FieldGroup title="Panels & promo cards">
        <NumberSliderField label="Panel backdrop blur" unit="px" min={0} max={32} step={1} value={c.panel.blur_px} onChange={(blur_px) => set('panel', { blur_px })} />
        <NumberSliderField label="Panel border width" unit="px" min={0} max={4} step={1} value={c.panel.border_width_px} onChange={(border_width_px) => set('panel', { border_width_px })} />
        <TextAreaField label="Promo card shadow (CSS)" rows={3} monospace value={c.panel.shadow} onChange={(shadow) => set('panel', { shadow })} />
        <ToggleField label="Promo card uses accent border" checked={c.promo_card.accent_border} onChange={(accent_border) => set('promo_card', { accent_border })} />
        <ToggleField label="Promo card title uppercase" checked={c.promo_card.title_uppercase} onChange={(title_uppercase) => set('promo_card', { title_uppercase })} />
      </FieldGroup>

      <FieldGroup title="Modals">
        <NumberSliderField label="Backdrop blur" unit="px" min={0} max={32} step={1} value={c.modal.backdrop_blur_px} onChange={(backdrop_blur_px) => set('modal', { backdrop_blur_px })} />
        <ColorField label="Backdrop colour" value={c.modal.backdrop_color} onChange={(backdrop_color) => set('modal', { backdrop_color })} />
        <NumberSliderField label="Max width" unit="px" min={320} max={1600} step={20} value={c.modal.width_max_px} onChange={(width_max_px) => set('modal', { width_max_px })} />
      </FieldGroup>
    </div>
  );
}

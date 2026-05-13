/**
 * LayoutStudio
 *
 * Container widths, paddings, border-radii, grid sizing, header/nav/footer
 * alignment. Writes into `SiteSettings.layout`.
 */
import type { SiteSettings } from '../../../types';
import { FieldGroup, NumberSliderField, SelectField } from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

export function LayoutStudio({ settings, setSettings }: Props) {
  const l = settings.layout;
  const set = (patch: Partial<typeof l>) => setSettings({ ...settings, layout: { ...l, ...patch } });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Page container"
        tone="accent"
        description="Controls the outermost wrapper width and body padding."
      >
        <NumberSliderField label="Max container width" unit="px" min={720} max={2400} step={20} value={l.container_max_width_px} onChange={(container_max_width_px) => set({ container_max_width_px })} />
        <NumberSliderField label="Body padding" unit="px" min={0} max={80} step={2} value={l.container_padding_px} onChange={(container_padding_px) => set({ container_padding_px })} />
        <NumberSliderField label="Base spacing" unit="px" min={4} max={48} step={2} value={l.base_padding_px} onChange={(base_padding_px) => set({ base_padding_px })} />
      </FieldGroup>

      <FieldGroup title="Header (hero block)">
        <NumberSliderField label="Vertical padding" unit="px" min={0} max={120} step={2} value={l.header_padding_v_px} onChange={(header_padding_v_px) => set({ header_padding_v_px })} />
        <NumberSliderField label="Horizontal padding" unit="px" min={0} max={120} step={2} value={l.header_padding_h_px} onChange={(header_padding_h_px) => set({ header_padding_h_px })} />
        <NumberSliderField label="Header bottom margin" unit="px" min={0} max={160} step={4} value={l.header_margin_bottom_px} onChange={(header_margin_bottom_px) => set({ header_margin_bottom_px })} />
        <SelectField
          label="Header text alignment"
          value={l.header_text_align}
          onChange={(header_text_align) => set({ header_text_align })}
          options={[
            { value: 'left', label: 'Left' },
            { value: 'center', label: 'Center' },
            { value: 'right', label: 'Right' },
          ]}
        />
      </FieldGroup>

      <FieldGroup title="Top navigation">
        <SelectField
          label="Nav alignment"
          value={l.nav_alignment}
          onChange={(nav_alignment) => set({ nav_alignment })}
          options={[
            { value: 'flex-start', label: 'Left' },
            { value: 'center', label: 'Center' },
            { value: 'flex-end', label: 'Right' },
            { value: 'space-between', label: 'Spread (space-between)' },
          ]}
        />
        <NumberSliderField label="Gap between nav buttons" unit="px" min={0} max={32} step={1} value={l.nav_gap_px} onChange={(nav_gap_px) => set({ nav_gap_px })} />
        <SelectField
          label="Nav position"
          value={l.nav_position}
          onChange={(nav_position) => set({ nav_position })}
          options={[
            { value: 'top', label: 'Normal (in flow)' },
            { value: 'sticky', label: 'Sticky at viewport top' },
          ]}
          help="Sticky pins the top bar with a subtle blur background."
        />
      </FieldGroup>

      <FieldGroup title="Game card grid">
        <NumberSliderField label="Card min width" unit="px" min={160} max={520} step={10} value={l.card_min_width_px} onChange={(card_min_width_px) => set({ card_min_width_px })} help="Controls how many columns auto-fit on wide screens." />
        <NumberSliderField label="Force columns" min={0} max={6} step={1} value={l.card_force_columns} onChange={(card_force_columns) => set({ card_force_columns })} help="0 = auto-fill from min width. 1+ forces an exact column count." />
        <NumberSliderField label="Gap" unit="px" min={4} max={64} step={1} value={l.card_gap_px} onChange={(card_gap_px) => set({ card_gap_px })} />
        <NumberSliderField label="Thumbnail height" unit="px" min={120} max={420} step={5} value={l.card_thumbnail_height_px} onChange={(card_thumbnail_height_px) => set({ card_thumbnail_height_px })} />
      </FieldGroup>

      <FieldGroup title="Corners (border radii)">
        <NumberSliderField label="Panels & cards" unit="px" min={0} max={36} step={1} value={l.border_radius_panel_px} onChange={(border_radius_panel_px) => set({ border_radius_panel_px })} />
        <NumberSliderField label="Game cards (override)" unit="px" min={0} max={36} step={1} value={l.border_radius_card_px} onChange={(border_radius_card_px) => set({ border_radius_card_px })} />
        <NumberSliderField label="Buttons" unit="px" min={0} max={32} step={1} value={l.border_radius_button_px} onChange={(border_radius_button_px) => set({ border_radius_button_px })} />
      </FieldGroup>

      <FieldGroup title="Footer">
        <SelectField
          label="Footer text alignment"
          value={l.footer_text_align}
          onChange={(footer_text_align) => set({ footer_text_align })}
          options={[
            { value: 'left', label: 'Left' },
            { value: 'center', label: 'Center' },
            { value: 'right', label: 'Right' },
          ]}
        />
        <NumberSliderField label="Footer padding" unit="px" min={0} max={120} step={2} value={l.footer_padding_px} onChange={(footer_padding_px) => set({ footer_padding_px })} />
      </FieldGroup>
    </div>
  );
}

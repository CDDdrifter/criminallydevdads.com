/**
 * BehaviorStudio
 *
 * Feature flags, maintenance mode, default homepage filter, and small UX
 * niceties (click sound, autoplay previews, homepage intro HTML). Writes
 * into `SiteSettings.behavior`.
 */
import type { SiteSettings } from '../../../types';
import {
  FieldGroup,
  NumberSliderField,
  SelectField,
  TextAreaField,
  TextField,
  ToggleField,
} from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

export function BehaviorStudio({ settings, setSettings }: Props) {
  const b = settings.behavior;
  const set = (patch: Partial<typeof b>) => setSettings({ ...settings, behavior: { ...b, ...patch } });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Maintenance mode"
        tone="danger"
        description={
          <>
            When enabled, every non-/admin route shows a maintenance card instead of the real page.
            Admin bypass keeps the studio reachable so you can disable it again.
          </>
        }
      >
        <ToggleField
          label="Enable maintenance mode"
          checked={b.maintenance_mode.enabled}
          onChange={(enabled) =>
            set({ maintenance_mode: { ...b.maintenance_mode, enabled } })
          }
          help="Hides all pages from public visitors."
        />
        <TextField
          label="Title"
          value={b.maintenance_mode.title}
          onChange={(title) => set({ maintenance_mode: { ...b.maintenance_mode, title } })}
          placeholder="We’ll be right back"
        />
        <TextAreaField
          label="Message"
          rows={4}
          value={b.maintenance_mode.message}
          onChange={(message) => set({ maintenance_mode: { ...b.maintenance_mode, message } })}
          help="Plain text. Newlines preserved."
        />
        <ToggleField
          label="Admins bypass maintenance"
          checked={b.maintenance_mode.allow_admin_bypass}
          onChange={(allow_admin_bypass) =>
            set({ maintenance_mode: { ...b.maintenance_mode, allow_admin_bypass } })
          }
          help="Recommended ON — without this you can lock yourself out."
        />
      </FieldGroup>

      <FieldGroup
        title="Visibility — what shows on the homepage"
        description="Toggle whole sections off without deleting them."
      >
        <ToggleField label="Show Vault nav link" checked={b.show_vault_link} onChange={(show_vault_link) => set({ show_vault_link })} />
        <ToggleField label="Show Dev log nav link" checked={b.show_devlog_link} onChange={(show_devlog_link) => set({ show_devlog_link })} />
        <ToggleField label="Show filter buttons (ALL / GAMES / ASSETS)" checked={b.show_filter_buttons} onChange={(show_filter_buttons) => set({ show_filter_buttons })} />
        <ToggleField label="Show support / donate section" checked={b.show_support_section} onChange={(show_support_section) => set({ show_support_section })} />
        <ToggleField label="Show footer" checked={b.show_footer} onChange={(show_footer) => set({ show_footer })} />
        <ToggleField
          label="Show ‘Admin / Team login’ link in top nav"
          checked={b.show_admin_link_in_nav}
          onChange={(show_admin_link_in_nav) => set({ show_admin_link_in_nav })}
          help="Independent of the VITE_SHOW_ADMIN_NAV build flag — set either to show the link."
        />
      </FieldGroup>

      <FieldGroup title="Homepage filter + hover">
        <SelectField
          label="Default game filter on load"
          value={b.default_game_filter}
          onChange={(default_game_filter) => set({ default_game_filter })}
          options={[
            { value: 'all', label: 'All' },
            { value: 'game', label: 'Games only' },
            { value: 'asset', label: 'Assets only' },
          ]}
        />
        <SelectField
          label="Card hover effect"
          value={b.game_card_hover_effect}
          onChange={(game_card_hover_effect) => set({ game_card_hover_effect })}
          options={[
            { value: 'lift', label: 'Lift (default)' },
            { value: 'shine', label: 'Shine sweep' },
            { value: 'glow', label: 'Glow' },
            { value: 'tilt', label: 'Tilt' },
            { value: 'pulse', label: 'Pulse outline' },
            { value: 'none', label: 'No hover effect' },
          ]}
        />
        <ToggleField
          label="Auto-play game preview videos on the homepage"
          checked={b.homepage_autoplay_previews}
          onChange={(homepage_autoplay_previews) => set({ homepage_autoplay_previews })}
          help="Hover-only autoplay; videos still respect mute/preload on cellular networks."
        />
      </FieldGroup>

      <FieldGroup title="Homepage intro banner">
        <ToggleField label="Show banner above hero" checked={b.homepage_intro.enabled} onChange={(enabled) => set({ homepage_intro: { ...b.homepage_intro, enabled } })} />
        <TextAreaField
          label="Banner HTML (trusted)"
          rows={6}
          monospace
          value={b.homepage_intro.html}
          onChange={(html) => set({ homepage_intro: { ...b.homepage_intro, html } })}
          help="Rendered as raw HTML — keep it tight. Plain text + simple tags."
        />
      </FieldGroup>

      <FieldGroup title="Click sound (optional)" description="Plays a short MP3 / WAV when nav buttons are clicked.">
        <TextField
          label="Audio URL"
          value={b.click_sound_url}
          onChange={(click_sound_url) => set({ click_sound_url })}
          placeholder="https://… (MP3 / WAV / OGG)"
          help="Leave empty to disable."
        />
        <NumberSliderField
          label="Volume"
          min={0}
          max={1}
          step={0.05}
          value={b.click_sound_volume}
          onChange={(click_sound_volume) => set({ click_sound_volume })}
        />
      </FieldGroup>
    </div>
  );
}

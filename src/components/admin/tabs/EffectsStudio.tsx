/**
 * EffectsStudio
 *
 * Fine-grained control of the visual FX layers. The legacy boolean toggles
 * (`fx_scanlines`, `fx_noise`, …) on `site_settings` still gate "on / off"
 * for back-compat; this tab tunes each layer's *look* (opacity, colour,
 * speed, etc.) via the new `effects` JSONB.
 *
 * Each section is one FX subsystem.
 */
import type { SiteSettings } from '../../../types';
import { VISUAL_PRESET_OPTIONS } from '../../../lib/visualPresets';
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

export function EffectsStudio({ settings, setSettings }: Props) {
  const fx = settings.effects;
  const set = <K extends keyof typeof fx>(k: K, v: Partial<(typeof fx)[K]>) => {
    const current = fx[k];
    // Only object sub-configs are mergeable; the `custom_css` string is
    // updated via a separate setter so this helper stays type-safe.
    const next: typeof fx = {
      ...fx,
      [k]: typeof current === 'object' && current !== null ? { ...current, ...v } : current,
    } as typeof fx;
    setSettings({ ...settings, effects: next });
  };

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <details className="admin-panel" style={{ borderStyle: 'solid', borderColor: 'rgba(115, 248, 255, 0.35)' }}>
        <summary style={{ cursor: 'pointer', fontWeight: 700, color: 'var(--accent)' }}>
          Visual systems inventory — what lives where
        </summary>
        <div className="admin-muted" style={{ marginTop: 12, fontSize: '0.82rem', lineHeight: 1.65 }}>
          <p style={{ margin: '0 0 10px' }}>
            <strong>This tab</strong> controls the CRT-style <em>overlay layers</em> (scanlines, grain, vignette, animated
            colour wash, cursor spotlight) plus title glitch, card entrance/hover, header edge sweep, scroll micro-jitter,
            and <strong>Effects → Custom CSS</strong>. Master on/off toggles mirror legacy <code>fx_*</code> site
            settings.
          </p>
          <p style={{ margin: '0 0 10px' }}>
            <strong>Theme</strong> — solid tokens (every colour), body gradient, radial accents, background image,{' '}
            <strong>looping background video</strong>, header glow, named presets.
          </p>
          <p style={{ margin: '0 0 10px' }}>
            <strong>Typography</strong> — Google Fonts import, families, sizes, hero title shadow, link underline.
            <br />
            <strong>Layout</strong> — container width, padding, card grid, thumbnail height, nav alignment (sticky/top).
            <br />
            <strong>Components</strong> — card/button/panel shadows, modal backdrop, promo chips.
            <br />
            <strong>Motion</strong> — page entrance presets, route transition fade, hero idle animation, button hover
            motion, promo strip entrance.
            <br />
            <strong>Media</strong> — ambient particles (density, speed, palette).
            <br />
            <strong>Brand / Hero</strong> — top brand strip (logo, tagline).
            <br />
            <strong>Behavior</strong> — game card hover style (lift/shine/glow/tilt/pulse), preview autoplay, click
            sound, homepage intro HTML.
            <br />
            <strong>System</strong> — forced high-contrast mode.
            <br />
            <strong>Site settings (legacy)</strong> — <code>Site Custom CSS</code> (global) and per-page / per-game{' '}
            <strong>Custom mood CSS</strong> in Pages / Games.
          </p>
          <p style={{ margin: 0 }}>
            <strong>Always-on shell</strong> — <code>SiteCursor</code>, <code>SiteAudio</code> (BGM / ambient),{' '}
            <code>SiteWatermark</code>, third-party analytics from <strong>SEO</strong>. Hash routes fire first-party{' '}
            <code>page_view</code>; HTML app pages also emit <code>app_open</code> (see Analytics tab after migration 021).
          </p>
        </div>
      </details>

      <FieldGroup
        title="🌐 Site mood (hub default)"
        tone="accent"
        description="Accent palette for Home, Vault, Dev log, and any route without its own mood. Games/Pages can override in their 🎨 Appearance panel."
      >
        <SelectField
          label="Hub mood preset"
          value={settings.site_visual_preset ?? ''}
          onChange={(site_visual_preset) => setSettings({ ...settings, site_visual_preset })}
          options={VISUAL_PRESET_OPTIONS.map((o) => ({
            value: o.value,
            label: o.label,
          }))}
        />
      </FieldGroup>

      <FieldGroup
        title="Master FX toggles"
        tone="accent"
        description={
          <>
            Big switches for each layer. Fine controls below only paint while the layer is on.
            Per-game/page overrides live in <strong>🎨 Appearance</strong> on Games / Pages tabs.
          </>
        }
      >
        <ToggleField
          label="Scanlines"
          checked={settings.fx_scanlines}
          onChange={(fx_scanlines) => setSettings({ ...settings, fx_scanlines })}
        />
        <ToggleField
          label="Noise / grain"
          checked={settings.fx_noise}
          onChange={(fx_noise) => setSettings({ ...settings, fx_noise })}
        />
        <ToggleField
          label="Vignette"
          checked={settings.fx_vignette}
          onChange={(fx_vignette) => setSettings({ ...settings, fx_vignette })}
        />
        <ToggleField
          label="Hue-shift colour wash"
          checked={settings.fx_hue_shift}
          onChange={(fx_hue_shift) => setSettings({ ...settings, fx_hue_shift })}
        />
        <ToggleField
          label="Cursor spotlight"
          checked={settings.fx_cursor_spotlight}
          onChange={(fx_cursor_spotlight) => setSettings({ ...settings, fx_cursor_spotlight })}
        />
        <SelectField
          label="Coarse intensity multiplier"
          value={settings.fx_intensity}
          onChange={(fx_intensity) => setSettings({ ...settings, fx_intensity })}
          options={[
            { value: 'subtle', label: 'Subtle' },
            { value: 'normal', label: 'Normal' },
            { value: 'intense', label: 'Intense' },
          ]}
          help={<>Quick dial for everyone; overrides the legacy CSS scales in <code>index.css</code>.</>}
        />
      </FieldGroup>

      <FieldGroup title="Scanlines">
        <ToggleField label="Enabled" checked={fx.scanlines.enabled} onChange={(enabled) => set('scanlines', { enabled })} />
        <NumberSliderField label="Opacity" min={0} max={1} step={0.01} value={fx.scanlines.opacity} onChange={(opacity) => set('scanlines', { opacity })} />
        <ColorField label="Line colour" value={fx.scanlines.line_color} onChange={(line_color) => set('scanlines', { line_color })} />
        <ColorField label="Gap colour" value={fx.scanlines.gap_color} onChange={(gap_color) => set('scanlines', { gap_color })} />
        <NumberSliderField label="Spacing" unit="px" min={2} max={20} step={1} value={fx.scanlines.spacing_px} onChange={(spacing_px) => set('scanlines', { spacing_px })} />
      </FieldGroup>

      <FieldGroup title="Noise / grain">
        <ToggleField label="Enabled" checked={fx.noise.enabled} onChange={(enabled) => set('noise', { enabled })} />
        <NumberSliderField label="Opacity" min={0} max={0.3} step={0.005} value={fx.noise.opacity} onChange={(opacity) => set('noise', { opacity })} />
        <NumberSliderField label="Dot size" unit="px" min={1} max={10} step={1} value={fx.noise.size_px} onChange={(size_px) => set('noise', { size_px })} />
        <NumberSliderField label="Speed" unit="s per frame" min={0.05} max={2} step={0.01} value={fx.noise.speed_s} onChange={(speed_s) => set('noise', { speed_s })} />
        <ColorField label="Grain colour" value={fx.noise.color} onChange={(color) => set('noise', { color })} />
      </FieldGroup>

      <FieldGroup title="Vignette">
        <ToggleField label="Enabled" checked={fx.vignette.enabled} onChange={(enabled) => set('vignette', { enabled })} />
        <NumberSliderField label="Opacity" min={0} max={1} step={0.01} value={fx.vignette.opacity} onChange={(opacity) => set('vignette', { opacity })} />
        <NumberSliderField label="Inner clear stop" unit="%" min={0} max={90} step={1} value={fx.vignette.inner_stop} onChange={(inner_stop) => set('vignette', { inner_stop })} help="The radius where the dark edge starts." />
        <ColorField label="Edge colour" value={fx.vignette.color} onChange={(color) => set('vignette', { color })} help="Defaults to a dark rgba — set to red for horror mood." />
      </FieldGroup>

      <FieldGroup title="Hue-shift wash">
        <ToggleField label="Enabled" checked={fx.hue_shift.enabled} onChange={(enabled) => set('hue_shift', { enabled })} />
        <NumberSliderField label="Opacity" min={0} max={1} step={0.01} value={fx.hue_shift.opacity} onChange={(opacity) => set('hue_shift', { opacity })} />
        <NumberSliderField label="Speed" unit="s per loop" min={1} max={60} step={0.5} value={fx.hue_shift.speed_s} onChange={(speed_s) => set('hue_shift', { speed_s })} />
        <ColorField label="Stop A" value={fx.hue_shift.color_a} onChange={(color_a) => set('hue_shift', { color_a })} />
        <ColorField label="Stop B" value={fx.hue_shift.color_b} onChange={(color_b) => set('hue_shift', { color_b })} />
        <ColorField label="Stop C" value={fx.hue_shift.color_c} onChange={(color_c) => set('hue_shift', { color_c })} />
        <SelectField
          label="Blend mode"
          value={fx.hue_shift.blend}
          onChange={(blend) => set('hue_shift', { blend })}
          options={[
            { value: 'screen', label: 'Screen (lighten)' },
            { value: 'overlay', label: 'Overlay' },
            { value: 'multiply', label: 'Multiply (darken)' },
            { value: 'soft-light', label: 'Soft light' },
            { value: 'hard-light', label: 'Hard light' },
            { value: 'normal', label: 'Normal' },
          ]}
        />
      </FieldGroup>

      <FieldGroup title="Cursor spotlight">
        <ToggleField label="Enabled" checked={fx.cursor_spotlight.enabled} onChange={(enabled) => set('cursor_spotlight', { enabled })} />
        <ColorField label="Spotlight colour" value={fx.cursor_spotlight.color} onChange={(color) => set('cursor_spotlight', { color })} help="rgba — keep alpha low (≤0.2) so it doesn’t wash out content." />
        <NumberSliderField label="Opacity multiplier" min={0} max={1.5} step={0.01} value={fx.cursor_spotlight.opacity} onChange={(opacity) => set('cursor_spotlight', { opacity })} />
        <NumberSliderField label="Radius X" unit="px" min={200} max={2400} step={20} value={fx.cursor_spotlight.radius_x_px} onChange={(radius_x_px) => set('cursor_spotlight', { radius_x_px })} />
        <NumberSliderField label="Radius Y" unit="px" min={200} max={2000} step={20} value={fx.cursor_spotlight.radius_y_px} onChange={(radius_y_px) => set('cursor_spotlight', { radius_y_px })} />
      </FieldGroup>

      <FieldGroup title="Title glitch">
        <ToggleField label="Enabled" checked={fx.title_glitch.enabled} onChange={(enabled) => set('title_glitch', { enabled })} />
        <NumberSliderField label="Jitter intensity" unit="px" min={0} max={6} step={1} value={fx.title_glitch.intensity_px} onChange={(intensity_px) => set('title_glitch', { intensity_px })} />
        <NumberSliderField label="Period" unit="s" min={1} max={20} step={0.5} value={fx.title_glitch.period_s} onChange={(period_s) => set('title_glitch', { period_s })} />
      </FieldGroup>

      <FieldGroup title="Card-in animation">
        <ToggleField label="Enabled" checked={fx.card_in_animation.enabled} onChange={(enabled) => set('card_in_animation', { enabled })} />
        <NumberSliderField label="Duration" unit="ms" min={0} max={2000} step={25} value={fx.card_in_animation.duration_ms} onChange={(duration_ms) => set('card_in_animation', { duration_ms })} />
        <NumberSliderField label="Stagger between cards" unit="ms" min={0} max={500} step={5} value={fx.card_in_animation.stagger_ms} onChange={(stagger_ms) => set('card_in_animation', { stagger_ms })} />
      </FieldGroup>

      <FieldGroup title="Card hover effect">
        <ToggleField label="Enabled" checked={fx.card_hover.enabled} onChange={(enabled) => set('card_hover', { enabled })} />
        <NumberSliderField label="Lift" unit="px" min={0} max={24} step={1} value={fx.card_hover.lift_px} onChange={(lift_px) => set('card_hover', { lift_px })} />
        <NumberSliderField label="Skew" unit="deg" min={0} max={3} step={0.1} value={fx.card_hover.skew_deg} onChange={(skew_deg) => set('card_hover', { skew_deg })} />
        <ColorField label="Glow colour" value={fx.card_hover.glow_color} onChange={(glow_color) => set('card_hover', { glow_color })} />
        <NumberSliderField label="Glow strength" unit="px blur" min={0} max={80} step={1} value={fx.card_hover.glow_strength} onChange={(glow_strength) => set('card_hover', { glow_strength })} />
        <ToggleField label="Shine sweep across card" checked={fx.card_hover.shine} onChange={(shine) => set('card_hover', { shine })} />
      </FieldGroup>

      <FieldGroup title="Edge sweep + scroll micro-jitter">
        <ToggleField label="Header edge sweep" checked={fx.edge_sweep.enabled} onChange={(enabled) => set('edge_sweep', { enabled })} />
        <ColorField label="Sweep colour" value={fx.edge_sweep.color} onChange={(color) => set('edge_sweep', { color })} help="Defaults to var(--accent)." />
        <NumberSliderField label="Sweep period" unit="s" min={1} max={20} step={0.5} value={fx.edge_sweep.period_s} onChange={(period_s) => set('edge_sweep', { period_s })} />
        <ToggleField label="Body jitter while scrolling" checked={fx.scroll_jitter.enabled} onChange={(enabled) => set('scroll_jitter', { enabled })} help="Tiny CRT bounce when you scroll." />
        <ToggleField label="Honour OS reduce-motion" checked={fx.reduce_motion.honor_prefers} onChange={(honor_prefers) => set('reduce_motion', { honor_prefers })} help="Recommended on — disables every animation when the OS asks for less motion." />
      </FieldGroup>

      <FieldGroup
        title="Advanced — extra CSS"
        tone="danger"
        description="Two injection points: Effects CSS (studio-generated rules) and Global site CSS (legacy SiteCustomCss)."
      >
        <TextAreaField
          label="⚡ Effects custom CSS"
          rows={10}
          monospace
          value={fx.custom_css}
          onChange={(custom_css) => setSettings({ ...settings, effects: { ...fx, custom_css } })}
          help={<>Appended after generated FX rules from this tab.</>}
        />
        <TextAreaField
          label="🌐 Global site CSS"
          rows={10}
          monospace
          value={settings.custom_css}
          onChange={(custom_css) => setSettings({ ...settings, custom_css })}
          help={<>Injected by SiteCustomCss — targets .container, .game-card, .top-nav, etc.</>}
        />
      </FieldGroup>
    </div>
  );
}

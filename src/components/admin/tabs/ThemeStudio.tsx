/**
 * ThemeStudio
 *
 * Admin panel that paints every named colour token in the site, plus the
 * body background gradient + radial accent + optional background image, looping
 * body video, and header glow. Wired into `SiteSettings.theme` (see `types.ts`).
 *
 * Layout:
 *   1. Master switch + display name + preset picker.
 *   2. Background — gradient builder, radial accent, image, video, header glow.
 *   3. Core tokens — every grouped colour the site uses.
 *
 * All controls are reactive: editing any field updates the parent state and
 * `SiteThemeApply` repaints the page live (the studio tab is rendered behind
 * a transparent admin shell so users can see their changes immediately).
 */
import { useMemo } from 'react';
import type { SiteSettings, ThemeConfig, ThemePreset } from '../../../types';
import {
  defaultThemeBackgrounds,
  defaultThemeColors,
} from '../../../lib/themeDefaults';
import { BUILTIN_THEME_PRESETS } from '../../../lib/themePresets';
import {
  ColorField,
  FieldGroup,
  NumberSliderField,
  SelectField,
  TextField,
  ToggleField,
} from '../StudioFields';
import { GradientBuilder } from '../GradientBuilder';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
  /** Optional preset save callback — receives a fresh ThemePreset for `theme_presets`. */
  onSavePreset?: (preset: ThemePreset) => void;
};

const ALPHA_PALETTE = [
  '#73f8ff',
  '#a673ff',
  '#ff5fbf',
  '#3ecf8e',
  '#ffd166',
  '#ff8787',
  '#7dffb3',
  '#fcc419',
  '#88ccff',
  '#39ff14',
  '#ffffff',
  '#000000',
];

export function ThemeStudio({ settings, setSettings, onSavePreset }: Props) {
  const theme = settings.theme;
  const presets = useMemo<ThemePreset[]>(
    () => [...BUILTIN_THEME_PRESETS, ...(settings.theme_presets ?? [])],
    [settings.theme_presets],
  );

  const setTheme = (patch: Partial<ThemeConfig>) =>
    setSettings({ ...settings, theme: { ...theme, ...patch } });
  const setColors = (patch: Partial<typeof theme.colors>) =>
    setTheme({ colors: { ...theme.colors, ...patch } });
  const setBackground = (patch: Partial<typeof theme.background>) =>
    setTheme({ background: { ...theme.background, ...patch } });

  const applyPreset = (id: string) => {
    const p = presets.find((x) => x.id === id);
    if (!p) return;
    setTheme({
      display_name: p.theme.display_name,
      colors: { ...p.theme.colors },
      background: { ...p.theme.background },
      enabled: true,
    });
  };

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Studio theme"
        tone="accent"
        description={
          <>
            Master switch for the custom theme. When <strong>enabled</strong>, this overrides the
            cyber-violet defaults baked into <code>src/index.css</code> for every page (game / play
            views still apply their own per-game mood on top).
          </>
        }
      >
        <ToggleField
          label="Use Admin Studio theme site-wide"
          checked={theme.enabled}
          onChange={(v) => setTheme({ enabled: v })}
          help={
            theme.enabled
              ? 'Studio colours are live across the site.'
              : 'Currently disabled — the original cyber-violet palette renders.'
          }
        />
        <TextField
          label="Display name"
          value={theme.display_name}
          onChange={(display_name) => setTheme({ display_name })}
          placeholder="My Theme"
          help="Shown above the colour pickers and saved with exported presets."
        />
        <SelectField
          label="Quick preset"
          value=""
          onChange={(id) => applyPreset(id)}
          options={[
            { value: '', label: '— Apply a built-in preset —' },
            ...presets.map((p) => ({ value: p.id, label: p.name, hint: p.description })),
          ]}
          help={
            <>
              Pick a starting point. Picking a preset overwrites every colour token below but keeps
              your effects, typography and layout untouched.
            </>
          }
        />
        <div className="admin-row" style={{ gap: 8, flexWrap: 'wrap' }}>
          <button
            type="button"
            onClick={() =>
              setTheme({
                colors: defaultThemeColors(),
                background: defaultThemeBackgrounds(),
              })
            }
          >
            Reset to defaults
          </button>
          {onSavePreset ? (
            <button
              type="button"
              onClick={() => {
                const name =
                  prompt(
                    'Name this theme preset (saved in CMS so the team can switch to it later):',
                    theme.display_name || 'My theme',
                  )?.trim();
                if (!name) return;
                onSavePreset({
                  id: `user-${Date.now().toString(36)}`,
                  name,
                  description: 'Saved by an admin from the Theme Studio.',
                  theme: {
                    display_name: name,
                    colors: { ...theme.colors },
                    background: { ...theme.background },
                  },
                });
              }}
            >
              Save current colours as preset
            </button>
          ) : null}
        </div>
      </FieldGroup>

      <FieldGroup
        title="Body background"
        description={
          <>
            The body gradient + an optional radial accent overlay + an optional background image
            (in front, behind FX layers). Stops are rendered in order from 0 → 100. Studio rules
            override the <code>body {'{'} background {'}'}</code> declaration in
            <code> src/index.css</code>.
          </>
        }
      >
        <GradientBuilder
          label="Body gradient"
          value={theme.background.body_gradient}
          onChange={(body_gradient) => setBackground({ body_gradient })}
          description="Base gradient painted under all FX layers."
        />

        <div className="admin-panel" style={{ borderStyle: 'dashed' }}>
          <h3
            style={{
              fontSize: '0.85rem',
              textTransform: 'uppercase',
              color: 'var(--muted)',
              marginBottom: 8,
            }}
          >
            Radial accent overlay
          </h3>
          <ToggleField
            label="Show radial accent"
            checked={theme.background.body_radial_accent.enabled}
            onChange={(enabled) =>
              setBackground({
                body_radial_accent: { ...theme.background.body_radial_accent, enabled },
              })
            }
            help="A soft circular glow over the body gradient (e.g. top-right purple wash)."
          />
          {theme.background.body_radial_accent.enabled ? (
            <>
              <ColorField
                label="Accent colour"
                value={theme.background.body_radial_accent.color}
                presets={ALPHA_PALETTE}
                onChange={(color) =>
                  setBackground({
                    body_radial_accent: { ...theme.background.body_radial_accent, color },
                  })
                }
              />
              <TextField
                label="Size"
                value={theme.background.body_radial_accent.size}
                onChange={(size) =>
                  setBackground({
                    body_radial_accent: { ...theme.background.body_radial_accent, size },
                  })
                }
                monospace
                placeholder="800px 600px"
              />
              <TextField
                label="Position"
                value={theme.background.body_radial_accent.position}
                onChange={(position) =>
                  setBackground({
                    body_radial_accent: { ...theme.background.body_radial_accent, position },
                  })
                }
                monospace
                placeholder="85% 10%"
              />
              <NumberSliderField
                label="Falloff"
                unit="% transparent at edge"
                min={20}
                max={95}
                step={1}
                value={theme.background.body_radial_accent.falloff}
                onChange={(falloff) =>
                  setBackground({
                    body_radial_accent: { ...theme.background.body_radial_accent, falloff },
                  })
                }
              />
            </>
          ) : null}
        </div>

        <div className="admin-panel" style={{ borderStyle: 'dashed' }}>
          <h3
            style={{
              fontSize: '0.85rem',
              textTransform: 'uppercase',
              color: 'var(--muted)',
              marginBottom: 8,
            }}
          >
            Background image
          </h3>
          <TextField
            label="Image URL"
            value={theme.background.body_image_url}
            onChange={(body_image_url) => setBackground({ body_image_url })}
            placeholder="https://… or leave blank for none"
            help="Painted on top of the gradient (and behind FX layers). Big PNG/JPG/SVG OK."
          />
          {theme.background.body_image_url.trim() ? (
            <>
              <SelectField
                label="Image sizing"
                value={theme.background.body_image_size}
                onChange={(body_image_size) => setBackground({ body_image_size })}
                options={[
                  { value: 'cover', label: 'Cover (fill viewport)' },
                  { value: 'contain', label: 'Contain (fit inside)' },
                  { value: 'auto', label: 'Auto (natural size)' },
                  { value: 'repeat', label: 'Tile / repeat' },
                ]}
              />
              <SelectField
                label="Blend mode"
                value={theme.background.body_image_blend}
                onChange={(body_image_blend) => setBackground({ body_image_blend })}
                options={[
                  { value: 'normal', label: 'Normal (replace)' },
                  { value: 'screen', label: 'Screen (lighten)' },
                  { value: 'overlay', label: 'Overlay' },
                  { value: 'multiply', label: 'Multiply (darken)' },
                  { value: 'soft-light', label: 'Soft light' },
                  { value: 'hard-light', label: 'Hard light' },
                  { value: 'difference', label: 'Difference' },
                ]}
                help="Controls how the image mixes with the gradient underneath."
              />
              <NumberSliderField
                label="Opacity"
                min={0}
                max={1}
                step={0.01}
                value={theme.background.body_image_opacity}
                onChange={(body_image_opacity) => setBackground({ body_image_opacity })}
              />
              <ToggleField
                label="Fixed (scroll with body off)"
                checked={theme.background.body_image_fixed}
                onChange={(body_image_fixed) => setBackground({ body_image_fixed })}
              />
            </>
          ) : null}
        </div>

        <div className="admin-panel" style={{ borderStyle: 'dashed' }}>
          <h3
            style={{
              fontSize: '0.85rem',
              textTransform: 'uppercase',
              color: 'var(--muted)',
              marginBottom: 8,
            }}
          >
            Background video (animated)
          </h3>
          <ToggleField
            label="Show looping video behind the site"
            checked={theme.background.body_video.enabled}
            onChange={(enabled) =>
              setBackground({
                body_video: { ...theme.background.body_video, enabled },
              })
            }
            help="Requires Studio theme master switch ON. Uses a muted, looping &lt;video&gt; under your gradient + FX. Upload .webm or .mp4 to Supabase Storage or any https URL."
          />
          {theme.background.body_video.enabled ? (
            <>
              <TextField
                label="Video URL"
                value={theme.background.body_video.url}
                onChange={(url) =>
                  setBackground({
                    body_video: { ...theme.background.body_video, url },
                  })
                }
                placeholder="https://….supabase.co/storage/…/bg.webm"
              />
              <NumberSliderField
                label="Video opacity"
                min={0}
                max={1}
                step={0.02}
                value={theme.background.body_video.opacity}
                onChange={(opacity) =>
                  setBackground({
                    body_video: { ...theme.background.body_video, opacity },
                  })
                }
              />
              <NumberSliderField
                label="Blur (px)"
                min={0}
                max={24}
                step={1}
                value={theme.background.body_video.blur_px}
                onChange={(blur_px) =>
                  setBackground({
                    body_video: { ...theme.background.body_video, blur_px },
                  })
                }
                help="Softens busy footage so text stays readable."
              />
            </>
          ) : null}
        </div>

        <div className="admin-panel" style={{ borderStyle: 'dashed' }}>
          <h3
            style={{
              fontSize: '0.85rem',
              textTransform: 'uppercase',
              color: 'var(--muted)',
              marginBottom: 8,
            }}
          >
            Header glow
          </h3>
          <ToggleField
            label="Show header glow"
            checked={theme.background.header_glow.enabled}
            onChange={(enabled) =>
              setBackground({
                header_glow: { ...theme.background.header_glow, enabled },
              })
            }
            help="Soft radial light inside the hero header card."
          />
          {theme.background.header_glow.enabled ? (
            <>
              <ColorField
                label="Glow colour"
                value={theme.background.header_glow.color}
                presets={ALPHA_PALETTE}
                onChange={(color) =>
                  setBackground({
                    header_glow: { ...theme.background.header_glow, color },
                  })
                }
              />
              <TextField
                label="Size"
                value={theme.background.header_glow.size}
                onChange={(size) =>
                  setBackground({ header_glow: { ...theme.background.header_glow, size } })
                }
                monospace
              />
              <TextField
                label="Position"
                value={theme.background.header_glow.position}
                onChange={(position) =>
                  setBackground({
                    header_glow: { ...theme.background.header_glow, position },
                  })
                }
                monospace
              />
              <NumberSliderField
                label="Opacity"
                min={0}
                max={1}
                step={0.01}
                value={theme.background.header_glow.opacity}
                onChange={(opacity) =>
                  setBackground({ header_glow: { ...theme.background.header_glow, opacity } })
                }
              />
            </>
          ) : null}
        </div>
      </FieldGroup>

      <FieldGroup
        title="Core palette"
        description={
          <>
            The 12 primary tokens that drive accents, backgrounds and text. Every page on the site
            reads from these via CSS variables.
          </>
        }
      >
        <ColorField label="Background 0 (top)" value={theme.colors.bg_0} onChange={(bg_0) => setColors({ bg_0 })} presets={ALPHA_PALETTE} />
        <ColorField label="Background 1 (bottom)" value={theme.colors.bg_1} onChange={(bg_1) => setColors({ bg_1 })} presets={ALPHA_PALETTE} />
        <ColorField label="Panel background" value={theme.colors.panel} onChange={(panel) => setColors({ panel })} help="rgba — alpha lets the gradient bleed through." />
        <ColorField label="Panel (strong)" value={theme.colors.panel_strong} onChange={(panel_strong) => setColors({ panel_strong })} />
        <ColorField label="Text" value={theme.colors.text} onChange={(text) => setColors({ text })} />
        <ColorField label="Text (strong / heading)" value={theme.colors.text_strong} onChange={(text_strong) => setColors({ text_strong })} />
        <ColorField label="Muted text" value={theme.colors.muted} onChange={(muted) => setColors({ muted })} />
        <ColorField label="Accent 1" value={theme.colors.accent} onChange={(accent) => setColors({ accent })} presets={ALPHA_PALETTE} />
        <ColorField label="Accent 2" value={theme.colors.accent_2} onChange={(accent_2) => setColors({ accent_2 })} presets={ALPHA_PALETTE} />
        <ColorField label="Danger" value={theme.colors.danger} onChange={(danger) => setColors({ danger })} />
        <ColorField label="Success" value={theme.colors.success} onChange={(success) => setColors({ success })} />
        <ColorField label="Warning" value={theme.colors.warning} onChange={(warning) => setColors({ warning })} />
        <ColorField label="Border" value={theme.colors.border} onChange={(border) => setColors({ border })} />
        <ColorField label="Link" value={theme.colors.link} onChange={(link) => setColors({ link })} />
        <ColorField label="Link hover" value={theme.colors.link_hover} onChange={(link_hover) => setColors({ link_hover })} />
      </FieldGroup>

      <FieldGroup title="Game card colours">
        <ColorField label="Card gradient — top" value={theme.colors.card_bg_a} onChange={(card_bg_a) => setColors({ card_bg_a })} />
        <ColorField label="Card gradient — bottom" value={theme.colors.card_bg_b} onChange={(card_bg_b) => setColors({ card_bg_b })} />
        <ColorField label="Card border" value={theme.colors.card_border} onChange={(card_border) => setColors({ card_border })} />
        <ColorField label="Card hover border" value={theme.colors.card_hover_border} onChange={(card_hover_border) => setColors({ card_hover_border })} />
        <ColorField label="Tag pill — start" value={theme.colors.tag_bg_a} onChange={(tag_bg_a) => setColors({ tag_bg_a })} />
        <ColorField label="Tag pill — end" value={theme.colors.tag_bg_b} onChange={(tag_bg_b) => setColors({ tag_bg_b })} />
        <ColorField label="Tag text" value={theme.colors.tag_text} onChange={(tag_text) => setColors({ tag_text })} />
      </FieldGroup>

      <FieldGroup title="Header + footer">
        <ColorField label="Header background" value={theme.colors.header_bg} onChange={(header_bg) => setColors({ header_bg })} />
        <ColorField label="Header border" value={theme.colors.header_border} onChange={(header_border) => setColors({ header_border })} />
        <ColorField label="Hero title colour" value={theme.colors.header_title_color} onChange={(header_title_color) => setColors({ header_title_color })} />
        <ColorField label="Hero subtitle colour" value={theme.colors.header_subtitle_color} onChange={(header_subtitle_color) => setColors({ header_subtitle_color })} />
        <ColorField label="Footer text" value={theme.colors.footer_text_color} onChange={(footer_text_color) => setColors({ footer_text_color })} />
      </FieldGroup>

      <FieldGroup title="Top navigation buttons">
        <ColorField label="Nav button bg" value={theme.colors.nav_button_bg} onChange={(nav_button_bg) => setColors({ nav_button_bg })} />
        <ColorField label="Nav button text" value={theme.colors.nav_button_text} onChange={(nav_button_text) => setColors({ nav_button_text })} />
        <ColorField label="Nav button border" value={theme.colors.nav_button_border} onChange={(nav_button_border) => setColors({ nav_button_border })} />
        <ColorField label="Hover bg start" value={theme.colors.nav_button_hover_bg_a} onChange={(nav_button_hover_bg_a) => setColors({ nav_button_hover_bg_a })} />
        <ColorField label="Hover bg end" value={theme.colors.nav_button_hover_bg_b} onChange={(nav_button_hover_bg_b) => setColors({ nav_button_hover_bg_b })} />
        <ColorField label="Hover text" value={theme.colors.nav_button_hover_text} onChange={(nav_button_hover_text) => setColors({ nav_button_hover_text })} />
      </FieldGroup>

      <FieldGroup title="Generic buttons (filters, forms)">
        <ColorField label="Bg" value={theme.colors.button_bg} onChange={(button_bg) => setColors({ button_bg })} />
        <ColorField label="Text" value={theme.colors.button_text} onChange={(button_text) => setColors({ button_text })} />
        <ColorField label="Border" value={theme.colors.button_border} onChange={(button_border) => setColors({ button_border })} />
        <ColorField label="Hover bg start" value={theme.colors.button_hover_bg_a} onChange={(button_hover_bg_a) => setColors({ button_hover_bg_a })} />
        <ColorField label="Hover bg end" value={theme.colors.button_hover_bg_b} onChange={(button_hover_bg_b) => setColors({ button_hover_bg_b })} />
      </FieldGroup>

      <FieldGroup title="Play / Download / Support buttons">
        <ColorField label="Play btn — start" value={theme.colors.play_btn_a} onChange={(play_btn_a) => setColors({ play_btn_a })} />
        <ColorField label="Play btn — end" value={theme.colors.play_btn_b} onChange={(play_btn_b) => setColors({ play_btn_b })} />
        <ColorField label="Play btn text" value={theme.colors.play_btn_text} onChange={(play_btn_text) => setColors({ play_btn_text })} />
        <ColorField label="Download btn — start" value={theme.colors.download_btn_a} onChange={(download_btn_a) => setColors({ download_btn_a })} />
        <ColorField label="Download btn — end" value={theme.colors.download_btn_b} onChange={(download_btn_b) => setColors({ download_btn_b })} />
        <ColorField label="Download btn text" value={theme.colors.download_btn_text} onChange={(download_btn_text) => setColors({ download_btn_text })} />
        <ColorField label="Support btn — start" value={theme.colors.support_btn_a} onChange={(support_btn_a) => setColors({ support_btn_a })} />
        <ColorField label="Support btn — end" value={theme.colors.support_btn_b} onChange={(support_btn_b) => setColors({ support_btn_b })} />
        <ColorField label="Support btn text" value={theme.colors.support_btn_text} onChange={(support_btn_text) => setColors({ support_btn_text })} />
      </FieldGroup>

      {settings.theme_presets && settings.theme_presets.length > 0 ? (
        <FieldGroup
          title="Saved presets"
          description="Presets you saved via the button above. Click Apply to load one, or Delete to remove."
        >
          {settings.theme_presets.map((p) => (
            <div key={p.id} className="admin-row" style={{ justifyContent: 'space-between', gap: 8 }}>
              <span>
                <strong>{p.name}</strong>
                <span className="admin-muted"> · {p.description}</span>
              </span>
              <span className="admin-row" style={{ gap: 6 }}>
                <button type="button" onClick={() => applyPreset(p.id)}>
                  Apply
                </button>
                <button
                  type="button"
                  onClick={() =>
                    setSettings({
                      ...settings,
                      theme_presets: settings.theme_presets.filter((x) => x.id !== p.id),
                    })
                  }
                >
                  Delete
                </button>
              </span>
            </div>
          ))}
        </FieldGroup>
      ) : null}
    </div>
  );
}

/**
 * MotionStudio
 *
 * The combined animation + game-card layout tab. Animations live here
 * because they decide what each rendered card / hero / promo looks like
 * as it appears, and game-card display flags piggyback on those animations.
 */
import type { AnimationKey, SiteSettings } from '../../../types';
import {
  ColorField,
  FieldGroup,
  NumberSliderField,
  SelectField,
  TextField,
  ToggleField,
} from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

const ANIMATION_OPTIONS: { value: AnimationKey; label: string }[] = [
  { value: 'none', label: 'None — no animation' },
  { value: 'fade-in', label: 'Fade in' },
  { value: 'slide-up', label: 'Slide up' },
  { value: 'slide-down', label: 'Slide down' },
  { value: 'slide-left', label: 'Slide left' },
  { value: 'slide-right', label: 'Slide right' },
  { value: 'zoom-in', label: 'Zoom in' },
  { value: 'zoom-out', label: 'Zoom out' },
  { value: 'flip-in', label: 'Flip in (3D)' },
  { value: 'wobble', label: 'Wobble (idle)' },
  { value: 'pulse', label: 'Pulse (idle)' },
  { value: 'shake', label: 'Shake (idle)' },
  { value: 'glitch', label: 'Glitch (idle)' },
  { value: 'shimmer', label: 'Shimmer (idle)' },
];

export function MotionStudio({ settings, setSettings }: Props) {
  const a = settings.animations;
  const g = settings.game_cards;

  const setA = (patch: Partial<typeof a>) =>
    setSettings({ ...settings, animations: { ...a, ...patch } });
  const setG = (patch: Partial<typeof g>) =>
    setSettings({ ...settings, game_cards: { ...g, ...patch } });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      {/* ---------------------------- Master ------------------------------ */}
      <FieldGroup
        title="Master animation switch"
        tone="accent"
        description="If off, every studio animation goes silent. The OS-level reduce-motion media query still applies."
      >
        <ToggleField
          label="Enable studio animations"
          checked={a.enabled}
          onChange={(enabled) => setA({ enabled })}
        />
      </FieldGroup>

      {/* --------------------------- Entrance ----------------------------- */}
      <FieldGroup
        title="Page entrance"
        description="Plays when the user navigates to a new route. Set to none for a static site feel."
      >
        <SelectField
          label="Animation"
          value={a.page_entrance}
          options={ANIMATION_OPTIONS}
          onChange={(v) => setA({ page_entrance: v as AnimationKey })}
        />
        <NumberSliderField
          label="Duration (ms)"
          value={a.page_entrance_duration_ms}
          min={0}
          max={2000}
          step={20}
          onChange={(v) => setA({ page_entrance_duration_ms: v })}
        />
        <NumberSliderField
          label="Route fade (ms)"
          value={a.route_fade_ms}
          min={0}
          max={1500}
          step={20}
          onChange={(v) => setA({ route_fade_ms: v })}
          help="A short crossfade between routes. 0 disables it."
        />
      </FieldGroup>

      {/* ------------------------------ Cards ----------------------------- */}
      <FieldGroup
        title="Card entrance"
        description="How each game card appears in the homepage grid. Stagger gives a cascading reveal."
      >
        <SelectField
          label="Animation"
          value={a.card_entrance}
          options={ANIMATION_OPTIONS}
          onChange={(v) => setA({ card_entrance: v as AnimationKey })}
        />
        <NumberSliderField
          label="Stagger (ms / card)"
          value={a.card_entrance_stagger_ms}
          min={0}
          max={250}
          step={5}
          onChange={(v) => setA({ card_entrance_stagger_ms: v })}
        />
      </FieldGroup>

      {/* ------------------------------ Hero ------------------------------ */}
      <FieldGroup
        title="Hero idle loop"
        description="Loops forever on the hero title. Use pulse/wobble/glitch sparingly — they can distract."
      >
        <SelectField
          label="Idle animation"
          value={a.hero_idle}
          options={ANIMATION_OPTIONS}
          onChange={(v) => setA({ hero_idle: v as AnimationKey })}
        />
        <NumberSliderField
          label="Period (s)"
          value={a.hero_idle_period_s}
          min={1}
          max={30}
          step={0.5}
          onChange={(v) => setA({ hero_idle_period_s: v })}
        />
      </FieldGroup>

      <FieldGroup title="Other animations">
        <SelectField
          label="Button hover"
          value={a.button_hover}
          options={ANIMATION_OPTIONS}
          onChange={(v) => setA({ button_hover: v as AnimationKey })}
        />
        <SelectField
          label="Promo card entrance"
          value={a.promo_entrance}
          options={ANIMATION_OPTIONS}
          onChange={(v) => setA({ promo_entrance: v as AnimationKey })}
        />
      </FieldGroup>

      {/* ============================ Game cards ========================== */}
      <FieldGroup
        title="Game-card layout"
        tone="accent"
        description="Tune what shows on each grid card on the homepage."
      >
        <SelectField
          label="Layout style"
          value={g.layout}
          options={[
            { value: 'standard', label: 'Standard (default)' },
            { value: 'compact', label: 'Compact (smaller padding)' },
            { value: 'media', label: 'Media-first (giant cover)' },
            { value: 'minimal', label: 'Minimal (no description)' },
          ]}
          onChange={(v) => setG({ layout: v as typeof g.layout })}
        />
        <SelectField
          label="Title case"
          value={g.title_case}
          options={[
            { value: 'none', label: 'As written' },
            { value: 'upper', label: 'UPPERCASE' },
            { value: 'lower', label: 'lowercase' },
            { value: 'capitalize', label: 'Capitalize Words' },
          ]}
          onChange={(v) => setG({ title_case: v as typeof g.title_case })}
        />
        <ToggleField
          label="Show thumbnail"
          checked={g.show_thumbnail}
          onChange={(show_thumbnail) => setG({ show_thumbnail })}
        />
        <ToggleField
          label="Show type tag"
          checked={g.show_type_tag}
          onChange={(show_type_tag) => setG({ show_type_tag })}
        />
        <ToggleField
          label="Show description"
          checked={g.show_description}
          onChange={(show_description) => setG({ show_description })}
        />
        <ToggleField
          label="Show price (when set)"
          checked={g.show_price}
          onChange={(show_price) => setG({ show_price })}
        />
      </FieldGroup>

      <FieldGroup
        title="NEW ribbon"
        description="Highlights games published in the last N days with a corner ribbon."
      >
        <ToggleField
          label="Enable"
          checked={g.new_ribbon.enabled}
          onChange={(enabled) => setG({ new_ribbon: { ...g.new_ribbon, enabled } })}
        />
        <TextField
          label="Ribbon text"
          value={g.new_ribbon.text}
          onChange={(text) => setG({ new_ribbon: { ...g.new_ribbon, text } })}
        />
        <NumberSliderField
          label="Window (days)"
          value={g.new_ribbon.days}
          min={1}
          max={90}
          step={1}
          onChange={(days) => setG({ new_ribbon: { ...g.new_ribbon, days } })}
        />
        <ColorField
          label="Ribbon background"
          value={g.new_ribbon.bg}
          onChange={(bg) => setG({ new_ribbon: { ...g.new_ribbon, bg } })}
        />
        <ColorField
          label="Ribbon text colour"
          value={g.new_ribbon.color}
          onChange={(color) => setG({ new_ribbon: { ...g.new_ribbon, color } })}
        />
      </FieldGroup>
    </div>
  );
}

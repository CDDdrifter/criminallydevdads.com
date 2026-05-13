/**
 * MediaStudio — site-wide sound, cursor, and particle layer.
 *
 * Three runtime layers live here:
 *  - Audio (`<SiteAudio>`) plays bg music + hover sounds.
 *  - Cursor (`<SiteCursor>`) swaps the mouse for a custom emoji / image with optional trail.
 *  - Particles (`<SiteParticles>`) paints a canvas of stars / snow / etc behind content.
 */
import type { CursorConfig, ParticlesConfig, SiteSettings } from '../../../types';
import {
  AssetUploadField,
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

export function MediaStudio({ settings, setSettings }: Props) {
  const audio = settings.audio;
  const cursor = settings.cursor;
  const particles = settings.particles;
  const setAudio = (patch: Partial<typeof audio>) =>
    setSettings({ ...settings, audio: { ...audio, ...patch } });
  const setCursor = (patch: Partial<CursorConfig>) =>
    setSettings({ ...settings, cursor: { ...cursor, ...patch } });
  const setParticles = (patch: Partial<ParticlesConfig>) =>
    setSettings({ ...settings, particles: { ...particles, ...patch } });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      {/* ============================== Audio ============================= */}
      <FieldGroup
        title="Site audio"
        tone="accent"
        description="Browsers usually require a user gesture before audio plays — interact with the page once to unlock."
      >
        <ToggleField
          label="Mute all studio audio"
          checked={audio.muted}
          onChange={(muted) => setAudio({ muted })}
        />
        <NumberSliderField
          label="Master volume"
          value={audio.master_volume}
          min={0}
          max={1}
          step={0.05}
          onChange={(master_volume) => setAudio({ master_volume })}
        />
        <ToggleField
          label="Show a floating mute toggle on the page"
          checked={audio.show_mute_toggle}
          onChange={(show_mute_toggle) => setAudio({ show_mute_toggle })}
        />
      </FieldGroup>

      <FieldGroup
        title="Background music"
        description="Loops while the user is on the site. Keep volume low so it doesn't fight game audio."
      >
        <AssetUploadField
          label="Music URL"
          value={audio.background_music_url}
          onChange={(background_music_url) => setAudio({ background_music_url })}
          placeholder="https://… mp3/ogg/wav"
          accept="audio/*"
          kind="audio"
        />
        <NumberSliderField
          label="Music volume"
          value={audio.background_music_volume}
          min={0}
          max={1}
          step={0.05}
          onChange={(background_music_volume) => setAudio({ background_music_volume })}
        />
        <ToggleField
          label="Try to autoplay on first gesture"
          checked={audio.background_music_autoplay}
          onChange={(background_music_autoplay) => setAudio({ background_music_autoplay })}
        />
        <ToggleField
          label="Loop"
          checked={audio.background_music_loop}
          onChange={(background_music_loop) => setAudio({ background_music_loop })}
        />
      </FieldGroup>

      <FieldGroup
        title="Hover & ambient"
        description="A tiny click/hover sound adds polish. An ambient loop mixes underneath the music for atmosphere."
      >
        <AssetUploadField
          label="Hover sound URL"
          value={audio.hover_sound_url}
          onChange={(hover_sound_url) => setAudio({ hover_sound_url })}
          placeholder="https://… (short clip)"
          accept="audio/*"
          kind="audio"
        />
        <NumberSliderField
          label="Hover volume"
          value={audio.hover_sound_volume}
          min={0}
          max={1}
          step={0.05}
          onChange={(hover_sound_volume) => setAudio({ hover_sound_volume })}
        />
        <AssetUploadField
          label="Ambient loop URL"
          value={audio.ambient_loop_url}
          onChange={(ambient_loop_url) => setAudio({ ambient_loop_url })}
          placeholder="https://… (looping pad / wind / rain)"
          accept="audio/*"
          kind="audio"
        />
        <NumberSliderField
          label="Ambient volume"
          value={audio.ambient_loop_volume}
          min={0}
          max={1}
          step={0.05}
          onChange={(ambient_loop_volume) => setAudio({ ambient_loop_volume })}
        />
      </FieldGroup>

      {/* ============================== Cursor ============================ */}
      <FieldGroup
        title="Custom cursor"
        tone="accent"
        description="Render an emoji or image under the mouse. Works on desktop only — mobile devices ignore custom cursors."
      >
        <ToggleField
          label="Enable studio cursor"
          checked={cursor.enabled}
          onChange={(enabled) => setCursor({ enabled })}
        />
        <SelectField
          label="Cursor style"
          value={cursor.style}
          options={[
            { value: 'default', label: 'Default OS cursor' },
            { value: 'emoji', label: 'Emoji' },
            { value: 'image', label: 'Image URL' },
            { value: 'reticle', label: 'Targeting reticle' },
            { value: 'crosshair', label: 'Crosshair' },
            { value: 'pointer', label: 'Big pointer' },
            { value: 'none', label: 'Hide cursor (kiosk)' },
          ]}
          onChange={(v) => setCursor({ style: v as CursorConfig['style'] })}
        />
        <TextField
          label="Emoji"
          value={cursor.emoji}
          onChange={(emoji) => setCursor({ emoji })}
          placeholder="👑 🎮 🔫 …"
        />
        <AssetUploadField
          label="Image URL"
          value={cursor.image_url}
          onChange={(image_url) => setCursor({ image_url })}
        />
        <NumberSliderField
          label="Size (px)"
          value={cursor.size_px}
          min={8}
          max={96}
          step={1}
          onChange={(size_px) => setCursor({ size_px })}
        />
        <ToggleField
          label="Hide OS cursor when studio cursor active"
          checked={cursor.hide_os_cursor}
          onChange={(hide_os_cursor) => setCursor({ hide_os_cursor })}
        />
      </FieldGroup>

      <FieldGroup
        title="Cursor trail"
        description="A trail of fading dots that follow the cursor — be sparing with this on slower devices."
      >
        <ToggleField
          label="Enable trail"
          checked={cursor.trail.enabled}
          onChange={(enabled) => setCursor({ trail: { ...cursor.trail, enabled } })}
        />
        <ColorField
          label="Trail colour"
          value={cursor.trail.color}
          onChange={(color) => setCursor({ trail: { ...cursor.trail, color } })}
        />
        <NumberSliderField
          label="Trail length"
          value={cursor.trail.length}
          min={2}
          max={30}
          step={1}
          onChange={(length) => setCursor({ trail: { ...cursor.trail, length } })}
        />
        <NumberSliderField
          label="Trail dot size (px)"
          value={cursor.trail.size_px}
          min={2}
          max={32}
          step={1}
          onChange={(size_px) => setCursor({ trail: { ...cursor.trail, size_px } })}
        />
      </FieldGroup>

      <FieldGroup title="Click ripple">
        <ToggleField
          label="Enable click ripple"
          checked={cursor.click_ripple.enabled}
          onChange={(enabled) =>
            setCursor({ click_ripple: { ...cursor.click_ripple, enabled } })
          }
        />
        <ColorField
          label="Ripple colour"
          value={cursor.click_ripple.color}
          onChange={(color) => setCursor({ click_ripple: { ...cursor.click_ripple, color } })}
        />
        <NumberSliderField
          label="Ripple size (px)"
          value={cursor.click_ripple.size_px}
          min={20}
          max={240}
          step={5}
          onChange={(size_px) =>
            setCursor({ click_ripple: { ...cursor.click_ripple, size_px } })
          }
        />
      </FieldGroup>

      {/* ============================ Particles =========================== */}
      <FieldGroup
        title="Particles layer"
        tone="accent"
        description="A canvas of floating particles painted behind (or above) the page content."
      >
        <ToggleField
          label="Enable particles"
          checked={particles.enabled}
          onChange={(enabled) => setParticles({ enabled })}
        />
        <SelectField
          label="Kind"
          value={particles.kind}
          options={[
            { value: 'stars', label: 'Stars' },
            { value: 'snow', label: 'Snow' },
            { value: 'sparks', label: 'Sparks (upward)' },
            { value: 'ash', label: 'Ash (downward)' },
            { value: 'matrix', label: 'Matrix code rain' },
            { value: 'dots', label: 'Plain dots' },
            { value: 'fireflies', label: 'Fireflies' },
            { value: 'bubbles', label: 'Bubbles (upward)' },
            { value: 'rain', label: 'Rain' },
            { value: 'leaves', label: 'Leaves' },
          ]}
          onChange={(v) => setParticles({ kind: v as ParticlesConfig['kind'] })}
        />
        <NumberSliderField
          label="Count"
          value={particles.count}
          min={1}
          max={400}
          step={1}
          onChange={(count) => setParticles({ count })}
        />
        <ColorField
          label="Particle colour"
          value={particles.color}
          onChange={(color) => setParticles({ color })}
        />
        <NumberSliderField
          label="Min speed (px/frame)"
          value={particles.speed_min}
          min={0}
          max={5}
          step={0.05}
          onChange={(speed_min) => setParticles({ speed_min })}
        />
        <NumberSliderField
          label="Max speed (px/frame)"
          value={particles.speed_max}
          min={0}
          max={10}
          step={0.05}
          onChange={(speed_max) => setParticles({ speed_max })}
        />
        <NumberSliderField
          label="Min size (px)"
          value={particles.size_min_px}
          min={1}
          max={30}
          step={1}
          onChange={(size_min_px) => setParticles({ size_min_px })}
        />
        <NumberSliderField
          label="Max size (px)"
          value={particles.size_max_px}
          min={1}
          max={40}
          step={1}
          onChange={(size_max_px) => setParticles({ size_max_px })}
        />
        <SelectField
          label="Direction"
          value={particles.direction}
          options={[
            { value: 'down', label: 'Down' },
            { value: 'up', label: 'Up' },
            { value: 'left', label: 'Left' },
            { value: 'right', label: 'Right' },
            { value: 'random', label: 'Random' },
          ]}
          onChange={(v) => setParticles({ direction: v as ParticlesConfig['direction'] })}
        />
        <SelectField
          label="Layer"
          value={particles.z_index}
          options={[
            { value: 'behind', label: 'Behind content' },
            { value: 'above', label: 'Above content (overlay)' },
          ]}
          onChange={(v) => setParticles({ z_index: v as ParticlesConfig['z_index'] })}
        />
        <NumberSliderField
          label="Layer opacity"
          value={particles.opacity}
          min={0}
          max={1}
          step={0.05}
          onChange={(opacity) => setParticles({ opacity })}
        />
        <ToggleField
          label="Honour OS reduce-motion"
          checked={particles.respect_reduce_motion}
          onChange={(respect_reduce_motion) => setParticles({ respect_reduce_motion })}
        />
      </FieldGroup>
    </div>
  );
}

/**
 * SiteAudio — global music + hover + ambient audio for the studio.
 *
 * Browsers refuse to autoplay audio until the user has interacted with the
 * page once. We respect that by lazy-attaching the music `<audio>` element
 * the first time *any* user gesture fires, then unmuting per settings.
 *
 * Hover sounds use a single cached `HTMLAudioElement` cloned per fire so they
 * can overlap without resetting one another.
 */
import { useEffect, useRef } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';

export function SiteAudio() {
  const { settings } = useSiteSettings();
  const audio = settings.audio;

  const musicRef = useRef<HTMLAudioElement | null>(null);
  const ambientRef = useRef<HTMLAudioElement | null>(null);
  const hoverRef = useRef<HTMLAudioElement | null>(null);

  // Apply volumes whenever settings change.
  useEffect(() => {
    const master = audio.muted ? 0 : audio.master_volume;
    if (musicRef.current) musicRef.current.volume = master * audio.background_music_volume;
    if (ambientRef.current) ambientRef.current.volume = master * audio.ambient_loop_volume;
  }, [audio]);

  // Manage background music element.
  useEffect(() => {
    if (!audio.background_music_url) {
      musicRef.current?.pause();
      musicRef.current?.remove();
      musicRef.current = null;
      return undefined;
    }
    if (!musicRef.current) {
      const el = new Audio(audio.background_music_url);
      el.loop = audio.background_music_loop;
      el.volume = (audio.muted ? 0 : audio.master_volume) * audio.background_music_volume;
      el.preload = 'auto';
      musicRef.current = el;
    } else if (musicRef.current.src !== audio.background_music_url) {
      musicRef.current.src = audio.background_music_url;
    }
    musicRef.current.loop = audio.background_music_loop;

    // Autoplay attempt — most browsers will reject without a gesture.
    if (audio.background_music_autoplay) {
      const playP = musicRef.current.play();
      if (playP && typeof playP.catch === 'function') {
        playP.catch(() => {
          // Fall back to playing on first interaction.
          const start = () => {
            musicRef.current?.play().catch(() => undefined);
            window.removeEventListener('pointerdown', start);
            window.removeEventListener('keydown', start);
          };
          window.addEventListener('pointerdown', start, { once: true });
          window.addEventListener('keydown', start, { once: true });
        });
      }
    }
    return undefined;
  }, [
    audio.background_music_url,
    audio.background_music_loop,
    audio.background_music_autoplay,
    audio.master_volume,
    audio.muted,
    audio.background_music_volume,
  ]);

  // Ambient loop.
  useEffect(() => {
    if (!audio.ambient_loop_url) {
      ambientRef.current?.pause();
      ambientRef.current?.remove();
      ambientRef.current = null;
      return undefined;
    }
    if (!ambientRef.current) {
      const el = new Audio(audio.ambient_loop_url);
      el.loop = true;
      el.volume = (audio.muted ? 0 : audio.master_volume) * audio.ambient_loop_volume;
      ambientRef.current = el;
      const start = () => {
        ambientRef.current?.play().catch(() => undefined);
        window.removeEventListener('pointerdown', start);
      };
      window.addEventListener('pointerdown', start, { once: true });
    } else if (ambientRef.current.src !== audio.ambient_loop_url) {
      ambientRef.current.src = audio.ambient_loop_url;
    }
    return undefined;
  }, [audio.ambient_loop_url, audio.master_volume, audio.muted, audio.ambient_loop_volume]);

  // Hover sound — single hidden audio cloned per fire.
  useEffect(() => {
    if (!audio.hover_sound_url) {
      hoverRef.current = null;
      return undefined;
    }
    hoverRef.current = new Audio(audio.hover_sound_url);
    const onOver = (ev: MouseEvent) => {
      const t = ev.target as HTMLElement | null;
      if (!t) return;
      if (!t.closest('button, a, .game-card')) return;
      const clip = hoverRef.current?.cloneNode(true) as HTMLAudioElement | undefined;
      if (!clip) return;
      clip.volume = (audio.muted ? 0 : audio.master_volume) * audio.hover_sound_volume;
      const p = clip.play();
      if (p && typeof p.catch === 'function') p.catch(() => undefined);
    };
    document.addEventListener('mouseover', onOver);
    return () => document.removeEventListener('mouseover', onOver);
  }, [audio.hover_sound_url, audio.master_volume, audio.muted, audio.hover_sound_volume]);

  // Optional floating mute button so users can pause everything at will.
  if (!audio.show_mute_toggle) return null;
  return (
    <button
      type="button"
      onClick={() => {
        // Lightweight: stash a window-level flag and force-pause music.
        // The Studio mute toggle is the real source of truth; this is just UX.
        if (musicRef.current) musicRef.current.muted = !musicRef.current.muted;
        if (ambientRef.current) ambientRef.current.muted = !ambientRef.current.muted;
      }}
      aria-label="Toggle site audio"
      style={{
        position: 'fixed',
        right: 16,
        bottom: 16,
        zIndex: 9990,
        borderRadius: '50%',
        width: 44,
        height: 44,
        fontSize: '1.1rem',
        background: 'var(--panel)',
        border: '1px solid var(--border)',
        cursor: 'pointer',
      }}
    >
      🔊
    </button>
  );
}

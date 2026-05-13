/**
 * ClickSound
 *
 * When `behavior.click_sound_url` is set, plays that short audio clip every
 * time a user clicks on a `<button>`, `<a>`, or `.btn-*` element inside the
 * app. Volume comes from `behavior.click_sound_volume`.
 *
 * - Mount once near the root of the tree (after SiteSettingsProvider).
 * - Hot-swaps the audio source when the URL changes.
 * - Cheap: a single `<audio>` element is cloned per click to allow overlap.
 * - Silently fails if the browser blocks audio before user interaction.
 */
import { useEffect, useMemo, useRef } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';

export function ClickSound() {
  const { settings } = useSiteSettings();
  const url = settings.behavior?.click_sound_url?.trim() ?? '';
  const volume = Math.max(0, Math.min(1, settings.behavior?.click_sound_volume ?? 0.4));
  const audioRef = useRef<HTMLAudioElement | null>(null);

  // Build / dispose the master <audio> element whenever the URL changes.
  useMemo(() => {
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = '';
      audioRef.current = null;
    }
    if (url) {
      const el = new Audio(url);
      el.preload = 'auto';
      el.crossOrigin = 'anonymous';
      audioRef.current = el;
    }
    return url;
  }, [url]);

  useEffect(() => {
    if (!url) return undefined;
    function onClick(ev: MouseEvent) {
      const t = ev.target as HTMLElement | null;
      if (!t) return;
      const trigger = t.closest('button, a, .btn-play, .btn-download, .btn-support');
      if (!trigger) return;
      const audio = audioRef.current;
      if (!audio) return;
      // Clone so rapid clicks overlap (the source `audio` is paused for caching).
      try {
        const clip = audio.cloneNode(true) as HTMLAudioElement;
        clip.volume = volume;
        const playback = clip.play();
        if (playback && typeof playback.catch === 'function') {
          // Ignore the AbortError some browsers throw before user gesture.
          playback.catch(() => undefined);
        }
      } catch {
        /* clones may fail in extremely locked-down browsers — ignore. */
      }
    }
    document.addEventListener('click', onClick, true);
    return () => {
      document.removeEventListener('click', onClick, true);
    };
  }, [url, volume]);

  return null;
}

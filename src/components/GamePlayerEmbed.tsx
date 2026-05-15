/**
 * GamePlayerEmbed — iframe shell for hosted / zipped games.
 *
 * No overlay fullscreen button: games use their own controls, Escape, or the
 * browser/device back gesture. The iframe still allows `allowFullScreen` so a
 * game may request native fullscreen from inside its own canvas if it supports it.
 */
import { useEffect } from 'react';

type Props = {
  title: string;
  src: string;
};

type FullscreenDocument = Document & {
  webkitFullscreenElement?: Element | null;
  webkitExitFullscreen?: () => Promise<void> | void;
};

function getFullscreenElement(): Element | null {
  const doc = document as FullscreenDocument;
  return document.fullscreenElement ?? doc.webkitFullscreenElement ?? null;
}

function tryNativeExit(): void {
  const doc = document as FullscreenDocument;
  try {
    if (typeof doc.exitFullscreen === 'function') {
      void doc.exitFullscreen();
      return;
    }
    if (typeof doc.webkitExitFullscreen === 'function') {
      void doc.webkitExitFullscreen();
    }
  } catch {
    /* ignore */
  }
}

export function GamePlayerEmbed({ title, src }: Props) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && getFullscreenElement()) {
        tryNativeExit();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  return (
    <div className="game-embed-shell">
      <iframe
        title={title}
        src={src}
        allow="fullscreen; gamepad; autoplay; gyroscope; accelerometer; xr-spatial-tracking"
        allowFullScreen
      />
    </div>
  );
}

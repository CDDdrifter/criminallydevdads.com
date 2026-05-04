/**
 * Game iframe + fullscreen control.
 *
 * We request fullscreen on the *wrapper* (this shell), not the iframe’s document, because cross-origin
 * games cannot be fullscreen’d from the parent via the iframe’s API. Expanding the shell gives a clean
 * “whole player” fullscreen for every hosted game (local games/ or external URL).
 */
import { useCallback, useEffect, useRef, useState } from 'react';

type Props = {
  title: string;
  src: string;
};

function getFullscreenElement(): Element | null {
  const doc = document as Document & {
    webkitFullscreenElement?: Element | null;
  };
  return document.fullscreenElement ?? doc.webkitFullscreenElement ?? null;
}

export function GamePlayerEmbed({ title, src }: Props) {
  const shellRef = useRef<HTMLDivElement>(null);
  const [fs, setFs] = useState(false);
  const [fsSupported, setFsSupported] = useState(true);

  useEffect(() => {
    const el = shellRef.current;
    if (!el) {
      return;
    }
    const can =
      typeof el.requestFullscreen === 'function' ||
      typeof (el as unknown as { webkitRequestFullscreen?: () => void }).webkitRequestFullscreen === 'function';
    setFsSupported(can);

    const sync = () => {
      setFs(getFullscreenElement() === el);
    };
    document.addEventListener('fullscreenchange', sync);
    document.addEventListener('webkitfullscreenchange', sync as EventListener);
    return () => {
      document.removeEventListener('fullscreenchange', sync);
      document.removeEventListener('webkitfullscreenchange', sync as EventListener);
    };
  }, []);

  const toggleFullscreen = useCallback(async () => {
    const el = shellRef.current;
    if (!el) {
      return;
    }
    try {
      if (getFullscreenElement() === el) {
        const doc = document as Document & {
          exitFullscreen?: () => Promise<void>;
          webkitExitFullscreen?: () => void;
        };
        if (doc.exitFullscreen) {
          await doc.exitFullscreen();
        } else {
          doc.webkitExitFullscreen?.();
        }
      } else {
        if (el.requestFullscreen) {
          await el.requestFullscreen();
        } else {
          const w = el as unknown as { webkitRequestFullscreen?: () => void };
          w.webkitRequestFullscreen?.();
        }
      }
    } catch (e) {
      console.warn('Fullscreen not available', e);
    }
  }, []);

  return (
    <div className="game-embed-shell" ref={shellRef}>
      <iframe
        title={title}
        src={src}
        allow="fullscreen; gamepad; autoplay"
        allowFullScreen
      />
      {fsSupported ? (
        <button
          type="button"
          className="game-embed-fs-btn"
          onClick={() => void toggleFullscreen()}
          aria-pressed={fs}
          aria-label={fs ? 'Exit fullscreen' : 'Enter fullscreen'}
        >
          {fs ? 'Exit fullscreen' : '⛶ Fullscreen'}
        </button>
      ) : null}
    </div>
  );
}

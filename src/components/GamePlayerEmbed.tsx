/**
 * GamePlayerEmbed — game iframe + enter-fullscreen control.
 *
 * Shows **Fullscreen** only while not fullscreen. Once fullscreen, no overlay
 * exit button — use Escape, browser back, or the game’s own UI.
 */
import { useCallback, useEffect, useRef, useState } from 'react';

type Props = {
  title: string;
  src: string;
};

type FullscreenDocument = Document & {
  webkitFullscreenElement?: Element | null;
  webkitExitFullscreen?: () => Promise<void> | void;
};

type FullscreenElement = HTMLDivElement & {
  webkitRequestFullscreen?: () => Promise<void> | void;
};

function getFullscreenElement(): Element | null {
  const doc = document as FullscreenDocument;
  return document.fullscreenElement ?? doc.webkitFullscreenElement ?? null;
}

function tryNativeEnter(el: FullscreenElement): boolean {
  try {
    if (typeof el.requestFullscreen === 'function') {
      void el.requestFullscreen();
      return true;
    }
    if (typeof el.webkitRequestFullscreen === 'function') {
      void el.webkitRequestFullscreen();
      return true;
    }
  } catch {
    /* gesture / policy */
  }
  return false;
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

function isIPhone(): boolean {
  if (typeof navigator === 'undefined') return false;
  return /iPhone|iPod/.test(navigator.userAgent || '');
}

export function GamePlayerEmbed({ title, src }: Props) {
  const shellRef = useRef<HTMLDivElement>(null);
  const [fs, setFs] = useState(false);
  const [pseudoFs, setPseudoFs] = useState(false);

  const isFullscreen = fs || pseudoFs;

  useEffect(() => {
    const sync = () => {
      setFs(getFullscreenElement() === shellRef.current);
    };
    document.addEventListener('fullscreenchange', sync);
    document.addEventListener('webkitfullscreenchange', sync as EventListener);
    return () => {
      document.removeEventListener('fullscreenchange', sync);
      document.removeEventListener('webkitfullscreenchange', sync as EventListener);
    };
  }, []);

  useEffect(() => {
    if (!pseudoFs) return undefined;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prevOverflow;
    };
  }, [pseudoFs]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      if (pseudoFs) setPseudoFs(false);
      else if (getFullscreenElement()) tryNativeExit();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [pseudoFs]);

  const enter = useCallback(() => {
    const el = shellRef.current as FullscreenElement | null;
    if (!el) return;
    if (isIPhone() || !tryNativeEnter(el)) {
      setPseudoFs(true);
    }
  }, []);

  return (
    <div
      className={`game-embed-shell${pseudoFs ? ' game-embed-shell--pseudo-fs' : ''}`}
      ref={shellRef}
    >
      <iframe
        title={title}
        src={src}
        allow="fullscreen; gamepad; autoplay; gyroscope; accelerometer; xr-spatial-tracking"
        allowFullScreen
      />
      {!isFullscreen ? (
        <button
          type="button"
          className="game-embed-fs-btn"
          onClick={enter}
          aria-label="Enter fullscreen"
        >
          ⛶ Fullscreen
        </button>
      ) : null}
    </div>
  );
}

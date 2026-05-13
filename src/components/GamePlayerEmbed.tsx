/**
 * GamePlayerEmbed — game iframe + fullscreen control.
 *
 * Cross-origin embedded games can't be fullscreen'd through the iframe's own
 * API, so we fullscreen the *shell* div instead. That works on desktop +
 * Android + iPadOS, but **iOS Safari on iPhone removed `requestFullscreen`
 * on non-`<video>` elements**, so the native API check fails there and the
 * button used to vanish entirely.
 *
 * Fix: detect iPhone and fall back to a CSS-only "pseudo fullscreen" that
 * `position: fixed`s the shell over the whole viewport and locks body scroll.
 * The button is always visible now — native API when possible, CSS fallback
 * otherwise — so iPhone users get a real fullscreen-feeling experience.
 */
import { useCallback, useEffect, useRef, useState } from 'react';

type Props = {
  title: string;
  src: string;
};

// Browsers that expose fullscreen with the webkit prefix (older Safari).
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

/**
 * Native fullscreen on the shell. Returns `true` if it actually started a
 * request (so callers know whether to fall back to pseudo-fullscreen).
 */
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
    // Some Safari versions throw synchronously if called outside a user gesture.
  }
  return false;
}

function tryNativeExit(): boolean {
  const doc = document as FullscreenDocument;
  try {
    if (typeof doc.exitFullscreen === 'function') {
      void doc.exitFullscreen();
      return true;
    }
    if (typeof doc.webkitExitFullscreen === 'function') {
      void doc.webkitExitFullscreen();
      return true;
    }
  } catch {
    /* nothing to do — pseudo-fullscreen takeover still works. */
  }
  return false;
}

/** iPhone (and iPod) report iOS in UA — iPad now reports as Mac, treat separately. */
function isIPhone(): boolean {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent || '';
  return /iPhone|iPod/.test(ua);
}

export function GamePlayerEmbed({ title, src }: Props) {
  const shellRef = useRef<HTMLDivElement>(null);
  /** Native fullscreen state (Element-based API). */
  const [fs, setFs] = useState(false);
  /** Pseudo-fullscreen takeover state (iPhone fallback). */
  const [pseudoFs, setPseudoFs] = useState(false);

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

  // Body-scroll lock + Esc handling while in pseudo-fullscreen.
  useEffect(() => {
    if (!pseudoFs) return undefined;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPseudoFs(false);
    };
    window.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = prevOverflow;
      window.removeEventListener('keydown', onKey);
    };
  }, [pseudoFs]);

  const enter = useCallback(() => {
    const el = shellRef.current as FullscreenElement | null;
    if (!el) return;
    // iPhone Safari refuses fullscreen on non-<video>; skip straight to fallback
    // so users still get the takeover experience.
    if (isIPhone() || !tryNativeEnter(el)) {
      setPseudoFs(true);
    }
  }, []);

  const exit = useCallback(() => {
    if (pseudoFs) setPseudoFs(false);
    if (fs) tryNativeExit();
  }, [fs, pseudoFs]);

  const isActuallyFull = fs || pseudoFs;

  return (
    <div
      className={`game-embed-shell${pseudoFs ? ' game-embed-shell--pseudo-fs' : ''}`}
      ref={shellRef}
    >
      <iframe
        title={title}
        src={src}
        // `fullscreen` permission lets the game request native FS from inside the iframe too
        // (e.g. Godot's HTML5 templates). On iPhone the game itself usually exposes its own
        // landscape button — our shell takeover gives them an aligned full-viewport stage.
        allow="fullscreen; gamepad; autoplay; gyroscope; accelerometer; xr-spatial-tracking"
        allowFullScreen
      />
      {/* Always visible. We toggle between Enter (when not full) and Exit (when full). */}
      <button
        type="button"
        className="game-embed-fs-btn"
        onClick={isActuallyFull ? exit : enter}
        aria-pressed={isActuallyFull}
        aria-label={isActuallyFull ? 'Exit fullscreen' : 'Enter fullscreen'}
      >
        {isActuallyFull ? '✕ Exit' : '⛶ Fullscreen'}
      </button>
    </div>
  );
}

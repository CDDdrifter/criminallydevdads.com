/**
 * GamePlayerEmbed — game iframe + enter-fullscreen control.
 *
 * Routes keyboard / gamepad to the embedded game via a click-to-play gate, iframe focus,
 * and capture-phase key handling so Space / WASD / arrows do not scroll the hub page.
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  anyGamepadButtonPressed,
  focusGameIframe,
  GAME_EMBED_ALLOW,
  isGameControlKey,
  isTypingTarget,
  setGameEmbedActiveDocument,
} from '../lib/gameEmbedInput';

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
  if (typeof navigator === 'undefined') {
    return false;
  }
  return /iPhone|iPod/.test(navigator.userAgent || '');
}

export function GamePlayerEmbed({ title, src }: Props) {
  const shellRef = useRef<HTMLDivElement>(null);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [fs, setFs] = useState(false);
  const [pseudoFs, setPseudoFs] = useState(false);
  const [engaged, setEngaged] = useState(false);

  const isFullscreen = fs || pseudoFs;

  const engage = useCallback(() => {
    setEngaged(true);
    requestAnimationFrame(() => {
      focusGameIframe(iframeRef.current);
    });
  }, []);

  useEffect(() => {
    setEngaged(false);
  }, [src]);

  useEffect(() => {
    setGameEmbedActiveDocument(engaged);
    return () => setGameEmbedActiveDocument(false);
  }, [engaged]);

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
    if (!pseudoFs) {
      return undefined;
    }
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prevOverflow;
    };
  }, [pseudoFs]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') {
        return;
      }
      if (pseudoFs) {
        setPseudoFs(false);
      } else if (getFullscreenElement()) {
        tryNativeExit();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [pseudoFs]);

  /** After engage: steal game keys from the parent page and refocus the iframe. */
  useEffect(() => {
    if (!engaged) {
      return undefined;
    }

    const onKeyDownCapture = (e: KeyboardEvent) => {
      if (e.key === 'Escape' || isTypingTarget(e.target)) {
        return;
      }
      const iframe = iframeRef.current;
      if (!iframe || !isGameControlKey(e)) {
        return;
      }
      const active = document.activeElement;
      if (active !== iframe) {
        e.preventDefault();
        focusGameIframe(iframe);
      }
    };

    document.addEventListener('keydown', onKeyDownCapture, true);
    return () => document.removeEventListener('keydown', onKeyDownCapture, true);
  }, [engaged]);

  /** Any key while the gate is up → engage (same as click). */
  useEffect(() => {
    if (engaged) {
      return undefined;
    }
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' || isTypingTarget(e.target)) {
        return;
      }
      if (isGameControlKey(e) || e.key.length === 1) {
        engage();
      }
    };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [engaged, engage]);

  /** Web gamepads: first button press should engage + focus (Godot often needs this). */
  useEffect(() => {
    if (engaged) {
      return undefined;
    }
    let raf = 0;
    const tick = () => {
      if (anyGamepadButtonPressed()) {
        engage();
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [engaged, engage]);

  /** Keep routing gamepad input to the iframe while playing. */
  useEffect(() => {
    if (!engaged) {
      return undefined;
    }
    let raf = 0;
    const tick = () => {
      const iframe = iframeRef.current;
      if (iframe && document.activeElement !== iframe && anyGamepadButtonPressed()) {
        focusGameIframe(iframe);
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [engaged]);

  const enter = useCallback(() => {
    const el = shellRef.current as FullscreenElement | null;
    if (!el) {
      return;
    }
    engage();
    if (isIPhone() || !tryNativeEnter(el)) {
      setPseudoFs(true);
    }
  }, [engage]);

  const onShellPointerDown = useCallback(
    (e: React.PointerEvent) => {
      if ((e.target as HTMLElement).closest('.game-embed-fs-btn')) {
        return;
      }
      if (!engaged) {
        engage();
      } else {
        focusGameIframe(iframeRef.current);
      }
    },
    [engaged, engage],
  );

  return (
    <div
      className={`game-embed-shell${pseudoFs ? ' game-embed-shell--pseudo-fs' : ''}${engaged ? ' game-embed-shell--engaged' : ''}`}
      ref={shellRef}
      onPointerDown={onShellPointerDown}
    >
      <iframe
        ref={iframeRef}
        title={title}
        src={src}
        className="game-embed-iframe"
        tabIndex={0}
        allow={GAME_EMBED_ALLOW}
        allowFullScreen
      />
      {!engaged ? (
        <button type="button" className="game-embed-play-gate" onClick={engage}>
          <span className="game-embed-play-gate__title">🎮 Click to play</span>
          <span className="game-embed-play-gate__hint">
            Focuses keyboard &amp; controller here. Press any gamepad button if controls do not respond.
          </span>
        </button>
      ) : null}
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

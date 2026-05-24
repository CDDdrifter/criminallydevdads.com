/**
 * GamePlayerEmbed — game iframe + docked player toolbar (fullscreen always reachable).
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  anyGamepadButtonPressed,
  focusGameIframe,
  GAME_EMBED_ALLOW,
  isGameControlKey,
  isTypingTarget,
  setGameEmbedActiveDocument,
  setGameEmbedFullscreenDocument,
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

  const exitFullscreen = useCallback(() => {
    if (pseudoFs) {
      setPseudoFs(false);
      return;
    }
    tryNativeExit();
  }, [pseudoFs]);

  useEffect(() => {
    setEngaged(false);
    setPseudoFs(false);
  }, [src]);

  useEffect(() => {
    setGameEmbedActiveDocument(engaged);
    return () => setGameEmbedActiveDocument(false);
  }, [engaged]);

  useEffect(() => {
    setGameEmbedFullscreenDocument(isFullscreen);
    return () => setGameEmbedFullscreenDocument(false);
  }, [isFullscreen]);

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

  const enterFullscreen = useCallback(() => {
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
      if ((e.target as HTMLElement).closest('.game-embed-toolbar, .game-embed-play-gate')) {
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
      className={`game-embed-shell${pseudoFs ? ' game-embed-shell--pseudo-fs' : ''}${engaged ? ' game-embed-shell--engaged' : ''}${isFullscreen ? ' game-embed-shell--fs' : ''}`}
      ref={shellRef}
      onPointerDown={onShellPointerDown}
    >
      <div className="game-embed-stage">
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
              Focuses keyboard &amp; controller here. Use the toolbar below for fullscreen.
            </span>
          </button>
        ) : null}
      </div>

      <div className="game-embed-toolbar" role="toolbar" aria-label="Game player">
        <span className="game-embed-toolbar__hint">
          {isFullscreen ? 'Press Esc or Exit to leave fullscreen' : engaged ? 'Playing — scroll down for game info' : 'Click the game area to start'}
        </span>
        {isFullscreen ? (
          <button
            type="button"
            className="game-embed-fs-btn game-embed-fs-btn--exit"
            onClick={exitFullscreen}
            aria-label="Exit fullscreen"
          >
            ✕ Exit fullscreen
          </button>
        ) : (
          <button
            type="button"
            className="game-embed-fs-btn"
            onClick={enterFullscreen}
            aria-label="Enter fullscreen"
          >
            ⛶ Fullscreen
          </button>
        )}
      </div>
    </div>
  );
}

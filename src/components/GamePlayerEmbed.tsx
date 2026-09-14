/**
 * GamePlayerEmbed — game iframe + docked player toolbar (fullscreen always reachable).
 * Play / fullscreen never navigate away or change the iframe src.
 */
import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from 'react';
import {
  anyGamepadActivity,
  focusGameIframe,
  GAME_EMBED_ALLOW,
  hasConnectedGamepad,
  installIframeGamepadBridge,
  isGameControlKey,
  isTypingTarget,
  setGameEmbedActiveDocument,
  setGameEmbedFullscreenDocument,
} from '../lib/gameEmbedInput';

type Props = {
  title: string;
  src: string;
  /** Standalone Godot page used for iPhone Add to Home Screen + offline save. */
  installHref?: string;
};

export type GamePlayerHandle = {
  enterFullscreen: () => void;
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

export const GamePlayerEmbed = forwardRef<GamePlayerHandle, Props>(function GamePlayerEmbed(
  { title, src, installHref },
  ref,
) {
  const shellRef = useRef<HTMLDivElement>(null);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [fs, setFs] = useState(false);
  const [pseudoFs, setPseudoFs] = useState(false);
  const [engaged, setEngaged] = useState(false);

  const isFullscreen = fs || pseudoFs;

  const nudgeGameInput = useCallback(() => {
    const iframe = iframeRef.current;
    installIframeGamepadBridge(iframe);
    focusGameIframe(iframe);
  }, []);

  const engage = useCallback(() => {
    setEngaged(true);
    requestAnimationFrame(() => {
      nudgeGameInput();
    });
  }, [nudgeGameInput]);

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
      const nowFs = getFullscreenElement() === shellRef.current;
      setFs(nowFs);
      if (nowFs) {
        setEngaged(true);
        requestAnimationFrame(() => {
          nudgeGameInput();
          requestAnimationFrame(nudgeGameInput);
        });
      }
    };
    document.addEventListener('fullscreenchange', sync);
    document.addEventListener('webkitfullscreenchange', sync as EventListener);
    return () => {
      document.removeEventListener('fullscreenchange', sync);
      document.removeEventListener('webkitfullscreenchange', sync as EventListener);
    };
  }, [nudgeGameInput]);

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
      if (anyGamepadActivity() || (isFullscreen && hasConnectedGamepad())) {
        engage();
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [engaged, engage, isFullscreen]);

  useEffect(() => {
    if (!engaged) {
      return undefined;
    }
    let raf = 0;
    const tick = () => {
      const iframe = iframeRef.current;
      if (!iframe) {
        raf = requestAnimationFrame(tick);
        return;
      }
      const toolbarActive = document.activeElement?.closest('.game-embed-toolbar');
      const shouldHold =
        isFullscreen && hasConnectedGamepad()
          ? !toolbarActive
          : anyGamepadActivity();
      if (document.activeElement !== iframe && shouldHold) {
        nudgeGameInput();
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [engaged, isFullscreen, nudgeGameInput]);

  useEffect(() => {
    const onPad = () => {
      if (isFullscreen) {
        engage();
      }
      requestAnimationFrame(nudgeGameInput);
    };
    window.addEventListener('gamepadconnected', onPad);
    return () => window.removeEventListener('gamepadconnected', onPad);
  }, [engage, isFullscreen, nudgeGameInput]);

  useEffect(() => {
    if (!isFullscreen) {
      return undefined;
    }
    engage();
    const t1 = window.setTimeout(nudgeGameInput, 0);
    const t2 = window.setTimeout(nudgeGameInput, 120);
    const t3 = window.setTimeout(nudgeGameInput, 400);
    return () => {
      window.clearTimeout(t1);
      window.clearTimeout(t2);
      window.clearTimeout(t3);
    };
  }, [isFullscreen, engage, nudgeGameInput]);

  const enterFullscreen = useCallback(() => {
    const el = shellRef.current as FullscreenElement | null;
    if (!el) {
      return;
    }
    engage();
    const afterEnter = () => {
      requestAnimationFrame(() => {
        nudgeGameInput();
        requestAnimationFrame(nudgeGameInput);
      });
    };
    if (isIPhone()) {
      setPseudoFs(true);
      afterEnter();
      return;
    }
    try {
      const req = el.requestFullscreen?.() ?? el.webkitRequestFullscreen?.();
      if (req && typeof (req as Promise<void>).then === 'function') {
        void Promise.resolve(req)
          .then(afterEnter)
          .catch(() => {
            setPseudoFs(true);
            afterEnter();
          });
        return;
      }
    } catch {
      /* fall through */
    }
    setPseudoFs(true);
    afterEnter();
  }, [engage, nudgeGameInput]);

  const exitFullscreen = useCallback(() => {
    if (pseudoFs) {
      setPseudoFs(false);
    }
    if (getFullscreenElement()) {
      tryNativeExit();
    }
  }, [pseudoFs]);

  useImperativeHandle(ref, () => ({ enterFullscreen }), [enterFullscreen]);

  const onShellPointerDown = useCallback(
    (e: React.PointerEvent) => {
      if ((e.target as HTMLElement).closest('.game-embed-toolbar, .game-embed-play-gate')) {
        return;
      }
      if (!engaged) {
        engage();
      } else {
        nudgeGameInput();
      }
    },
    [engaged, engage, nudgeGameInput],
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
          onLoad={() => {
            installIframeGamepadBridge(iframeRef.current);
            if (engaged || isFullscreen) {
              focusGameIframe(iframeRef.current);
            }
          }}
        />
        {!engaged ? (
          <button type="button" className="game-embed-play-gate" onPointerUp={engage}>
            <span className="game-embed-play-gate__title">Tap to play</span>
            <span className="game-embed-play-gate__hint">
              Starts this game here. It will not open a new page or reload.
            </span>
          </button>
        ) : null}
      </div>

      <div className="game-embed-toolbar" role="toolbar" aria-label="Game player">
        <span className="game-embed-toolbar__hint">
          {isFullscreen
            ? 'Fullscreen — controller stays with the game'
            : engaged
              ? 'Playing — scroll down for game info'
              : 'Tap the game to start. Fullscreen stays on this page.'}
        </span>
        <div className="game-embed-toolbar__actions">
          {installHref && !isFullscreen ? (
            <a
              className="game-embed-fs-btn game-embed-install-btn"
              href={installHref}
              target="_blank"
              rel="noopener noreferrer"
            >
              Save to iPhone
            </a>
          ) : null}
          {isFullscreen ? (
            <button
              type="button"
              className="game-embed-fs-btn"
              onClick={exitFullscreen}
              aria-label="Exit fullscreen"
            >
              Exit
            </button>
          ) : (
            <button
              type="button"
              className="game-embed-fs-btn"
              onClick={enterFullscreen}
              aria-label="Enter fullscreen"
            >
              Fullscreen
            </button>
          )}
        </div>
      </div>
    </div>
  );
});


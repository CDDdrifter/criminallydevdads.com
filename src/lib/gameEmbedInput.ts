/**
 * Helpers so keyboard / gamepad input reaches Godot (and other) games inside our play iframe.
 * Browsers only route keys to the embedded document when the iframe has focus; gamepads on
 * the web often need a user gesture + focus before Godot sees them.
 */

/** Permissions Policy on the play iframe — keep in sync with GamePlayerEmbed. */
export const GAME_EMBED_ALLOW =
  'fullscreen; gamepad *; autoplay; gyroscope; accelerometer; xr-spatial-tracking; pointer-lock; keyboard-map';

const GAME_KEY_CODES = new Set([
  'Space',
  'ArrowUp',
  'ArrowDown',
  'ArrowLeft',
  'ArrowRight',
  'KeyW',
  'KeyA',
  'KeyS',
  'KeyD',
  'KeyE',
  'KeyQ',
  'KeyR',
  'KeyF',
  'ShiftLeft',
  'ShiftRight',
  'ControlLeft',
  'ControlRight',
  'Tab',
  'Enter',
  'NumpadEnter',
  'Digit1',
  'Digit2',
  'Digit3',
  'Digit4',
  'Digit5',
  'Digit6',
  'Digit7',
  'Digit8',
  'Digit9',
  'Digit0',
]);

/** Keys that commonly scroll the hub page instead of reaching the game. */
export function isGameControlKey(e: KeyboardEvent): boolean {
  if (e.code && GAME_KEY_CODES.has(e.code)) {
    return true;
  }
  if (e.key === ' ' || e.key === 'Spacebar') {
    return true;
  }
  return e.key.length === 1 && /^[wasdzxqe rf]$/i.test(e.key);
}

export function isTypingTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) {
    return false;
  }
  const tag = target.tagName;
  if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') {
    return true;
  }
  return target.isContentEditable;
}

export function focusGameIframe(iframe: HTMLIFrameElement | null | undefined): void {
  if (!iframe) {
    return;
  }
  try {
    iframe.focus({ preventScroll: true });
  } catch {
    iframe.focus();
  }
}

export function anyGamepadButtonPressed(): boolean {
  const getPads = navigator.getGamepads?.bind(navigator);
  if (!getPads) {
    return false;
  }
  const pads = getPads();
  for (const pad of pads) {
    if (!pad) {
      continue;
    }
    for (const btn of pad.buttons) {
      if (btn.pressed) {
        return true;
      }
    }
  }
  return false;
}

export function setGameEmbedActiveDocument(active: boolean): void {
  if (active) {
    document.documentElement.dataset.gameEmbedActive = 'on';
  } else {
    delete document.documentElement.dataset.gameEmbedActive;
  }
}

/** Locks page scroll only while the player is in true fullscreen (native or pseudo). */
export function setGameEmbedFullscreenDocument(active: boolean): void {
  if (active) {
    document.documentElement.dataset.gameEmbedFs = 'on';
  } else {
    delete document.documentElement.dataset.gameEmbedFs;
  }
}

const HUB_VIEWPORT = 'width=device-width, initial-scale=1.0, viewport-fit=cover';
const GAME_VIEWPORT =
  'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';

/** Stops iPhone pinch-zoom from eating the 2nd/3rd finger while a game is playing. */
export function setHubViewportForGame(lock: boolean): void {
  const meta = document.querySelector('meta[name="viewport"]');
  if (!meta) {
    return;
  }
  meta.setAttribute('content', lock ? GAME_VIEWPORT : HUB_VIEWPORT);
}

export function touchOverlapsElement(touch: Touch, el: HTMLElement): boolean {
  const r = el.getBoundingClientRect();
  return touch.clientX >= r.left && touch.clientX <= r.right && touch.clientY >= r.top && touch.clientY <= r.bottom;
}

/**
 * Keep hub scroll / pinch from stealing extra fingers meant for Godot
 * (move stick + aim + jump + dash at the same time).
 */
export function attachGameEmbedTouchGuard(opts: {
  getStage: () => HTMLElement | null;
  isActive: () => boolean;
  isFullscreen: () => boolean;
}): () => void {
  const stageTouches = new Set<number>();

  const trackIfGameTouch = (touch: Touch) => {
    const stage = opts.getStage();
    if (!stage) {
      return;
    }
    if (opts.isFullscreen() || touchOverlapsElement(touch, stage)) {
      stageTouches.add(touch.identifier);
    }
  };

  const onStart = (e: TouchEvent) => {
    if (!opts.isActive()) {
      return;
    }
    for (let i = 0; i < e.changedTouches.length; i++) {
      trackIfGameTouch(e.changedTouches[i]!);
    }
  };

  const shouldBlockBrowserGesture = (e: TouchEvent) => {
    if (!opts.isActive()) {
      return false;
    }
    if (opts.isFullscreen()) {
      return true;
    }
    const stage = opts.getStage();
    if (!stage) {
      return false;
    }
    for (let i = 0; i < e.touches.length; i++) {
      const t = e.touches[i]!;
      if (stageTouches.has(t.identifier) || touchOverlapsElement(t, stage)) {
        return true;
      }
    }
    return false;
  };

  const onMove = (e: TouchEvent) => {
    if (shouldBlockBrowserGesture(e)) {
      e.preventDefault();
    }
  };

  const onEnd = (e: TouchEvent) => {
    for (let i = 0; i < e.changedTouches.length; i++) {
      stageTouches.delete(e.changedTouches[i]!.identifier);
    }
  };

  const preventGesture = (e: Event) => {
    if (opts.isActive()) {
      e.preventDefault();
    }
  };

  const optsPassive = { passive: false, capture: true } as const;
  document.addEventListener('touchstart', onStart, optsPassive);
  document.addEventListener('touchmove', onMove, optsPassive);
  document.addEventListener('touchend', onEnd, optsPassive);
  document.addEventListener('touchcancel', onEnd, optsPassive);
  document.addEventListener('gesturestart', preventGesture, optsPassive);
  document.addEventListener('gesturechange', preventGesture, optsPassive);
  document.addEventListener('gestureend', preventGesture, optsPassive);

  return () => {
    document.removeEventListener('touchstart', onStart, optsPassive);
    document.removeEventListener('touchmove', onMove, optsPassive);
    document.removeEventListener('touchend', onEnd, optsPassive);
    document.removeEventListener('touchcancel', onEnd, optsPassive);
    document.removeEventListener('gesturestart', preventGesture, optsPassive);
    document.removeEventListener('gesturechange', preventGesture, optsPassive);
    document.removeEventListener('gestureend', preventGesture, optsPassive);
    stageTouches.clear();
  };
}

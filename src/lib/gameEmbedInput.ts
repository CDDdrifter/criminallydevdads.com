/**
 * Helpers so keyboard / gamepad input reaches Godot (and other) games inside our play iframe.
 * Browsers only route keys to the embedded document when the iframe has focus; gamepads on
 * the web often need a user gesture + focus before Godot sees them.
 *
 * Fullscreen on the hub shell is especially picky: Chrome keeps pads on the parent document,
 * so we refocus the iframe + inner canvas and (same-origin) fall back to the parent's pads.
 */

/** Permissions Policy on the play iframe — keep in sync with GamePlayerEmbed. */
export const GAME_EMBED_ALLOW =
  'fullscreen; fullscreen *; gamepad; gamepad *; autoplay; gyroscope; accelerometer; xr-spatial-tracking; pointer-lock; keyboard-map';

/** Posted into the game frame so Godot can grab canvas focus after hub fullscreen. */
export const GAME_FOCUS_MESSAGE = 'cdd-game-focus';

/** Posted so the game can re-read pads after the hub sees a controller. */
export const GAMEPAD_SYNC_MESSAGE = 'cdd-gamepad-sync';

const AXIS_DEADZONE = 0.24;

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
  try {
    iframe.contentWindow?.focus();
  } catch {
    /* cross-origin */
  }
  try {
    const doc = iframe.contentDocument;
    const canvas =
      (doc?.getElementById('canvas') as HTMLElement | null) ?? doc?.querySelector('canvas');
    if (canvas) {
      if (!canvas.hasAttribute('tabindex')) {
        canvas.setAttribute('tabindex', '0');
      }
      canvas.focus({ preventScroll: true });
    }
  } catch {
    /* cross-origin */
  }
  try {
    iframe.contentWindow?.postMessage({ type: GAME_FOCUS_MESSAGE }, '*');
  } catch {
    /* ignore */
  }
}

function padListHasDevice(pads: ArrayLike<Gamepad | null>): boolean {
  for (let i = 0; i < pads.length; i += 1) {
    if (pads[i]) {
      return true;
    }
  }
  return false;
}

function listGamepads(): (Gamepad | null)[] {
  const getPads = navigator.getGamepads?.bind(navigator);
  if (!getPads) {
    return [];
  }
  return Array.from(getPads());
}

export function hasConnectedGamepad(): boolean {
  return listGamepads().some(Boolean);
}

export function anyGamepadActivity(): boolean {
  for (const pad of listGamepads()) {
    if (!pad) {
      continue;
    }
    for (const btn of pad.buttons) {
      if (btn.pressed || btn.value > 0.15) {
        return true;
      }
    }
    for (const axis of pad.axes) {
      if (Math.abs(axis) > AXIS_DEADZONE) {
        return true;
      }
    }
  }
  return false;
}

export function anyGamepadButtonPressed(): boolean {
  return anyGamepadActivity();
}

/**
 * Same-origin: Godot polls the iframe's navigator.getGamepads(). Chrome often
 * keeps live pads on the parent (user gesture / fullscreen), so prefer those.
 */
export function installIframeGamepadBridge(iframe: HTMLIFrameElement | null | undefined): void {
  if (!iframe) {
    return;
  }
  try {
    const win = iframe.contentWindow as (Window & { __cddGamepadBridge?: boolean }) | null;
    if (!win || win.__cddGamepadBridge || !win.navigator.getGamepads) {
      return;
    }
    const localGet = win.navigator.getGamepads.bind(win.navigator);
    const parentGet = navigator.getGamepads?.bind(navigator);
    win.navigator.getGamepads = function patchedGetGamepads() {
      let parentPads: ReturnType<Navigator['getGamepads']> | null = null;
      try {
        parentPads = parentGet ? parentGet() : null;
      } catch {
        parentPads = null;
      }
      if (parentPads && padListHasDevice(parentPads)) {
        return parentPads;
      }
      return localGet();
    };
    win.__cddGamepadBridge = true;
  } catch {
    /* cross-origin */
  }
}

/** Patch getGamepads, focus the canvas, and tell Godot to (re)scan controllers. */
export function syncIframeGamepads(iframe: HTMLIFrameElement | null | undefined): void {
  installIframeGamepadBridge(iframe);
  focusGameIframe(iframe);
  try {
    iframe?.contentWindow?.postMessage({ type: GAMEPAD_SYNC_MESSAGE }, '*');
  } catch {
    /* ignore */
  }
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

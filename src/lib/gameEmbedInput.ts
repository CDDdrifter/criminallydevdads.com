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

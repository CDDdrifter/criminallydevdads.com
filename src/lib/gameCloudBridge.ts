/**
 * Exposes cloud save helpers on `window.CDD` for embedded games (same-origin
 * parent or games that call parent.postMessage). Hub games can also import
 * `loadGameSave` / `saveGameSave` from communityData when bundled with the site.
 */
import { loadGameSave, saveGameSave } from './communityData';

export type CddBridge = {
  isSignedIn: () => boolean;
  getUserId: () => string | null;
  loadSave: (gameSlug: string) => Promise<Record<string, unknown> | null>;
  saveSave: (gameSlug: string, data: Record<string, unknown>) => Promise<boolean>;
};

declare global {
  interface Window {
    CDD?: CddBridge;
  }
}

export function installGameCloudBridge(getUserId: () => string | null) {
  const bridge: CddBridge = {
    isSignedIn: () => Boolean(getUserId()),
    getUserId,
    loadSave: async (gameSlug) => {
      const uid = getUserId();
      if (!uid) return null;
      return loadGameSave(uid, gameSlug);
    },
    saveSave: async (gameSlug, data) => {
      const uid = getUserId();
      if (!uid) return false;
      return saveGameSave(uid, gameSlug, data);
    },
  };
  window.CDD = bridge;
}

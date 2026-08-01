/**
 * Firebase — Auth, Firestore, and Storage.
 *
 * Config loads from cms/firebase-config.json at runtime (copied to dist/cms/ on deploy).
 * Firebase client keys are public — security is via Authorized domains + Security Rules.
 * VITE_FIREBASE_* env vars are an optional build-time fallback.
 */
import { initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';
import { getFirestore, type Firestore } from 'firebase/firestore';
import { getStorage, type FirebaseStorage } from 'firebase/storage';
import bundledConfig from '../../cms/firebase-config.json';
import { fetchStaticJson } from './staticCms';

export type FirebasePublicConfig = {
  apiKey?: string;
  authDomain?: string;
  projectId?: string;
  appId?: string;
  storageBucket?: string;
};

let app: FirebaseApp | null = null;
let auth: Auth | null = null;
let db: Firestore | null = null;
let storage: FirebaseStorage | null = null;
let initPromise: Promise<boolean> | null = null;
let configured = false;

function trim(v: unknown): string {
  return typeof v === 'string' ? v.trim() : '';
}

function configFromEnv(): FirebasePublicConfig {
  return {
    apiKey: trim(import.meta.env.VITE_FIREBASE_API_KEY),
    authDomain: trim(import.meta.env.VITE_FIREBASE_AUTH_DOMAIN),
    projectId: trim(import.meta.env.VITE_FIREBASE_PROJECT_ID),
    appId: trim(import.meta.env.VITE_FIREBASE_APP_ID),
    storageBucket: trim(import.meta.env.VITE_FIREBASE_STORAGE_BUCKET),
  };
}

function isComplete(cfg: FirebasePublicConfig): boolean {
  return Boolean(cfg.apiKey && cfg.authDomain && cfg.projectId);
}

function defaultStorageBucket(projectId: string): string {
  return `${projectId}.appspot.com`;
}

function applyConfig(cfg: FirebasePublicConfig): boolean {
  if (!isComplete(cfg)) {
    configured = false;
    return false;
  }
  if (!app) {
    const projectId = cfg.projectId!;
    app = initializeApp({
      apiKey: cfg.apiKey!,
      authDomain: cfg.authDomain!,
      projectId,
      appId: cfg.appId || undefined,
      storageBucket: cfg.storageBucket || defaultStorageBucket(projectId),
    });
    auth = getAuth(app);
    db = getFirestore(app);
    storage = getStorage(app);
  }
  configured = true;
  return true;
}

/** Load Firebase once — file first, then Vite env fallback. */
export async function initFirebase(): Promise<boolean> {
  if (configured && auth && db) {
    return true;
  }
  if (initPromise) {
    return initPromise;
  }

  initPromise = (async () => {
    const fromFile = await fetchStaticJson<FirebasePublicConfig>('cms/firebase-config.json');
    if (fromFile && isComplete(fromFile)) {
      return applyConfig(fromFile);
    }
    const fromEnv = configFromEnv();
    if (isComplete(fromEnv)) {
      return applyConfig(fromEnv);
    }
    configured = false;
    return false;
  })();

  return initPromise;
}

function bootstrapFirebaseSync(): boolean {
  const fromFile = bundledConfig as FirebasePublicConfig;
  if (isComplete(fromFile)) {
    return applyConfig(fromFile);
  }
  const fromEnv = configFromEnv();
  if (isComplete(fromEnv)) {
    return applyConfig(fromEnv);
  }
  return false;
}

// Sync init so getRedirectResult can run immediately on OAuth return (no fetch wait).
bootstrapFirebaseSync();

/** Sync check — only true after initFirebase() succeeds. */
export function isFirebaseReady(): boolean {
  return configured && auth !== null && db !== null;
}

/** @deprecated Use initFirebase() + isFirebaseReady() or useAuth().authConfigured */
export const firebaseConfigured = isComplete(configFromEnv());

export { app, auth, db, storage };

/**
 * Unified backend flag — true when Firebase (Auth + Firestore) is ready.
 * Replaces legacy `supabaseConfigured` checks across the app.
 */
import { isFirebaseReady } from './firebase';

/** Sync check after initFirebase() has resolved. */
export function backendConfigured(): boolean {
  return isFirebaseReady();
}

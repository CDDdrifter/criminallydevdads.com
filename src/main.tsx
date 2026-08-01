/**
 * Entry: finish Google redirect sign-in before loading the React bundle,
 * then mount the app. Redirect state is origin-scoped and must be consumed ASAP.
 */
import { browserLocalPersistence, setPersistence } from 'firebase/auth';
import { bootstrapSpaAuthPaths } from './lib/authBootstrap';
import { auth } from './lib/firebase';
import {
  cleanFirebaseAuthParamsFromUrl,
  completeRedirectSignIn,
  isFirebaseRedirectReturn,
} from './lib/firebaseAuthBootstrap';

bootstrapSpaAuthPaths();

void (async () => {
  if (auth) {
    try {
      await setPersistence(auth, browserLocalPersistence);
      const redirectResult = await completeRedirectSignIn(auth);
      if (redirectResult?.user || auth.currentUser || !isFirebaseRedirectReturn()) {
        cleanFirebaseAuthParamsFromUrl();
      }
    } catch (err) {
      console.error('[auth] redirect sign-in failed on load', err);
    }
  }

  const { mountApp } = await import('./main-app');
  await mountApp();
})();

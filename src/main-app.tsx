import ReactDOM from 'react-dom/client';
import { RootErrorBoundary } from './components/RootErrorBoundary';
import { AuthProvider } from './context/AuthContext';
import { SiteSettingsProvider } from './context/SiteSettingsContext';
import { App } from './App';
import { popAuthReturn } from './lib/authBootstrap';
import { auth, initFirebase } from './lib/firebase';
import { cleanFirebaseAuthParamsFromUrl, completeRedirectSignIn } from './lib/firebaseAuthBootstrap';
import './index.css';

export async function mountApp() {
  await initFirebase();

  if (auth) {
    try {
      const redirectResult = await completeRedirectSignIn(auth);
      cleanFirebaseAuthParamsFromUrl();
      if (redirectResult?.user) {
        const returnPath = popAuthReturn();
        if (returnPath && returnPath !== window.location.pathname) {
          window.history.replaceState(window.history.state, '', returnPath);
        }
      }
    } catch (err) {
      console.error('[auth] redirect sign-in failed on load', err);
    }
  }

  ReactDOM.createRoot(document.getElementById('root')!).render(
    <RootErrorBoundary>
      <AuthProvider>
        <SiteSettingsProvider>
          <App />
        </SiteSettingsProvider>
      </AuthProvider>
    </RootErrorBoundary>,
  );
}

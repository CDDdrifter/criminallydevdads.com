import ReactDOM from 'react-dom/client';
import { RootErrorBoundary } from './components/RootErrorBoundary';
import { AuthProvider } from './context/AuthContext';
import { SiteSettingsProvider } from './context/SiteSettingsContext';
import { App } from './App';
import './index.css';

export async function mountApp() {
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

import React from 'react';
import ReactDOM from 'react-dom/client';
import { bootstrapSpaAuthPaths } from './lib/authBootstrap';
import { RootErrorBoundary } from './components/RootErrorBoundary';

bootstrapSpaAuthPaths();
import { AuthProvider } from './context/AuthContext';
import { SiteSettingsProvider } from './context/SiteSettingsContext';
import { App } from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <RootErrorBoundary>
      <AuthProvider>
        <SiteSettingsProvider>
          <App />
        </SiteSettingsProvider>
      </AuthProvider>
    </RootErrorBoundary>
  </React.StrictMode>,
);

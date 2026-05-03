import React from 'react';
import ReactDOM from 'react-dom/client';
import { RootErrorBoundary } from './components/RootErrorBoundary';
import { AuthProvider } from './context/AuthContext';
import { App } from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <RootErrorBoundary>
      <AuthProvider>
        <App />
      </AuthProvider>
    </RootErrorBoundary>
  </React.StrictMode>,
);

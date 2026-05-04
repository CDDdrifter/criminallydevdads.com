import { Component, type ErrorInfo, type ReactNode } from 'react';

type Props = { children: ReactNode };

type State = { error: Error | null };

/**
 * If React crashes (e.g. bad data shape from an API), show something instead of a blank page + gradient only.
 */
export class RootErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Root error boundary:', error, info.componentStack);
  }

  render() {
    if (this.state.error) {
      return (
        <div
          style={{
            minHeight: '100vh',
            padding: 32,
            color: '#d6deff',
            fontFamily: 'Consolas, monospace',
            maxWidth: 640,
            margin: '0 auto',
            lineHeight: 1.6,
          }}
        >
          <h1 style={{ fontSize: '1.25rem', marginBottom: 16 }}>Something broke on this page</h1>
          <p style={{ color: '#7f8ba7', marginBottom: 16 }}>
            Open the browser console (F12 → Console) for the technical error.
          </p>
          <p style={{ color: '#7f8ba7', marginBottom: 16 }}>
            If this started after adding <strong>GitHub Actions secrets</strong>, try{' '}
            <strong>removing</strong> <code>VITE_SUPABASE_URL</code> and{' '}
            <code>VITE_SUPABASE_ANON_KEY</code>, then re-run the deploy — the hub works without them
            (file-based games). Add the secrets back using <code>docs/SUPABASE_COPY_THESE_TWO_VALUES.md</code>{' '}
            (no extra quotes or spaces).
          </p>
          <pre
            style={{
              background: '#0d111a',
              padding: 16,
              borderRadius: 8,
              overflow: 'auto',
              fontSize: 12,
              border: '1px solid rgba(115, 248, 255, 0.25)',
            }}
          >
            {this.state.error.message}
          </pre>
        </div>
      );
    }
    return this.props.children;
  }
}

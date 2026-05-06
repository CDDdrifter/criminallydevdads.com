import { Link, useSearchParams } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';

export function PurchaseSuccessPage() {
  const [params] = useSearchParams();
  const sessionId = params.get('session_id');

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <article className="admin-panel page-article" style={{ maxWidth: 560, margin: '0 auto' }}>
        <h1 className="header-title" style={{ fontSize: '1.75rem', marginBottom: 12 }}>
          Thank you
        </h1>
        <p className="admin-muted" style={{ lineHeight: 1.6 }}>
          Your payment was submitted through Stripe. You should receive a receipt by email from Stripe if you entered
          an address at checkout.
        </p>
        {sessionId ? (
          <p className="admin-muted" style={{ fontSize: '0.85rem', wordBreak: 'break-all' }}>
            Reference: <code>{sessionId}</code>
          </p>
        ) : null}
        <p style={{ marginTop: 24 }}>
          <Link to="/" className="btn-play" style={{ display: 'inline-block', textAlign: 'center' }}>
            Back to hub
          </Link>
        </p>
        <p className="admin-muted" style={{ marginTop: 16, fontSize: '0.82rem' }}>
          <Link to="/purchase/terms">Purchase terms</Link>
        </p>
      </article>
    </SiteChrome>
  );
}

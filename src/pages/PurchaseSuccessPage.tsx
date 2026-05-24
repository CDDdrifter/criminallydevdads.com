/**
 * Stripe success redirect target (HashRouter): /#/purchase/success?session_id=...
 * Must stay in sync with SITE_URL + path in supabase/functions/create-checkout-session/index.ts.
 */
import { Link, useSearchParams } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';

export function PurchaseSuccessPage() {
  const [params] = useSearchParams();
  const sessionId = params.get('session_id');
  const kind = params.get('kind');
  const slug = params.get('slug');

  const isService = kind === 'service';

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <article className="admin-panel page-article" style={{ maxWidth: 560, margin: '0 auto' }}>
        <h1 className="header-title" style={{ fontSize: '1.75rem', marginBottom: 12 }}>
          Thank you
        </h1>
        <p className="admin-muted" style={{ lineHeight: 1.6 }}>
          Your payment was submitted through Stripe
          {isService ? ' for our services' : ''}. You should receive a receipt by email from Stripe if you entered an
          address at checkout.
          {isService ? ' We will follow up about your order or project brief soon.' : ''}
        </p>
        {slug && isService ? (
          <p className="admin-muted" style={{ fontSize: '0.88rem' }}>
            Item: <code>{slug}</code>
          </p>
        ) : null}
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

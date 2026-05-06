import { Link } from 'react-router-dom';
import { SiteChrome } from '../components/SiteChrome';

/**
 * Plain-language terms for digital goods — not a substitute for advice from a qualified attorney.
 */
export function PurchaseTermsPage() {
  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <article className="admin-panel page-article" style={{ maxWidth: 640, margin: '0 auto' }}>
        <h1 className="header-title" style={{ fontSize: '1.75rem', marginBottom: 12 }}>
          Digital purchases
        </h1>
        <div className="admin-muted" style={{ lineHeight: 1.65, whiteSpace: 'pre-wrap' }}>
          {`Payments on this site are processed by Stripe. When you buy or donate, you are charged by Stripe according to the amount shown at checkout.

Digital goods (games, assets, or other downloads) may be delivered as described on each product page — for example via play on this site, download links, or keys sent by email, depending on how we configure that title.

Refunds: contact us using the support options on the site. Where required by law, consumer rights still apply.

Taxes: prices may be shown excluding tax; Stripe may calculate and collect tax depending on your location and our Stripe settings.

If something looks wrong with a charge, use your Stripe receipt to identify the payment and reach out through our support page.`}
        </div>
        <p style={{ marginTop: 24 }}>
          <Link to="/">← Back to hub</Link>
        </p>
      </article>
    </SiteChrome>
  );
}

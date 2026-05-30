/**
 * PurchaseConsent — required Terms + Refund acceptance checkbox shown above buy
 * buttons. Driven by `site_settings.legal`. When `required` is false it renders
 * nothing so non-commerce flows are unaffected. Policy names in the notice link
 * to the matching legal pages configured in the legal footer.
 */
import { Fragment, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useSiteSettings } from '../hooks/useSiteSettings';

/** Replace "Terms of Service" / "Refund Policy" mentions with links to their pages. */
function linkifyNotice(notice: string, links: { label: string; href: string }[]): ReactNode {
  if (links.length === 0) return notice;
  // Build a regex of known labels (longest first to avoid partial overlaps).
  const labels = links.map((l) => l.label).sort((a, b) => b.length - a.length);
  const escaped = labels.map((l) => l.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  const re = new RegExp(`(${escaped.join('|')})`, 'g');
  const parts = notice.split(re);
  return parts.map((part, i) => {
    const match = links.find((l) => l.label === part);
    if (!match) return <Fragment key={i}>{part}</Fragment>;
    return match.href.startsWith('/') ? (
      <Link key={i} to={match.href} target="_blank" style={{ textDecoration: 'underline' }}>
        {part}
      </Link>
    ) : (
      <a key={i} href={match.href} target="_blank" rel="noreferrer" style={{ textDecoration: 'underline' }}>
        {part}
      </a>
    );
  });
}

export function PurchaseConsent({
  required,
  agreed,
  onChange,
}: {
  required: boolean;
  agreed: boolean;
  onChange: (next: boolean) => void;
}) {
  const { settings } = useSiteSettings();
  if (!required) return null;
  const legal = settings.legal;
  const notice = legal?.purchase_consent_notice?.trim() || 'I agree to the Terms of Service and Refund Policy.';

  return (
    <label
      className="purchase-consent admin-row"
      style={{ gap: 8, alignItems: 'flex-start', margin: '4px 0 10px', fontSize: '0.82rem', lineHeight: 1.45 }}
    >
      <input
        type="checkbox"
        checked={agreed}
        onChange={(e) => onChange(e.target.checked)}
        style={{ marginTop: 3 }}
      />
      <span>{linkifyNotice(notice, legal?.links ?? [])}</span>
    </label>
  );
}

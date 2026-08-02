/**
 * LegalStudio — configures `site_settings.legal`: business identity, the
 * site-wide legal footer + policy links, the purchase consent gate (Terms +
 * Refund acceptance before checkout), and the cookie banner. Writes via
 * setSettings; the floating save bar persists.
 *
 * Not legal advice — these are switches to surface policies and require
 * agreement. Pair with the seeded CMS policy pages (migration 031).
 */
import { newSectionId } from '../../../lib/pageSections';
import type { LegalConfig, LegalLink, SiteSettings } from '../../../types';
import { defaultLegalConfig } from '../../../types';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

const SUGGESTED_LINKS: { label: string; href: string }[] = [
  { label: 'Terms of Service', href: '/p/terms' },
  { label: 'Privacy Policy', href: '/p/privacy' },
  { label: 'Refund Policy', href: '/p/refund' },
  { label: 'Cookie Policy', href: '/p/cookie' },
  { label: 'DMCA / Copyright', href: '/p/dmca' },
  { label: 'Disclaimer', href: '/p/disclaimer' },
  { label: 'Acceptable Use', href: '/p/acceptable-use' },
];

export function LegalStudio({ settings, setSettings }: Props) {
  const legal = settings.legal ?? defaultLegalConfig();
  const patch = (p: Partial<LegalConfig>) => setSettings({ ...settings, legal: { ...legal, ...p } });

  const addLink = (label = '', href = '') =>
    patch({ links: [...legal.links, { id: newSectionId(), label, href }] });
  const patchLink = (id: string, p: Partial<LegalLink>) =>
    patch({ links: legal.links.map((l) => (l.id === id ? { ...l, ...p } : l)) });

  const existingHrefs = new Set(legal.links.map((l) => l.href));

  return (
    <div className="admin-grid" style={{ gap: 20 }}>
      <div className="admin-panel">
        <h2 style={{ margin: '0 0 8px', fontSize: '1rem', color: 'var(--accent)' }}>⚖️ Legal & policies</h2>
        <p className="admin-muted" style={{ marginTop: 0, fontSize: '0.88rem', lineHeight: 1.55 }}>
          Surface your policies in the site-wide footer, require buyers to accept Terms + Refund before checkout, and
          show a cookie banner. Edit the policy page text under <strong>Pages</strong> (slugs: terms, privacy, refund,
          cookie). Save with the floating bar. Have a qualified professional review before accepting payments.
        </p>
      </div>

      <div className="admin-panel admin-grid">
        <h3 style={{ gridColumn: '1 / -1', margin: 0, fontSize: '0.9rem' }}>Business identity</h3>
        <div className="admin-field">
          <label htmlFor="lg_name">Legal / business name</label>
          <input id="lg_name" value={legal.business_name} onChange={(e) => patch({ business_name: e.target.value })} />
        </div>
        <div className="admin-field">
          <label htmlFor="lg_email">Contact email (legal / support)</label>
          <input
            id="lg_email"
            type="email"
            value={legal.contact_email}
            onChange={(e) => patch({ contact_email: e.target.value })}
            placeholder="hello@example.com"
          />
        </div>
      </div>

      <div className="admin-panel">
        <div className="admin-row" style={{ justifyContent: 'space-between', marginBottom: 8 }}>
          <h3 style={{ margin: 0, fontSize: '0.9rem' }}>Footer & policy links</h3>
          <label className="admin-row" style={{ gap: 8 }}>
            <input
              type="checkbox"
              checked={legal.show_footer}
              onChange={(e) => patch({ show_footer: e.target.checked })}
            />
            Show legal footer
          </label>
        </div>
        <p className="admin-muted" style={{ fontSize: '0.82rem', marginTop: 0 }}>
          Links appear in the site-wide footer. Point them at your CMS policy pages (e.g. <code>/p/terms</code>) or
          external URLs.
        </p>
        <div style={{ display: 'grid', gap: 8 }}>
          {legal.links.map((l) => (
            <div key={l.id} className="admin-row" style={{ gap: 6, flexWrap: 'wrap' }}>
              <input
                value={l.label}
                onChange={(e) => patchLink(l.id, { label: e.target.value })}
                placeholder="Label"
                style={{ flex: '1 1 160px' }}
              />
              <input
                value={l.href}
                onChange={(e) => patchLink(l.id, { href: e.target.value })}
                placeholder="/p/terms or https://…"
                style={{ flex: '1 1 200px' }}
              />
              <button type="button" onClick={() => patch({ links: legal.links.filter((x) => x.id !== l.id) })}>
                ✕
              </button>
            </div>
          ))}
        </div>
        <div className="admin-row" style={{ gap: 6, flexWrap: 'wrap', marginTop: 10 }}>
          <button type="button" onClick={() => addLink()}>+ Add link</button>
          {SUGGESTED_LINKS.filter((s) => !existingHrefs.has(s.href)).map((s) => (
            <button
              key={s.href}
              type="button"
              className="admin-muted"
              onClick={() => addLink(s.label, s.href)}
              title={`Add ${s.label}`}
            >
              + {s.label}
            </button>
          ))}
        </div>
      </div>

      <div className="admin-panel">
        <h3 style={{ margin: '0 0 8px', fontSize: '0.9rem' }}>Purchase consent gate</h3>
        <label className="admin-row" style={{ gap: 8, marginBottom: 10 }}>
          <input
            type="checkbox"
            checked={legal.require_purchase_consent}
            onChange={(e) => patch({ require_purchase_consent: e.target.checked })}
          />
          Require buyers to accept Terms + Refund before every checkout (games & services)
        </label>
        <div className="admin-field">
          <label htmlFor="lg_consent">Consent checkbox text</label>
          <textarea
            id="lg_consent"
            rows={3}
            value={legal.purchase_consent_notice}
            onChange={(e) => patch({ purchase_consent_notice: e.target.value })}
          />
          <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 6 }}>
            Mentions of your link labels (e.g. “Terms of Service”, “Refund Policy”) auto-link to the matching footer
            link. Keep no-refund language here to make it binding at the point of sale.
          </p>
        </div>
      </div>

      <div className="admin-panel">
        <h3 style={{ margin: '0 0 8px', fontSize: '0.9rem' }}>Cookie banner</h3>
        <label className="admin-row" style={{ gap: 8, marginBottom: 10 }}>
          <input
            type="checkbox"
            checked={legal.cookie_banner_enabled}
            onChange={(e) => patch({ cookie_banner_enabled: e.target.checked })}
          />
          Show dismissible cookie banner on first visit
        </label>
        <div className="admin-field">
          <label htmlFor="lg_cookie">Cookie banner text</label>
          <textarea
            id="lg_cookie"
            rows={3}
            value={legal.cookie_notice}
            onChange={(e) => patch({ cookie_notice: e.target.value })}
          />
        </div>
      </div>
    </div>
  );
}

import { useCallback, useEffect, useState } from 'react';
import {
  SERVICE_CATEGORY_OPTIONS,
  SERVICE_KIND_OPTIONS,
  SERVICE_PRICING_OPTIONS,
  deleteServiceSlug,
  fetchAllServicesAdmin,
  upsertService,
} from '../../../lib/servicesData';
import { adminListServiceRequests, type ServiceRequestRow } from '../../../lib/communityData';
import { donationPresetsFromUnknown } from '../../../lib/gamePricing';
import { ADMIN_AI_SERVICE_DRAFT_KEY } from '../../../lib/adminAi/types';
import type { ServicePricingModel, SiteService } from '../../../types';

function emptyService(): SiteService {
  return {
    slug: '',
    title: '',
    tagline: '',
    description: '',
    category: 'other',
    kind: 'service',
    icon_emoji: '✨',
    image_url: '',
    features: [],
    deliverables: '',
    turnaround: '',
    pricing_model: 'quote',
    price_cents: null,
    stripe_price_id: null,
    purchase_url: null,
    gumroad_url: null,
    pwyw_min_cents: 50,
    pwyw_suggested_cents: null,
    donation_presets_cents: [],
    cta_label: 'Get started',
    request_only: true,
    request_form_enabled: true,
    published: true,
    show_on_services_hub: true,
    sort_order: 100,
  };
}

export function ServicesAdminTab() {
  const [list, setList] = useState<SiteService[]>([]);
  const [draft, setDraft] = useState<SiteService>(emptyService());
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [requests, setRequests] = useState<ServiceRequestRow[]>([]);

  const reload = useCallback(async () => {
    setList(await fetchAllServicesAdmin());
    setRequests(await adminListServiceRequests(80));
  }, []);

  useEffect(() => {
    void reload();
  }, [reload]);

  useEffect(() => {
    try {
      const raw = sessionStorage.getItem(ADMIN_AI_SERVICE_DRAFT_KEY);
      if (!raw) return;
      sessionStorage.removeItem(ADMIN_AI_SERVICE_DRAFT_KEY);
      const parsed = JSON.parse(raw) as Partial<SiteService>;
      setDraft({ ...emptyService(), ...parsed, slug: String(parsed.slug ?? ''), title: String(parsed.title ?? '') });
      setMsg('Loaded draft from Admin AI — review and Save service.');
    } catch {
      /* ignore */
    }
  }, []);

  const featuresText = draft.features.join('\n');

  return (
    <div className="admin-grid" style={{ gap: 20 }}>
      <div className="admin-panel">
        <h2 style={{ margin: '0 0 8px', fontSize: '1rem', color: 'var(--accent)' }}>💼 Services &amp; gigs catalog</h2>
        <p className="admin-muted" style={{ marginTop: 0, lineHeight: 1.55, fontSize: '0.88rem' }}>
          Public page: <code>/#/services</code>. Tips, demos, builds, merch — each row can use Stripe (same Edge
          Function as games), external Payment Link / Gumroad, or quote-only with email request. Run migration{' '}
          <code>025_site_services_commerce.sql</code> once.
        </p>
      </div>

      <div className="admin-panel admin-grid">
        <h3 style={{ gridColumn: '1 / -1', margin: 0, fontSize: '0.9rem' }}>Edit offering</h3>
        <div className="admin-field">
          <label htmlFor="svc_slug">Slug (URL key)</label>
          <input
            id="svc_slug"
            value={draft.slug}
            onChange={(e) => setDraft({ ...draft, slug: e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, '') })}
            placeholder="game-demo-prototype"
          />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_title">Title</label>
          <input id="svc_title" value={draft.title} onChange={(e) => setDraft({ ...draft, title: e.target.value })} />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_tagline">Tagline (card subtitle)</label>
          <input
            id="svc_tagline"
            value={draft.tagline}
            onChange={(e) => setDraft({ ...draft, tagline: e.target.value })}
          />
        </div>
        <div className="admin-field" style={{ gridColumn: '1 / -1' }}>
          <label htmlFor="svc_desc">Description (full pitch)</label>
          <textarea
            id="svc_desc"
            rows={4}
            value={draft.description}
            onChange={(e) => setDraft({ ...draft, description: e.target.value })}
          />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_cat">Category</label>
          <select
            id="svc_cat"
            value={draft.category}
            onChange={(e) => setDraft({ ...draft, category: e.target.value })}
          >
            {SERVICE_CATEGORY_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>
        <div className="admin-field">
          <label htmlFor="svc_kind">Kind</label>
          <select id="svc_kind" value={draft.kind} onChange={(e) => setDraft({ ...draft, kind: e.target.value })}>
            {SERVICE_KIND_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>
        <div className="admin-field">
          <label htmlFor="svc_emoji">Icon emoji</label>
          <input
            id="svc_emoji"
            value={draft.icon_emoji}
            onChange={(e) => setDraft({ ...draft, icon_emoji: e.target.value })}
          />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_image">Image URL (optional)</label>
          <input
            id="svc_image"
            value={draft.image_url}
            onChange={(e) => setDraft({ ...draft, image_url: e.target.value })}
            placeholder="https://…"
          />
        </div>
        <div className="admin-field" style={{ gridColumn: '1 / -1' }}>
          <label htmlFor="svc_features">Bullet features (one per line)</label>
          <textarea
            id="svc_features"
            rows={4}
            value={featuresText}
            onChange={(e) =>
              setDraft({
                ...draft,
                features: e.target.value
                  .split('\n')
                  .map((l) => l.trim())
                  .filter(Boolean),
              })
            }
          />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_deliver">Deliverables</label>
          <input
            id="svc_deliver"
            value={draft.deliverables}
            onChange={(e) => setDraft({ ...draft, deliverables: e.target.value })}
          />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_turn">Turnaround</label>
          <input
            id="svc_turn"
            value={draft.turnaround}
            onChange={(e) => setDraft({ ...draft, turnaround: e.target.value })}
          />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_pricing">Pricing model</label>
          <select
            id="svc_pricing"
            value={draft.pricing_model}
            onChange={(e) =>
              setDraft({ ...draft, pricing_model: e.target.value as ServicePricingModel })
            }
          >
            {SERVICE_PRICING_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>
        <div className="admin-field">
          <label htmlFor="svc_cta">Button label</label>
          <input id="svc_cta" value={draft.cta_label} onChange={(e) => setDraft({ ...draft, cta_label: e.target.value })} />
        </div>
        {(draft.pricing_model === 'fixed' || draft.pricing_model === 'pwyw' || draft.pricing_model === 'donation') && (
          <>
            <div className="admin-field">
              <label htmlFor="svc_price">Fixed price (USD)</label>
              <input
                id="svc_price"
                type="number"
                min={0}
                step={0.01}
                value={Number(draft.price_cents ?? 0) / 100}
                onChange={(e) =>
                  setDraft({ ...draft, price_cents: Math.round(Number(e.target.value || 0) * 100) })
                }
              />
            </div>
            <div className="admin-field">
              <label htmlFor="svc_stripe_price">Stripe Price ID (optional)</label>
              <input
                id="svc_stripe_price"
                value={draft.stripe_price_id ?? ''}
                onChange={(e) => setDraft({ ...draft, stripe_price_id: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="svc_pwyw_min">PWYW / donation min (USD)</label>
              <input
                id="svc_pwyw_min"
                type="number"
                min={0}
                step={0.01}
                value={Number(draft.pwyw_min_cents ?? 50) / 100}
                onChange={(e) =>
                  setDraft({ ...draft, pwyw_min_cents: Math.round(Number(e.target.value || 0) * 100) })
                }
              />
            </div>
            {draft.pricing_model === 'donation' ? (
              <div className="admin-field">
                <label htmlFor="svc_presets">Donation presets (USD, comma-separated)</label>
                <input
                  id="svc_presets"
                  value={(draft.donation_presets_cents ?? []).map((c) => (c / 100).toFixed(0)).join(', ')}
                  onChange={(e) => {
                    const cents = e.target.value
                      .split(/[,\s]+/)
                      .map((x) => Math.round(parseFloat(x) * 100))
                      .filter((n) => Number.isFinite(n) && n > 0);
                    setDraft({ ...draft, donation_presets_cents: donationPresetsFromUnknown(cents) });
                  }}
                />
              </div>
            ) : null}
          </>
        )}
        <div className="admin-field">
          <label htmlFor="svc_purchase">External checkout URL</label>
          <input
            id="svc_purchase"
            value={draft.purchase_url ?? ''}
            onChange={(e) => setDraft({ ...draft, purchase_url: e.target.value })}
            placeholder="https://buy.stripe.com/…"
          />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_gumroad">Gumroad URL</label>
          <input
            id="svc_gumroad"
            value={draft.gumroad_url ?? ''}
            onChange={(e) => setDraft({ ...draft, gumroad_url: e.target.value })}
          />
        </div>
        <div className="admin-field">
          <label htmlFor="svc_sort">Sort order</label>
          <input
            id="svc_sort"
            type="number"
            value={draft.sort_order}
            onChange={(e) => setDraft({ ...draft, sort_order: Number(e.target.value) || 0 })}
          />
        </div>
        <label className="admin-row" style={{ gap: 8 }}>
          <input
            type="checkbox"
            checked={draft.request_only}
            onChange={(e) => setDraft({ ...draft, request_only: e.target.checked })}
          />
          Quote / request only (hide Stripe checkout)
        </label>
        <label className="admin-row" style={{ gap: 8 }}>
          <input
            type="checkbox"
            checked={draft.request_form_enabled}
            onChange={(e) => setDraft({ ...draft, request_form_enabled: e.target.checked })}
          />
          Show email request form
        </label>
        <label className="admin-row" style={{ gap: 8 }}>
          <input
            type="checkbox"
            checked={draft.published}
            onChange={(e) => setDraft({ ...draft, published: e.target.checked })}
          />
          Published
        </label>
        <label className="admin-row" style={{ gap: 8 }}>
          <input
            type="checkbox"
            checked={draft.show_on_services_hub}
            onChange={(e) => setDraft({ ...draft, show_on_services_hub: e.target.checked })}
          />
          Show on /services page
        </label>
        <div className="admin-row" style={{ gridColumn: '1 / -1', gap: 10, flexWrap: 'wrap' }}>
          <button
            type="button"
            disabled={busy || !draft.slug.trim() || !draft.title.trim()}
            onClick={() => {
              setBusy(true);
              setMsg(null);
              void upsertService(draft)
                .then(() => {
                  setMsg(`Saved “${draft.title}”.`);
                  return reload();
                })
                .catch((e) => setMsg(e instanceof Error ? e.message : 'Save failed'))
                .finally(() => setBusy(false));
            }}
          >
            {busy ? 'Saving…' : 'Save service'}
          </button>
          <button type="button" onClick={() => setDraft(emptyService())}>
            New blank
          </button>
        </div>
        {msg ? <p className="admin-muted" style={{ gridColumn: '1 / -1' }}>{msg}</p> : null}
      </div>

      <div className="admin-panel">
        <h3 style={{ margin: '0 0 12px', fontSize: '0.9rem' }}>Saved offerings ({list.length})</h3>
        <ul style={{ margin: 0, padding: 0, listStyle: 'none' }}>
          {list.map((s) => (
            <li
              key={s.slug}
              style={{
                display: 'flex',
                flexWrap: 'wrap',
                gap: 8,
                alignItems: 'center',
                marginBottom: 10,
                paddingBottom: 10,
                borderBottom: '1px solid rgba(115,248,255,0.15)',
              }}
            >
              <span>
                {s.icon_emoji} <strong>{s.title}</strong>{' '}
                <code style={{ fontSize: '0.78rem' }}>{s.slug}</code> · {String(s.pricing_model)}
              </span>
              <button type="button" onClick={() => setDraft({ ...s })}>
                Edit
              </button>
              <button
                type="button"
                onClick={() => {
                  if (!window.confirm(`Delete service “${s.title}”?`)) return;
                  void deleteServiceSlug(s.slug).then(() => reload());
                }}
              >
                Delete
              </button>
            </li>
          ))}
        </ul>
      </div>

      <div className="admin-panel">
        <h3 style={{ margin: '0 0 12px', fontSize: '0.9rem' }}>Inbound requests ({requests.length})</h3>
        {requests.length === 0 ? (
          <p className="admin-muted">No requests yet.</p>
        ) : (
          <ul style={{ margin: 0, padding: 0, listStyle: 'none', maxHeight: 360, overflow: 'auto' }}>
            {requests.map((r) => (
              <li
                key={r.id}
                style={{
                  marginBottom: 10,
                  padding: '10px 12px',
                  borderRadius: 8,
                  border: '1px solid rgba(115,248,255,0.2)',
                  fontSize: '0.85rem',
                  lineHeight: 1.5,
                }}
              >
                <div className="admin-muted" style={{ fontSize: '0.78rem' }}>
                  {new Date(r.created_at).toLocaleString()} · {r.contact_email}
                  {r.service_title ? ` · ${r.service_title}` : ''}
                </div>
                <strong>{r.contact_name || 'Anonymous'}</strong>
                {r.budget_note ? <span> — {r.budget_note}</span> : null}
                <p style={{ margin: '6px 0 0', whiteSpace: 'pre-wrap' }}>{r.message}</p>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

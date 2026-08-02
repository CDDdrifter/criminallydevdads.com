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
import { newSectionId } from '../../../lib/pageSections';
import { ADMIN_AI_SERVICE_DRAFT_KEY } from '../../../lib/adminAi/types';
import type {
  ProductType,
  ServicePricingModel,
  ShippingConfig,
  ShippingRate,
  SiteService,
  SiteSettings,
  VariantGroup,
} from '../../../types';
import { defaultShippingConfig } from '../../../types';

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
    product_type: 'service',
    variant_groups: [],
    requires_shipping: false,
    allow_quantity: false,
    max_quantity: 1,
  };
}

const PRODUCT_TYPE_OPTIONS: { value: 'service' | 'digital' | 'physical'; label: string }[] = [
  { value: 'service', label: 'Service / gig (no fulfillment)' },
  { value: 'digital', label: 'Digital product (download / key)' },
  { value: 'physical', label: 'Physical product (ships)' },
];

type ServicesAdminTabProps = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

export function ServicesAdminTab({ settings, setSettings }: ServicesAdminTabProps) {
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
          <code>025_site_services_commerce.sql</code> once. Variants, physical products, and shipping require{' '}
          <code>029_products_variants_shipping.sql</code>.
        </p>
      </div>

      <ShippingSettingsPanel
        shipping={settings.shipping ?? defaultShippingConfig()}
        onChange={(shipping) => setSettings({ ...settings, shipping })}
      />

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
        {(draft.pricing_model === 'fixed' || draft.pricing_model === 'pwyw' || draft.pricing_model === 'tip') && (
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
              <label htmlFor="svc_pwyw_min">PWYW / tip minimum (USD)</label>
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
            {draft.pricing_model === 'pwyw' ? (
              <div className="admin-field">
                <label htmlFor="svc_pwyw_sug">Suggested amount (USD, hint only)</label>
                <input
                  id="svc_pwyw_sug"
                  type="number"
                  min={0}
                  step={0.01}
                  value={Number(draft.pwyw_suggested_cents ?? 0) / 100}
                  onChange={(e) =>
                    setDraft({ ...draft, pwyw_suggested_cents: Math.round(Number(e.target.value || 0) * 100) })
                  }
                />
              </div>
            ) : null}
            {draft.pricing_model === 'tip' ? (
              <div className="admin-field">
                <label htmlFor="svc_presets">Tip presets (USD, comma-separated)</label>
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

        {/* ===== Product type, fulfillment, quantity ===================== */}
        <div className="admin-field">
          <label htmlFor="svc_ptype">Product type</label>
          <select
            id="svc_ptype"
            value={draft.product_type}
            onChange={(e) => {
              const product_type = e.target.value as ProductType;
              setDraft({
                ...draft,
                product_type,
                // Auto-enable shipping for physical, off otherwise.
                requires_shipping: product_type === 'physical' ? true : false,
              });
            }}
          >
            {PRODUCT_TYPE_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>
        {draft.product_type === 'physical' ? (
          <label className="admin-row" style={{ gap: 8 }}>
            <input
              type="checkbox"
              checked={draft.requires_shipping}
              onChange={(e) => setDraft({ ...draft, requires_shipping: e.target.checked })}
            />
            Collect shipping address at checkout
          </label>
        ) : null}
        <label className="admin-row" style={{ gap: 8 }}>
          <input
            type="checkbox"
            checked={draft.allow_quantity}
            onChange={(e) => setDraft({ ...draft, allow_quantity: e.target.checked })}
          />
          Allow quantity selection
        </label>
        {draft.allow_quantity ? (
          <div className="admin-field">
            <label htmlFor="svc_maxqty">Max quantity</label>
            <input
              id="svc_maxqty"
              type="number"
              min={1}
              step={1}
              value={draft.max_quantity}
              onChange={(e) => setDraft({ ...draft, max_quantity: Math.max(1, Number(e.target.value) || 1) })}
            />
          </div>
        ) : null}

        {/* ===== Variant groups (any size / colour) ===================== */}
        <div className="admin-field" style={{ gridColumn: '1 / -1' }}>
          <label>Variants (sizes, colours, editions…)</label>
          <p className="admin-muted" style={{ fontSize: '0.8rem', margin: '0 0 8px' }}>
            Add an option axis (e.g. <strong>Size</strong>) with options (S, M, L, XL). Each option can adjust the
            base price. Shown as dropdowns on the storefront; the choice is sent to Stripe.
          </p>
          <VariantGroupsEditor
            groups={draft.variant_groups}
            onChange={(variant_groups) => setDraft({ ...draft, variant_groups })}
          />
        </div>

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

// ===========================================================================
// VariantGroupsEditor — edit option axes (Size, Colour) + per-option price.
// ===========================================================================

function VariantGroupsEditor({
  groups,
  onChange,
}: {
  groups: VariantGroup[];
  onChange: (groups: VariantGroup[]) => void;
}) {
  const addGroup = () =>
    onChange([...groups, { id: newSectionId(), name: 'Size', options: [] }]);
  const removeGroup = (gid: string) => onChange(groups.filter((g) => g.id !== gid));
  const patchGroup = (gid: string, patch: Partial<VariantGroup>) =>
    onChange(groups.map((g) => (g.id === gid ? { ...g, ...patch } : g)));
  const addOption = (gid: string) =>
    onChange(
      groups.map((g) =>
        g.id === gid
          ? { ...g, options: [...g.options, { id: newSectionId(), label: '', price_delta_cents: 0, sku: '' }] }
          : g,
      ),
    );

  return (
    <div className="admin-grid" style={{ gap: 10 }}>
      {groups.length === 0 ? (
        <p className="admin-muted" style={{ fontSize: '0.82rem' }}>
          No variants. This product sells as a single option.
        </p>
      ) : null}
      {groups.map((g) => (
        <div key={g.id} className="admin-panel" style={{ padding: 10, borderStyle: 'dashed' }}>
          <div className="admin-row" style={{ justifyContent: 'space-between', gap: 8, marginBottom: 8 }}>
            <input
              value={g.name}
              onChange={(e) => patchGroup(g.id, { name: e.target.value })}
              placeholder="Axis name (e.g. Size)"
              style={{ flex: 1 }}
            />
            <button type="button" onClick={() => removeGroup(g.id)}>
              Remove axis
            </button>
          </div>
          {g.options.map((o) => (
            <div key={o.id} className="admin-row" style={{ gap: 6, marginBottom: 6, flexWrap: 'wrap' }}>
              <input
                value={o.label}
                onChange={(e) =>
                  patchGroup(g.id, {
                    options: g.options.map((x) => (x.id === o.id ? { ...x, label: e.target.value } : x)),
                  })
                }
                placeholder="Option (e.g. L)"
                style={{ flex: '1 1 120px' }}
              />
              <label className="admin-muted" style={{ fontSize: '0.72rem', display: 'flex', alignItems: 'center', gap: 4 }}>
                +$
                <input
                  type="number"
                  step={0.01}
                  value={o.price_delta_cents / 100}
                  onChange={(e) =>
                    patchGroup(g.id, {
                      options: g.options.map((x) =>
                        x.id === o.id ? { ...x, price_delta_cents: Math.round(Number(e.target.value || 0) * 100) } : x,
                      ),
                    })
                  }
                  style={{ width: 80 }}
                  title="Price added when this option is chosen"
                />
              </label>
              <input
                value={o.sku ?? ''}
                onChange={(e) =>
                  patchGroup(g.id, {
                    options: g.options.map((x) => (x.id === o.id ? { ...x, sku: e.target.value } : x)),
                  })
                }
                placeholder="SKU (optional)"
                style={{ flex: '1 1 100px' }}
              />
              <button
                type="button"
                onClick={() =>
                  patchGroup(g.id, { options: g.options.filter((x) => x.id !== o.id) })
                }
              >
                ✕
              </button>
            </div>
          ))}
          <button type="button" onClick={() => addOption(g.id)}>
            + Add option
          </button>
        </div>
      ))}
      <button type="button" onClick={addGroup}>
        + Add variant axis
      </button>
    </div>
  );
}

// ===========================================================================
// ShippingSettingsPanel — site-wide flat-rate shipping for physical products.
// Writes into site_settings.shipping; the floating save bar persists it.
// ===========================================================================

function ShippingSettingsPanel({
  shipping,
  onChange,
}: {
  shipping: ShippingConfig;
  onChange: (next: ShippingConfig) => void;
}) {
  const patch = (p: Partial<ShippingConfig>) => onChange({ ...shipping, ...p });
  const addRate = () =>
    patch({
      rates: [
        ...shipping.rates,
        { id: newSectionId(), label: 'New rate', amount_cents: 0, delivery_estimate: '' },
      ],
    });
  const patchRate = (id: string, p: Partial<ShippingRate>) =>
    patch({ rates: shipping.rates.map((r) => (r.id === id ? { ...r, ...p } : r)) });

  return (
    <div className="admin-panel">
      <h3 style={{ margin: '0 0 8px', fontSize: '0.9rem', color: 'var(--accent)' }}>📦 Shipping (physical products)</h3>
      <p className="admin-muted" style={{ marginTop: 0, fontSize: '0.84rem', lineHeight: 1.5 }}>
        Applies to any product marked <strong>Physical</strong> with shipping enabled. Stripe collects the buyer's
        address and offers these flat rates. Save with the floating bar at the bottom.
      </p>
      <label className="admin-row" style={{ gap: 8, marginBottom: 10 }}>
        <input
          type="checkbox"
          checked={shipping.enabled}
          onChange={(e) => patch({ enabled: e.target.checked })}
        />
        Enable shipping address collection + rates at checkout
      </label>
      <div className="admin-field" style={{ marginBottom: 12 }}>
        <label htmlFor="ship_countries">Allowed countries (ISO codes, comma-separated)</label>
        <input
          id="ship_countries"
          value={shipping.allowed_countries.join(', ')}
          onChange={(e) =>
            patch({
              allowed_countries: e.target.value
                .split(/[,\s]+/)
                .map((c) => c.trim().toUpperCase())
                .filter((c) => /^[A-Z]{2}$/.test(c)),
            })
          }
          placeholder="US, CA, GB"
        />
      </div>
      <div style={{ display: 'grid', gap: 8 }}>
        {shipping.rates.map((r) => (
          <div key={r.id} className="admin-row" style={{ gap: 6, flexWrap: 'wrap', alignItems: 'flex-end' }}>
            <input
              value={r.label}
              onChange={(e) => patchRate(r.id, { label: e.target.value })}
              placeholder="Rate label"
              style={{ flex: '1 1 160px' }}
            />
            <label className="admin-muted" style={{ fontSize: '0.72rem', display: 'flex', alignItems: 'center', gap: 4 }}>
              $
              <input
                type="number"
                min={0}
                step={0.01}
                value={r.amount_cents / 100}
                onChange={(e) => patchRate(r.id, { amount_cents: Math.max(0, Math.round(Number(e.target.value || 0) * 100)) })}
                style={{ width: 90 }}
              />
            </label>
            <input
              value={r.delivery_estimate ?? ''}
              onChange={(e) => patchRate(r.id, { delivery_estimate: e.target.value })}
              placeholder="3-7 business days"
              style={{ flex: '1 1 140px' }}
            />
            <button type="button" onClick={() => patch({ rates: shipping.rates.filter((x) => x.id !== r.id) })}>
              ✕
            </button>
          </div>
        ))}
      </div>
      <button type="button" style={{ marginTop: 10 }} onClick={addRate}>
        + Add shipping rate
      </button>
    </div>
  );
}

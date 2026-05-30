import { useEffect, useMemo, useState } from 'react';
import type { ServiceView } from '../types';
import {
  defaultVariantSelection,
  effectiveUnitPriceCents,
  formatServicePriceLabel,
  serviceExternalStoreUrl,
  serviceOffersInternalCheckout,
  stripeMinimumUsdCents,
  variantSelectionLabel,
  type VariantSelection,
} from '../lib/servicePricing';
import { startServiceCheckout } from '../lib/stripeCheckout';

type Props = { service: ServiceView; compact?: boolean };

const money = (cents: number) => `$${(cents / 100).toFixed(2)}`;

export function ServicePurchaseBlock({ service, compact }: Props) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [amountDollars, setAmountDollars] = useState('5.00');
  const [selection, setSelection] = useState<VariantSelection>(() =>
    defaultVariantSelection(service.variant_groups),
  );
  const [qty, setQty] = useState(1);

  const externalUrl = serviceExternalStoreUrl(service);
  const priceText = formatServicePriceLabel(service);
  const hasVariants = service.variant_groups.length > 0;
  const maxQty = service.allow_quantity ? Math.max(1, service.max_quantity) : 1;

  useEffect(() => {
    setSelection(defaultVariantSelection(service.variant_groups));
    setQty(1);
  }, [service]);

  useEffect(() => {
    const min = Math.max(service.pwyw_min_cents, stripeMinimumUsdCents());
    let cents = min;
    if (service.pricing_model === 'pwyw') {
      const sug = service.pwyw_suggested_cents;
      if (sug >= min) cents = sug;
    } else if (service.pricing_model === 'donation') {
      const first = service.donation_presets_cents.find((p) => p >= min);
      if (first != null) cents = first;
    }
    setAmountDollars((cents / 100).toFixed(2));
  }, [service]);

  const unitPrice = useMemo(
    () => effectiveUnitPriceCents(service, selection),
    [service, selection],
  );
  const totalPrice = unitPrice * qty;

  if (externalUrl) {
    return (
      <a className="btn-play" href={externalUrl} target="_blank" rel="noreferrer">
        {service.cta_label || `Buy (${priceText})`}
      </a>
    );
  }

  if (!serviceOffersInternalCheckout(service)) {
    return null;
  }

  const minPay = Math.max(service.pwyw_min_cents, stripeMinimumUsdCents());

  const variantControls = hasVariants ? (
    <div className="service-buy__variants" style={{ display: 'grid', gap: 8, marginBottom: 10 }}>
      {service.variant_groups.map((g) => (
        <label key={g.id} className="admin-field" style={{ gap: 4 }}>
          <span className="admin-muted" style={{ fontSize: '0.8rem' }}>{g.name}</span>
          <select
            value={selection[g.id] ?? ''}
            onChange={(e) => setSelection((s) => ({ ...s, [g.id]: e.target.value }))}
          >
            {g.options.map((o) => (
              <option key={o.id} value={o.id}>
                {o.label}
                {o.price_delta_cents ? ` (${o.price_delta_cents > 0 ? '+' : ''}${money(o.price_delta_cents)})` : ''}
              </option>
            ))}
          </select>
        </label>
      ))}
    </div>
  ) : null;

  const qtyControl = service.allow_quantity ? (
    <label className="admin-field" style={{ gap: 4, marginBottom: 10, maxWidth: 140 }}>
      <span className="admin-muted" style={{ fontSize: '0.8rem' }}>Quantity (max {maxQty})</span>
      <input
        type="number"
        min={1}
        max={maxQty}
        step={1}
        value={qty}
        onChange={(e) => setQty(Math.min(maxQty, Math.max(1, Math.round(Number(e.target.value) || 1))))}
      />
    </label>
  ) : null;

  async function submitFixed() {
    setBusy(true);
    setErr(null);
    try {
      await startServiceCheckout({
        slug: service.slug,
        quantity: service.allow_quantity ? qty : undefined,
        variantSelection: hasVariants ? selection : undefined,
      });
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Checkout failed');
    } finally {
      setBusy(false);
    }
  }

  async function submitVariable(amountCents: number) {
    setBusy(true);
    setErr(null);
    try {
      await startServiceCheckout({ slug: service.slug, amountCents });
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Checkout failed');
    } finally {
      setBusy(false);
    }
  }

  if (service.pricing_model === 'fixed') {
    const buyLabel = `${service.cta_label} — ${money(totalPrice)}`;
    return (
      <div className={compact ? 'service-buy service-buy--compact' : 'service-buy'}>
        {variantControls}
        {qtyControl}
        <button type="button" className="btn-play" disabled={busy} onClick={() => void submitFixed()}>
          {busy ? 'Opening Stripe…' : buyLabel}
        </button>
        {(hasVariants || qty > 1) && (
          <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 6 }}>
            {variantSelectionLabel(service.variant_groups, selection)}
            {qty > 1 ? `${hasVariants ? ' · ' : ''}${money(unitPrice)} each` : ''}
          </p>
        )}
        {err ? <p className="admin-muted" style={{ color: 'var(--danger)', marginTop: 8 }}>{err}</p> : null}
      </div>
    );
  }

  return (
    <div className={compact ? 'service-buy service-buy--compact' : 'service-buy'}>
      {service.donation_presets_cents.length > 0 ? (
        <div className="service-buy__presets">
          {service.donation_presets_cents.map((c) => (
            <button
              key={c}
              type="button"
              disabled={busy}
              onClick={() => {
                setAmountDollars((c / 100).toFixed(2));
                void submitVariable(c);
              }}
            >
              ${(c / 100).toFixed(0)}
            </button>
          ))}
        </div>
      ) : null}
      <label className="admin-field" style={{ marginTop: 8 }}>
        <span className="admin-muted" style={{ fontSize: '0.8rem' }}>
          Amount (USD, min {money(minPay)})
        </span>
        <input
          type="number"
          min={minPay / 100}
          step="0.01"
          value={amountDollars}
          onChange={(e) => setAmountDollars(e.target.value)}
        />
      </label>
      <button
        type="button"
        className="btn-play"
        style={{ marginTop: 8 }}
        disabled={busy}
        onClick={() => void submitVariable(Math.round(parseFloat(amountDollars) * 100))}
      >
        {busy ? 'Opening Stripe…' : service.cta_label}
      </button>
      {err ? <p className="admin-muted" style={{ color: 'var(--danger)', marginTop: 8 }}>{err}</p> : null}
    </div>
  );
}

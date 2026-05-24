import { useEffect, useState } from 'react';
import type { ServiceView } from '../types';
import {
  formatServicePriceLabel,
  serviceExternalStoreUrl,
  serviceOffersInternalCheckout,
  stripeMinimumUsdCents,
} from '../lib/servicePricing';
import { startServiceCheckout } from '../lib/stripeCheckout';

type Props = { service: ServiceView; compact?: boolean };

export function ServicePurchaseBlock({ service, compact }: Props) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [amountDollars, setAmountDollars] = useState('5.00');

  const externalUrl = serviceExternalStoreUrl(service);
  const priceText = formatServicePriceLabel(service);

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

  async function submitFixed() {
    setBusy(true);
    setErr(null);
    try {
      await startServiceCheckout({ slug: service.slug });
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Checkout failed');
    } finally {
      setBusy(false);
    }
  }

  async function submitVariable() {
    setBusy(true);
    setErr(null);
    try {
      const cents = Math.round(parseFloat(amountDollars) * 100);
      await startServiceCheckout({ slug: service.slug, amountCents: cents });
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Checkout failed');
    } finally {
      setBusy(false);
    }
  }

  if (service.pricing_model === 'fixed') {
    return (
      <div className={compact ? 'service-buy service-buy--compact' : 'service-buy'}>
        <button type="button" className="btn-play" disabled={busy} onClick={() => void submitFixed()}>
          {busy ? 'Opening Stripe…' : `${service.cta_label} (${priceText})`}
        </button>
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
                void (async () => {
                  setBusy(true);
                  setErr(null);
                  try {
                    await startServiceCheckout({ slug: service.slug, amountCents: c });
                  } catch (e) {
                    setErr(e instanceof Error ? e.message : 'Checkout failed');
                  } finally {
                    setBusy(false);
                  }
                })();
              }}
            >
              ${(c / 100).toFixed(0)}
            </button>
          ))}
        </div>
      ) : null}
      <label className="admin-field" style={{ marginTop: 8 }}>
        <span className="admin-muted" style={{ fontSize: '0.8rem' }}>
          Amount (USD, min ${(minPay / 100).toFixed(2)})
        </span>
        <input
          type="number"
          min={minPay / 100}
          step="0.01"
          value={amountDollars}
          onChange={(e) => setAmountDollars(e.target.value)}
        />
      </label>
      <button type="button" className="btn-play" style={{ marginTop: 8 }} disabled={busy} onClick={() => void submitVariable()}>
        {busy ? 'Opening Stripe…' : service.cta_label}
      </button>
      {err ? <p className="admin-muted" style={{ color: 'var(--danger)', marginTop: 8 }}>{err}</p> : null}
    </div>
  );
}

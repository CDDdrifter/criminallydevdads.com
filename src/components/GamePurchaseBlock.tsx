import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import type { GameView } from '../types';
import { formatGamePriceLabel, gameOffersInternalCheckout, stripeMinimumUsdCents } from '../lib/gamePricing';
import { startGameCheckout } from '../lib/stripeCheckout';

type Props = { game: GameView };

export function GamePurchaseBlock({ game }: Props) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [amountDollars, setAmountDollars] = useState('5.00');

  const externalUrl = game.purchase_url.trim();
  const priceText = formatGamePriceLabel(game);
  const asset = game.type.toLowerCase() === 'asset';

  useEffect(() => {
    const min = Math.max(game.pwyw_min_cents, stripeMinimumUsdCents());
    let cents = min;
    if (game.pricing_model === 'pwyw') {
      const sug = game.pwyw_suggested_cents;
      if (sug >= min) {
        cents = sug;
      }
    } else if (game.pricing_model === 'donation') {
      const firstPreset = game.donation_presets_cents.find((p) => p >= min);
      if (firstPreset != null) {
        cents = firstPreset;
      }
    }
    setAmountDollars((cents / 100).toFixed(2));
  }, [
    game.slug,
    game.pricing_model,
    game.pwyw_min_cents,
    game.pwyw_suggested_cents,
    game.donation_presets_cents,
  ]);

  if (externalUrl) {
    return (
      <a className="btn-play" href={externalUrl} target="_blank" rel="noreferrer">
        {asset ? `Buy asset (${priceText})` : `Buy (${priceText})`}
      </a>
    );
  }

  if (!gameOffersInternalCheckout(game)) {
    return null;
  }

  const minPay = Math.max(game.pwyw_min_cents, stripeMinimumUsdCents());

  async function submitFixed() {
    setBusy(true);
    setErr(null);
    try {
      await startGameCheckout({ slug: game.slug });
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Checkout failed');
    } finally {
      setBusy(false);
    }
  }

  async function submitVariable() {
    const dollars = Number(amountDollars);
    const cents = Math.round(dollars * 100);
    if (!Number.isFinite(cents)) {
      setErr('Enter a valid amount.');
      return;
    }
    setBusy(true);
    setErr(null);
    try {
      await startGameCheckout({ slug: game.slug, amountCents: cents });
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Checkout failed');
    } finally {
      setBusy(false);
    }
  }

  const terms = (
    <p className="admin-muted" style={{ margin: 0, fontSize: '0.82rem' }}>
      Secure checkout via Stripe.{' '}
      <Link to="/purchase/terms">Digital purchase terms</Link>
    </p>
  );

  if (game.pricing_model === 'fixed') {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'flex-start' }}>
        <button type="button" className="btn-play" disabled={busy} onClick={() => void submitFixed()}>
          {busy ? 'Redirecting…' : asset ? `Buy asset (${priceText})` : `Buy (${priceText})`}
        </button>
        {err ? (
          <p className="admin-muted" style={{ margin: 0, color: 'var(--accent)' }}>
            {err}
          </p>
        ) : null}
        {terms}
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'flex-start', maxWidth: 420 }}>
      <label className="admin-muted" style={{ display: 'flex', flexDirection: 'column', gap: 4, width: '100%' }}>
        <span>{game.pricing_model === 'donation' ? 'Amount (USD)' : 'Your price (USD)'}</span>
        <input
          type="number"
          min={minPay / 100}
          step={0.01}
          value={amountDollars}
          onChange={(e) => setAmountDollars(e.target.value)}
          disabled={busy}
          style={{ padding: '8px 10px', borderRadius: 6, width: '100%', maxWidth: 280 }}
        />
      </label>
      {game.pricing_model === 'donation' && game.donation_presets_cents.length > 0 ? (
        <div className="admin-row" style={{ flexWrap: 'wrap', gap: 8 }}>
          {game.donation_presets_cents.map((c) => (
            <button
              key={c}
              type="button"
              className="btn-download"
              style={{ padding: '6px 12px' }}
              disabled={busy}
              onClick={() => setAmountDollars((c / 100).toFixed(2))}
            >
              ${(c / 100).toFixed(0)}
            </button>
          ))}
        </div>
      ) : null}
      <button type="button" className="btn-play" disabled={busy} onClick={() => void submitVariable()}>
        {busy
          ? 'Redirecting…'
          : game.pricing_model === 'donation'
            ? `Support — ${priceText}`
            : 'Continue to checkout'}
      </button>
      {err ? (
        <p className="admin-muted" style={{ margin: 0, color: 'var(--accent)' }}>
          {err}
        </p>
      ) : null}
      {terms}
    </div>
  );
}

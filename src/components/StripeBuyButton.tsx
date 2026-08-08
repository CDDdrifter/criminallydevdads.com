import { useEffect, useRef } from 'react';

const STRIPE_BUY_BUTTON_SCRIPT = 'https://js.stripe.com/v3/buy-button.js';
const SCRIPT_ID = 'cdd-stripe-buy-button-script';

declare global {
  namespace JSX {
    interface IntrinsicElements {
      'stripe-buy-button': React.DetailedHTMLProps<
        React.HTMLAttributes<HTMLElement> & {
          'buy-button-id'?: string;
          'publishable-key'?: string;
        },
        HTMLElement
      >;
    }
  }
}

type Props = {
  buyButtonId: string;
  publishableKey: string;
  className?: string;
};

function ensureStripeBuyButtonScript(): Promise<void> {
  return new Promise((resolve, reject) => {
    const existing = document.getElementById(SCRIPT_ID) as HTMLScriptElement | null;
    if (existing) {
      if (existing.dataset.loaded === 'true') {
        resolve();
        return;
      }
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener('error', () => reject(new Error('Stripe buy button script failed to load')), {
        once: true,
      });
      return;
    }

    const script = document.createElement('script');
    script.id = SCRIPT_ID;
    script.async = true;
    script.src = STRIPE_BUY_BUTTON_SCRIPT;
    script.addEventListener(
      'load',
      () => {
        script.dataset.loaded = 'true';
        resolve();
      },
      { once: true },
    );
    script.addEventListener('error', () => reject(new Error('Stripe buy button script failed to load')), {
      once: true,
    });
    document.head.appendChild(script);
  });
}

/** Embeds a Stripe Payment Link buy button (Buy Me a Coffee / tips). */
export function StripeBuyButton({ buyButtonId, publishableKey, className }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const buttonId = buyButtonId.trim();
  const key = publishableKey.trim();

  useEffect(() => {
    if (!buttonId || !key || !containerRef.current) {
      return;
    }

    let cancelled = false;
    const mount = containerRef.current;

    void ensureStripeBuyButtonScript()
      .then(() => {
        if (cancelled || !mount) {
          return;
        }
        mount.innerHTML = '';
        const el = document.createElement('stripe-buy-button');
        el.setAttribute('buy-button-id', buttonId);
        el.setAttribute('publishable-key', key);
        mount.appendChild(el);
      })
      .catch(() => {
        /* Ad blockers or network issues */
      });

    return () => {
      cancelled = true;
      if (mount) {
        mount.innerHTML = '';
      }
    };
  }, [buttonId, key]);

  if (!buttonId || !key) {
    return null;
  }

  return <div ref={containerRef} className={className ?? 'stripe-buy-button-wrap'} aria-label="Buy me a coffee" />;
}

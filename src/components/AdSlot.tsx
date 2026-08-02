/**
 * Optional ad placement — enable in Admin → Behavior with a Google AdSense client ID,
 * or paste ad network scripts in SEO → Custom head HTML.
 */
import { useEffect, useRef } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';

declare global {
  interface Window {
    adsbygoogle?: unknown[];
  }
}

export function AdSlot({ placement = 'hub-footer' }: { placement?: string }) {
  const { settings } = useSiteSettings();
  const b = settings.behavior;
  const clientId = b?.adsense_client_id?.trim() ?? '';
  const slotRef = useRef<HTMLModElement>(null);

  useEffect(() => {
    if (!b?.ads_enabled || !clientId || !slotRef.current) {
      return;
    }
    try {
      (window.adsbygoogle = window.adsbygoogle || []).push({});
    } catch {
      /* Ad blockers or script not loaded yet */
    }
  }, [b?.ads_enabled, clientId, placement]);

  if (!b?.ads_enabled) {
    return null;
  }

  if (!clientId) {
    return (
      <aside
        className="ad-slot ad-slot--placeholder"
        aria-label="Advertisement"
        style={{
          margin: '24px auto',
          maxWidth: 728,
          minHeight: 90,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          border: '1px dashed var(--border)',
          borderRadius: 10,
          color: 'var(--muted)',
          fontSize: '0.78rem',
        }}
      >
        Ad slot — add your AdSense client ID in Admin → Behavior
      </aside>
    );
  }

  return (
    <aside className="ad-slot" aria-label="Advertisement" style={{ margin: '24px auto', maxWidth: 728, textAlign: 'center' }}>
      <ins
        ref={slotRef}
        className="adsbygoogle"
        style={{ display: 'block' }}
        data-ad-client={clientId}
        data-ad-slot=""
        data-ad-format="auto"
        data-full-width-responsive="true"
      />
    </aside>
  );
}

/** Loads AdSense script once when ads are enabled. */
export function AdSenseScriptLoader() {
  const { settings } = useSiteSettings();
  const clientId = settings.behavior?.adsense_client_id?.trim() ?? '';
  const enabled = settings.behavior?.ads_enabled === true;

  useEffect(() => {
    if (!enabled || !clientId) {
      return;
    }
    const id = 'cdd-adsense-script';
    if (document.getElementById(id)) {
      return;
    }
    const script = document.createElement('script');
    script.id = id;
    script.async = true;
    script.src = `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${encodeURIComponent(clientId)}`;
    script.crossOrigin = 'anonymous';
    document.head.appendChild(script);
  }, [enabled, clientId]);

  return null;
}

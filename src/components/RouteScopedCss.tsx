import { useEffect } from 'react';

/**
 * Injects route-specific CSS (trusted admin content). Removed on unmount or when `css` clears.
 */
export function RouteScopedCss({ id, css }: { id: string; css: string }) {
  useEffect(() => {
    const trimmed = css.trim();
    const elId = `route-scoped-css-${id}`;
    if (!trimmed) {
      const existing = document.getElementById(elId);
      existing?.remove();
      return;
    }
    let el = document.getElementById(elId) as HTMLStyleElement | null;
    if (!el) {
      el = document.createElement('style');
      el.id = elId;
      document.head.appendChild(el);
    }
    el.textContent = trimmed;
    return () => {
      el?.remove();
    };
  }, [id, css]);

  return null;
}

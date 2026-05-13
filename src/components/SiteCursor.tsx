/**
 * SiteCursor — custom cursor + trail + click ripple.
 *
 * Renders a single absolutely-positioned `<div>` (or emoji span / `<img>`)
 * that follows the mouse. The trail is implemented as a small ring buffer of
 * decaying dots. We only enable when:
 *  - studio cursor is on, AND
 *  - the device is non-touch (touch devices have no cursor to replace).
 *
 * Because pointer events on every frame would be heavy, we use `pointermove`
 * (already throttled by the browser to one event per animation frame on
 * modern engines) and `transform: translate3d(...)` to keep paints cheap.
 */
import { useEffect, useRef } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';

function isTouchOnly() {
  if (typeof window === 'undefined') return false;
  return window.matchMedia('(hover: none)').matches;
}

export function SiteCursor() {
  const { settings } = useSiteSettings();
  const c = settings.cursor;

  const cursorRef = useRef<HTMLDivElement | null>(null);
  const trailRef = useRef<HTMLDivElement[]>([]);
  const trailIdxRef = useRef(0);

  useEffect(() => {
    if (!c.enabled || c.style === 'default') return undefined;
    if (isTouchOnly()) return undefined;

    // Hide the OS cursor (optional).
    if (c.hide_os_cursor || c.style === 'none') {
      document.documentElement.style.cursor = 'none';
    }

    // Build the cursor element.
    const root = document.createElement('div');
    root.style.cssText = `position: fixed; left: 0; top: 0; pointer-events: none; z-index: 99999; transform: translate3d(-100px, -100px, 0); will-change: transform; font-size: ${c.size_px}px; line-height: 1; display: ${c.style === 'none' ? 'none' : 'block'};`;

    if (c.style === 'emoji') {
      root.textContent = c.emoji || '👑';
      // Anchor to the centre rather than the top-left so the cursor "sits on" the hotspot.
      root.style.transformOrigin = 'center';
    } else if (c.style === 'image' && c.image_url) {
      const img = document.createElement('img');
      img.src = c.image_url;
      img.style.cssText = `width: ${c.size_px}px; height: ${c.size_px}px; display: block;`;
      root.appendChild(img);
    } else if (c.style === 'reticle') {
      root.innerHTML = `<svg width="${c.size_px}" height="${c.size_px}" viewBox="0 0 32 32"><circle cx="16" cy="16" r="12" fill="none" stroke="currentColor" stroke-width="2"/><line x1="16" y1="0" x2="16" y2="6" stroke="currentColor" stroke-width="2"/><line x1="16" y1="26" x2="16" y2="32" stroke="currentColor" stroke-width="2"/><line x1="0" y1="16" x2="6" y2="16" stroke="currentColor" stroke-width="2"/><line x1="26" y1="16" x2="32" y2="16" stroke="currentColor" stroke-width="2"/></svg>`;
      root.style.color = 'var(--accent)';
    } else if (c.style === 'crosshair') {
      root.innerHTML = `<svg width="${c.size_px}" height="${c.size_px}" viewBox="0 0 32 32"><line x1="0" y1="16" x2="32" y2="16" stroke="currentColor" stroke-width="2"/><line x1="16" y1="0" x2="16" y2="32" stroke="currentColor" stroke-width="2"/></svg>`;
      root.style.color = 'var(--accent)';
    } else if (c.style === 'pointer') {
      root.innerHTML = `<svg width="${c.size_px}" height="${c.size_px}" viewBox="0 0 16 16"><path fill="currentColor" stroke="black" stroke-width="1" d="M2 2 L2 14 L5 11 L7 15 L9 14 L7 10 L11 10 Z"/></svg>`;
      root.style.color = 'var(--accent)';
    }
    document.body.appendChild(root);
    cursorRef.current = root;

    // Trail dots — pre-create N elements we reuse cyclically.
    const trail: HTMLDivElement[] = [];
    if (c.trail.enabled) {
      for (let i = 0; i < c.trail.length; i++) {
        const dot = document.createElement('div');
        dot.style.cssText = `position: fixed; pointer-events: none; left: 0; top: 0; z-index: 99998; width: ${c.trail.size_px}px; height: ${c.trail.size_px}px; border-radius: 50%; background: ${c.trail.color}; transform: translate3d(-100px, -100px, 0); opacity: ${(1 - i / c.trail.length).toFixed(2)};`;
        document.body.appendChild(dot);
        trail.push(dot);
      }
    }
    trailRef.current = trail;
    trailIdxRef.current = 0;

    // Move handler.
    const onMove = (ev: PointerEvent) => {
      const x = ev.clientX - c.size_px / 2;
      const y = ev.clientY - c.size_px / 2;
      root.style.transform = `translate3d(${x}px, ${y}px, 0)`;
      if (trail.length === 0) return;
      const idx = trailIdxRef.current % trail.length;
      const dot = trail[idx];
      if (dot) {
        dot.style.transform = `translate3d(${ev.clientX - c.trail.size_px / 2}px, ${ev.clientY - c.trail.size_px / 2}px, 0)`;
      }
      trailIdxRef.current++;
    };

    // Click ripple — appended on each pointerdown then GC'd after the animation.
    const onDown = (ev: PointerEvent) => {
      if (!c.click_ripple.enabled) return;
      const r = document.createElement('div');
      r.style.cssText = `position: fixed; left: ${ev.clientX - c.click_ripple.size_px / 2}px; top: ${ev.clientY - c.click_ripple.size_px / 2}px; width: ${c.click_ripple.size_px}px; height: ${c.click_ripple.size_px}px; border-radius: 50%; pointer-events: none; z-index: 99997; background: ${c.click_ripple.color}; animation: studio-cursor-ripple 0.6s ease-out forwards;`;
      document.body.appendChild(r);
      window.setTimeout(() => r.remove(), 700);
    };

    // Ensure the ripple keyframe exists.
    if (!document.getElementById('studio-cursor-keyframes')) {
      const s = document.createElement('style');
      s.id = 'studio-cursor-keyframes';
      s.textContent = `@keyframes studio-cursor-ripple { to { transform: scale(2.2); opacity: 0; } }`;
      document.head.appendChild(s);
    }

    document.addEventListener('pointermove', onMove);
    document.addEventListener('pointerdown', onDown);
    return () => {
      document.removeEventListener('pointermove', onMove);
      document.removeEventListener('pointerdown', onDown);
      root.remove();
      trail.forEach((d) => d.remove());
      document.documentElement.style.cursor = '';
    };
  }, [
    c.enabled,
    c.style,
    c.emoji,
    c.image_url,
    c.size_px,
    c.hide_os_cursor,
    c.trail.enabled,
    c.trail.color,
    c.trail.length,
    c.trail.size_px,
    c.click_ripple.enabled,
    c.click_ripple.color,
    c.click_ripple.size_px,
  ]);

  return null;
}

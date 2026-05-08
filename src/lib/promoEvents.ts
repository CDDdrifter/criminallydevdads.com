import type { SiteEvent } from '../types';

function parseEventBoundary(s: string, kind: 'start' | 'end'): Date | null {
  const trimmed = s.trim();
  if (!trimmed) {
    return null;
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    const parts = trimmed.split('-').map(Number);
    const y = parts[0] ?? 0;
    const mo = parts[1] ?? 1;
    const d = parts[2] ?? 1;
    if (kind === 'start') {
      return new Date(y, mo - 1, d, 0, 0, 0, 0);
    }
    return new Date(y, mo - 1, d, 23, 59, 59, 999);
  }
  const t = Date.parse(trimmed);
  if (Number.isNaN(t)) {
    return null;
  }
  return new Date(t);
}

export function normalizePromoEvents(raw: unknown): SiteEvent[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out: SiteEvent[] = [];
  for (let i = 0; i < raw.length; i++) {
    const item = raw[i];
    if (!item || typeof item !== 'object') {
      continue;
    }
    const rec = item as Record<string, unknown>;
    const id = String(rec.id ?? '').trim() || `promo-${i + 1}`;
    const title = String(rec.title ?? '').trim();
    const body = rec.body != null ? String(rec.body) : '';
    const href = rec.href != null ? String(rec.href).trim() : '';
    const startsAt = rec.starts_at != null ? String(rec.starts_at).trim() : '';
    const endsAt = rec.ends_at != null ? String(rec.ends_at).trim() : '';
    out.push({
      id,
      title,
      body,
      href,
      external: Boolean(rec.external),
      starts_at: startsAt || null,
      ends_at: endsAt || null,
      active: rec.active !== false,
    });
  }
  return out;
}

export function isPromoActive(ev: SiteEvent, now = new Date()): boolean {
  if (!ev.active) {
    return false;
  }
  if (ev.starts_at) {
    const t = parseEventBoundary(ev.starts_at, 'start');
    if (t && now < t) {
      return false;
    }
  }
  if (ev.ends_at) {
    const t = parseEventBoundary(ev.ends_at, 'end');
    if (t && now > t) {
      return false;
    }
  }
  return true;
}

export function activePromoEvents(events: SiteEvent[], now = new Date()): SiteEvent[] {
  return events.filter((e) => isPromoActive(e, now));
}

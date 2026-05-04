import type { PageSection } from '../types';

function isRecord(v: unknown): v is Record<string, unknown> {
  return Boolean(v && typeof v === 'object' && !Array.isArray(v));
}

export function normalizePageSections(raw: unknown): PageSection[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out: PageSection[] = [];
  for (const item of raw) {
    if (!isRecord(item) || typeof item.id !== 'string' || typeof item.kind !== 'string') {
      continue;
    }
    const id = item.id;
    switch (item.kind) {
      case 'heading':
        if (typeof item.title === 'string') {
          out.push({
            id,
            kind: 'heading',
            title: item.title,
            subtitle: typeof item.subtitle === 'string' ? item.subtitle : undefined,
          });
        }
        break;
      case 'text':
        if (typeof item.body === 'string') {
          out.push({ id, kind: 'text', body: item.body });
        }
        break;
      case 'panel': {
        const variant =
          item.variant === 'accent' || item.variant === 'muted' ? item.variant : 'default';
        if (typeof item.title === 'string' && typeof item.body === 'string') {
          out.push({ id, kind: 'panel', title: item.title, body: item.body, variant });
        }
        break;
      }
      case 'image':
        if (typeof item.url === 'string' && item.url.length > 0) {
          out.push({
            id,
            kind: 'image',
            url: item.url,
            alt: typeof item.alt === 'string' ? item.alt : undefined,
            caption: typeof item.caption === 'string' ? item.caption : undefined,
          });
        }
        break;
      case 'video':
        if (typeof item.url === 'string') {
          out.push({
            id,
            kind: 'video',
            url: item.url,
            caption: typeof item.caption === 'string' ? item.caption : undefined,
          });
        }
        break;
      case 'divider':
        out.push({ id, kind: 'divider' });
        break;
      default:
        break;
    }
  }
  return out;
}

export function newSectionId(): string {
  return crypto.randomUUID();
}

export function createEmptySection(kind: PageSection['kind']): PageSection {
  const id = newSectionId();
  switch (kind) {
    case 'heading':
      return { id, kind: 'heading', title: 'New heading', subtitle: '' };
    case 'text':
      return { id, kind: 'text', body: 'Paragraph text…' };
    case 'panel':
      return { id, kind: 'panel', title: 'Panel title', body: 'Panel content…', variant: 'default' };
    case 'image':
      return { id, kind: 'image', url: '', alt: '', caption: '' };
    case 'video':
      return { id, kind: 'video', url: '', caption: '' };
    case 'divider':
      return { id, kind: 'divider' };
  }
}

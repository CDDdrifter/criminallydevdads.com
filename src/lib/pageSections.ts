/**
 * PageSections — parsing + factory helpers.
 *
 * The `PageSection` union (in `types.ts`) defines every block type the
 * CMS can render. This module's two jobs:
 *
 *   1. `normalizePageSections(raw)` — convert untrusted JSONB rows from
 *      Supabase into a strictly-typed `PageSection[]`. Anything that
 *      doesn't validate gets silently dropped so a single bad block can't
 *      crash a page.
 *
 *   2. `createEmptySection(kind)` — produce a fresh, mutable section with
 *      a stable UUID for the admin "Add block" buttons.
 *
 * Adding a new block type? Three places to touch:
 *   - `types.ts`            → the union
 *   - this file             → normalize + create
 *   - `PageSectionsView.tsx` → render
 *   - `PageSectionsForm.tsx` → edit
 */
import type { PageItem, PageSection } from '../types';

function isRecord(v: unknown): v is Record<string, unknown> {
  return Boolean(v && typeof v === 'object' && !Array.isArray(v));
}

function str(v: unknown, fallback = ''): string {
  return typeof v === 'string' ? v : fallback;
}

function strOpt(v: unknown): string | undefined {
  return typeof v === 'string' ? v : undefined;
}

function num(v: unknown): number | undefined {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  return undefined;
}

function bool(v: unknown, fallback = false): boolean {
  return typeof v === 'boolean' ? v : fallback;
}

export function newSectionId(): string {
  return crypto.randomUUID();
}

function normalizeId(v: unknown): string {
  return typeof v === 'string' && v ? v : newSectionId();
}

function asEnum<T extends string>(v: unknown, allowed: readonly T[], fallback: T): T {
  return typeof v === 'string' && (allowed as readonly string[]).includes(v) ? (v as T) : fallback;
}

function asColumns(v: unknown): 2 | 3 | 4 {
  return v === 2 || v === 3 || v === 4 ? v : 3;
}

/**
 * Items used by feature_list / stats / timeline / accordion / faq.
 * We accept partial entries (missing title/body is still listed empty) so
 * admins can sketch an empty list, save, and fill in later.
 */
function normalizeItems(raw: unknown): PageItem[] {
  if (!Array.isArray(raw)) return [];
  const out: PageItem[] = [];
  for (const item of raw) {
    if (!isRecord(item)) continue;
    const entry: PageItem = {
      id: normalizeId(item.id),
      title: str(item.title),
      body: str(item.body),
    };
    if (typeof item.icon === 'string') entry.icon = item.icon;
    if (typeof item.href === 'string') entry.href = item.href;
    if (typeof item.value === 'string') entry.value = item.value;
    if (item.status === 'done' || item.status === 'progress' || item.status === 'planned' || item.status === 'cancelled') {
      entry.status = item.status;
    }
    out.push(entry);
  }
  return out;
}

function normalizeCta(raw: unknown): { label: string; href: string; external?: boolean } | undefined {
  if (!isRecord(raw)) return undefined;
  const label = str(raw.label);
  const href = str(raw.href);
  if (!label && !href) return undefined;
  return { label, href, external: bool(raw.external) };
}

export function normalizePageSections(raw: unknown): PageSection[] {
  if (!Array.isArray(raw)) return [];
  const out: PageSection[] = [];
  for (const item of raw) {
    if (!isRecord(item) || typeof item.kind !== 'string') continue;
    const id = normalizeId(item.id);
    switch (item.kind) {
      // ===== Original 6 ====================================================
      case 'heading':
        out.push({
          id,
          kind: 'heading',
          title: str(item.title),
          subtitle: strOpt(item.subtitle),
          align: asEnum(item.align, ['left', 'center', 'right'] as const, 'left'),
        });
        break;
      case 'text':
        out.push({ id, kind: 'text', body: str(item.body) });
        break;
      case 'panel':
        out.push({
          id,
          kind: 'panel',
          title: str(item.title),
          body: str(item.body),
          variant: asEnum(item.variant, ['default', 'accent', 'muted'] as const, 'default'),
        });
        break;
      case 'image':
        out.push({
          id,
          kind: 'image',
          url: str(item.url),
          alt: strOpt(item.alt),
          caption: strOpt(item.caption),
        });
        break;
      case 'video':
        out.push({ id, kind: 'video', url: str(item.url), caption: strOpt(item.caption) });
        break;
      case 'divider':
        out.push({ id, kind: 'divider' });
        break;

      // ===== Expansion =====================================================
      case 'gallery':
        out.push({
          id,
          kind: 'gallery',
          images: Array.isArray(item.images)
            ? item.images
                .filter(isRecord)
                .map((g) => ({
                  id: normalizeId(g.id),
                  url: str(g.url),
                  alt: strOpt(g.alt),
                  caption: strOpt(g.caption),
                }))
                .filter((g) => g.url)
            : [],
          columns: asColumns(item.columns),
          lightbox: bool(item.lightbox, true),
        });
        break;
      case 'columns':
        out.push({
          id,
          kind: 'columns',
          columns: Array.isArray(item.columns)
            ? item.columns.filter(isRecord).map((c) => ({
                id: normalizeId(c.id),
                // Recursive call — columns can nest any block, even more columns
                sections: normalizePageSections(c.sections),
              }))
            : [],
          gap: asEnum(item.gap, ['sm', 'md', 'lg'] as const, 'md'),
        });
        break;
      case 'callout':
        out.push({
          id,
          kind: 'callout',
          title: str(item.title),
          body: str(item.body),
          tone: asEnum(
            item.tone,
            ['info', 'tip', 'success', 'warning', 'danger'] as const,
            'info',
          ),
          icon: strOpt(item.icon),
        });
        break;
      case 'quote':
        out.push({
          id,
          kind: 'quote',
          body: str(item.body),
          author: strOpt(item.author),
          role: strOpt(item.role),
          avatar_url: strOpt(item.avatar_url),
        });
        break;
      case 'code':
        out.push({
          id,
          kind: 'code',
          body: str(item.body),
          language: strOpt(item.language),
          filename: strOpt(item.filename),
        });
        break;
      case 'feature_list':
        out.push({
          id,
          kind: 'feature_list',
          items: normalizeItems(item.items),
          columns: asColumns(item.columns),
        });
        break;
      case 'stats':
        out.push({
          id,
          kind: 'stats',
          items: normalizeItems(item.items),
          columns: asColumns(item.columns),
        });
        break;
      case 'timeline':
        out.push({ id, kind: 'timeline', items: normalizeItems(item.items) });
        break;
      case 'accordion':
        out.push({
          id,
          kind: 'accordion',
          items: normalizeItems(item.items),
          default_open_id: strOpt(item.default_open_id),
        });
        break;
      case 'tabs':
        out.push({
          id,
          kind: 'tabs',
          tabs: Array.isArray(item.tabs)
            ? item.tabs.filter(isRecord).map((t) => ({
                id: normalizeId(t.id),
                label: str(t.label, 'Tab'),
                sections: normalizePageSections(t.sections),
              }))
            : [],
        });
        break;
      case 'cta':
        out.push({
          id,
          kind: 'cta',
          title: str(item.title),
          body: str(item.body),
          primary: normalizeCta(item.primary),
          secondary: normalizeCta(item.secondary),
          bg_image_url: strOpt(item.bg_image_url),
        });
        break;
      case 'embed':
        out.push({
          id,
          kind: 'embed',
          url: str(item.url),
          provider: asEnum(
            item.provider,
            ['youtube', 'twitch', 'vimeo', 'codepen', 'soundcloud', 'custom'] as const,
            'custom',
          ),
          aspect: asEnum(item.aspect, ['16/9', '4/3', '1/1', 'auto'] as const, '16/9'),
          caption: strOpt(item.caption),
        });
        break;
      case 'markdown':
        out.push({ id, kind: 'markdown', body: str(item.body) });
        break;
      case 'html':
        out.push({ id, kind: 'html', html: str(item.html) });
        break;
      case 'spacer':
        out.push({
          id,
          kind: 'spacer',
          size: asEnum(item.size, ['xs', 'sm', 'md', 'lg', 'xl'] as const, 'md'),
        });
        break;
      case 'hero':
        out.push({
          id,
          kind: 'hero',
          title: str(item.title),
          subtitle: strOpt(item.subtitle),
          bg_image_url: strOpt(item.bg_image_url),
          bg_video_url: strOpt(item.bg_video_url),
          height: asEnum(item.height, ['sm', 'md', 'lg', 'screen'] as const, 'md'),
          align: asEnum(item.align, ['left', 'center', 'right'] as const, 'center'),
          cta: normalizeCta(item.cta),
          overlay: num(item.overlay) ?? 0.4,
        });
        break;
      case 'download':
        out.push({
          id,
          kind: 'download',
          title: str(item.title),
          body: str(item.body),
          href: str(item.href),
          size: strOpt(item.size),
          format: strOpt(item.format),
          icon: strOpt(item.icon),
        });
        break;
      case 'buttons':
        out.push({
          id,
          kind: 'buttons',
          buttons: Array.isArray(item.buttons)
            ? item.buttons.filter(isRecord).map((b) => ({
                id: normalizeId(b.id),
                label: str(b.label, 'Button'),
                href: str(b.href),
                external: bool(b.external),
                variant: asEnum(b.variant, ['primary', 'secondary', 'ghost'] as const, 'primary'),
              }))
            : [],
          align: asEnum(item.align, ['left', 'center', 'right'] as const, 'left'),
        });
        break;
      case 'tip_button':
        out.push({
          id,
          kind: 'tip_button',
          label: strOpt(item.label),
          align: asEnum(item.align, ['left', 'center', 'right'] as const, 'center'),
          variant: asEnum(item.variant, ['primary', 'secondary'] as const, 'primary'),
        });
        break;
      case 'faq':
        out.push({
          id,
          kind: 'faq',
          items: normalizeItems(item.items),
          intro: strOpt(item.intro),
        });
        break;
      case 'iframe':
        out.push({
          id,
          kind: 'iframe',
          url: str(item.url),
          height_px: num(item.height_px) ?? 480,
          caption: strOpt(item.caption),
          allow: strOpt(item.allow),
        });
        break;
      case 'sandbox_html':
        out.push({
          id,
          kind: 'sandbox_html',
          html: str(item.html),
          iframe_compat: bool(item.iframe_compat),
          height_px: num(item.height_px) ?? 560,
          caption: strOpt(item.caption),
        });
        break;
      case 'image_text':
        out.push({
          id,
          kind: 'image_text',
          image_url: str(item.image_url),
          title: str(item.title),
          body: str(item.body),
          image_side: asEnum(item.image_side, ['left', 'right'] as const, 'left'),
          image_alt: strOpt(item.image_alt),
          cta: normalizeCta(item.cta),
        });
        break;
      case 'pricing':
        out.push({
          id,
          kind: 'pricing',
          columns: Array.isArray(item.columns)
            ? item.columns.filter(isRecord).map((c) => ({
                id: normalizeId(c.id),
                title: str(c.title, 'Plan'),
                price: str(c.price),
                period: strOpt(c.period),
                features: Array.isArray(c.features)
                  ? (c.features as unknown[]).map(String).filter(Boolean)
                  : [],
                cta: normalizeCta(c.cta),
                featured: bool(c.featured),
              }))
            : [],
        });
        break;
      case 'team':
        out.push({
          id,
          kind: 'team',
          members: Array.isArray(item.members)
            ? item.members.filter(isRecord).map((m) => ({
                id: normalizeId(m.id),
                name: str(m.name),
                role: str(m.role),
                avatar_url: strOpt(m.avatar_url),
                href: strOpt(m.href),
                bio: strOpt(m.bio),
              }))
            : [],
          columns: asColumns(item.columns),
        });
        break;
      case 'newsletter':
        out.push({
          id,
          kind: 'newsletter',
          title: str(item.title, 'Join the mailing list'),
          body: str(item.body),
          provider: asEnum(
            item.provider,
            ['mailchimp', 'buttondown', 'substack', 'convertkit', 'custom'] as const,
            'custom',
          ),
          action_url: str(item.action_url),
          button_label: strOpt(item.button_label),
        });
        break;
      case 'game_grid':
        out.push({
          id,
          kind: 'game_grid',
          title: strOpt(item.title),
          slugs: Array.isArray(item.slugs)
            ? (item.slugs as unknown[]).map(String).filter(Boolean)
            : [],
          columns: asColumns(item.columns),
        });
        break;
      case 'tags':
        out.push({
          id,
          kind: 'tags',
          items: Array.isArray(item.items)
            ? item.items.filter(isRecord).map((t) => ({
                id: normalizeId(t.id),
                label: str(t.label, 'tag'),
                href: strOpt(t.href),
                tone: asEnum(t.tone, ['default', 'accent', 'muted'] as const, 'default'),
              }))
            : [],
        });
        break;
      case 'comments': {
        const tt =
          item.target_type === 'game' || item.target_type === 'page' || item.target_type === 'devlog'
            ? item.target_type
            : undefined;
        out.push({
          id,
          kind: 'comments',
          title: strOpt(item.title),
          target_type: tt,
          target_key: strOpt(item.target_key),
        });
        break;
      }
      default:
        // Unknown kind — silently dropped so a future block type added on
        // another machine doesn't break older clients.
        break;
    }
  }
  return out;
}

/**
 * Returns a fresh, valid section with sensible placeholders. Each block
 * lists its own quick-start defaults so an admin can hit "Add" and see
 * something immediately rather than an empty box.
 */
export function createEmptySection(kind: PageSection['kind']): PageSection {
  const id = newSectionId();
  switch (kind) {
    case 'heading':
      return { id, kind: 'heading', title: 'New heading', subtitle: '', align: 'left' };
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
    case 'gallery':
      return { id, kind: 'gallery', images: [], columns: 3, lightbox: true };
    case 'columns':
      return {
        id,
        kind: 'columns',
        columns: [
          { id: newSectionId(), sections: [] },
          { id: newSectionId(), sections: [] },
        ],
        gap: 'md',
      };
    case 'callout':
      return { id, kind: 'callout', title: 'Heads up', body: 'Tell the reader something important.', tone: 'info', icon: '💡' };
    case 'quote':
      return { id, kind: 'quote', body: 'A short quote that hits hard.', author: 'Player', role: 'Beta tester' };
    case 'code':
      return { id, kind: 'code', body: 'console.log("hello world");', language: 'js' };
    case 'feature_list':
      return {
        id,
        kind: 'feature_list',
        items: [
          { id: newSectionId(), title: 'Fast', body: 'Loads in milliseconds.', icon: '⚡' },
          { id: newSectionId(), title: 'Polished', body: 'Pixel-perfect art.', icon: '🎨' },
          { id: newSectionId(), title: 'Multiplayer', body: 'Play with friends.', icon: '🤝' },
        ],
        columns: 3,
      };
    case 'stats':
      return {
        id,
        kind: 'stats',
        items: [
          { id: newSectionId(), title: 'Downloads', body: '', value: '12,453' },
          { id: newSectionId(), title: 'Games', body: '', value: '11' },
          { id: newSectionId(), title: 'Players online', body: '', value: '237' },
        ],
        columns: 3,
      };
    case 'timeline':
      return {
        id,
        kind: 'timeline',
        items: [
          { id: newSectionId(), title: 'Concept', body: 'Game starts as a doodle.', status: 'done' },
          { id: newSectionId(), title: 'Beta', body: 'Public testing begins.', status: 'progress' },
          { id: newSectionId(), title: 'Launch', body: 'Public release.', status: 'planned' },
        ],
      };
    case 'accordion':
      return {
        id,
        kind: 'accordion',
        items: [
          { id: newSectionId(), title: 'Question one?', body: 'Answer one.' },
          { id: newSectionId(), title: 'Question two?', body: 'Answer two.' },
        ],
      };
    case 'tabs':
      return {
        id,
        kind: 'tabs',
        tabs: [
          { id: newSectionId(), label: 'Overview', sections: [] },
          { id: newSectionId(), label: 'Details', sections: [] },
        ],
      };
    case 'cta':
      return {
        id,
        kind: 'cta',
        title: 'Ready to play?',
        body: 'Jump in — no download required.',
        primary: { label: 'Play now', href: '/', external: false },
      };
    case 'embed':
      return { id, kind: 'embed', url: '', provider: 'youtube', aspect: '16/9', caption: '' };
    case 'markdown':
      return {
        id,
        kind: 'markdown',
        body: '# Markdown heading\n\n- bullet one\n- bullet two\n\n**Bold** and *italic* work too.',
      };
    case 'html':
      return { id, kind: 'html', html: '<!-- Custom HTML — admin trust model -->' };
    case 'spacer':
      return { id, kind: 'spacer', size: 'md' };
    case 'hero':
      return {
        id,
        kind: 'hero',
        title: 'Massive hero',
        subtitle: 'Use this to introduce a section with style.',
        bg_image_url: '',
        height: 'md',
        align: 'center',
        overlay: 0.4,
      };
    case 'download':
      return {
        id,
        kind: 'download',
        title: 'Download the kit',
        body: 'Press kit, logo pack, screenshots — all the assets.',
        href: '',
        format: 'ZIP',
        size: '4.2 MB',
        icon: '📦',
      };
    case 'buttons':
      return {
        id,
        kind: 'buttons',
        buttons: [
          { id: newSectionId(), label: 'Play', href: '/', variant: 'primary', external: false },
          { id: newSectionId(), label: 'Devlog', href: '/devlog', variant: 'secondary', external: false },
        ],
        align: 'left',
      };
    case 'tip_button':
      return {
        id,
        kind: 'tip_button',
        label: '',
        align: 'center',
        variant: 'primary',
      };
    case 'faq':
      return {
        id,
        kind: 'faq',
        intro: '',
        items: [
          { id: newSectionId(), title: 'Is it free?', body: 'Yes — runs in the browser.' },
          { id: newSectionId(), title: 'Mobile-friendly?', body: 'Most titles work on mobile.' },
        ],
      };
    case 'iframe':
      return { id, kind: 'iframe', url: '', height_px: 480, caption: '' };
    case 'sandbox_html':
      return {
        id,
        kind: 'sandbox_html',
        html: '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mini app</title></head><body style="margin:0;font-family:system-ui;background:#0a0f18;color:#e8eeff;display:flex;align-items:center;justify-content:center;min-height:100vh"><p>Replace this with your exported HTML.</p></body></html>',
        iframe_compat: false,
        height_px: 560,
        caption: '',
      };
    case 'image_text':
      return {
        id,
        kind: 'image_text',
        image_url: '',
        title: 'Headline',
        body: 'Long-form description next to an image.',
        image_side: 'left',
        image_alt: '',
      };
    case 'pricing':
      return {
        id,
        kind: 'pricing',
        columns: [
          {
            id: newSectionId(),
            title: 'Free',
            price: '$0',
            period: 'forever',
            features: ['All hub games', 'Community support'],
          },
          {
            id: newSectionId(),
            title: 'Pro',
            price: '$5',
            period: '/month',
            features: ['Everything free', 'Early access builds', 'Cosmetics'],
            featured: true,
          },
        ],
      };
    case 'team':
      return {
        id,
        kind: 'team',
        members: [
          { id: newSectionId(), name: 'Dev One', role: 'Code', avatar_url: '' },
          { id: newSectionId(), name: 'Dev Two', role: 'Art', avatar_url: '' },
        ],
        columns: 3,
      };
    case 'newsletter':
      return {
        id,
        kind: 'newsletter',
        title: 'Subscribe',
        body: 'Get game launches + behind-the-scenes posts.',
        provider: 'custom',
        action_url: '',
        button_label: 'Subscribe',
      };
    case 'game_grid':
      return { id, kind: 'game_grid', title: 'Featured', slugs: [], columns: 3 };
    case 'tags':
      return {
        id,
        kind: 'tags',
        items: [
          { id: newSectionId(), label: 'roguelite', tone: 'accent' },
          { id: newSectionId(), label: 'co-op', tone: 'default' },
        ],
      };
    case 'comments':
      return { id, kind: 'comments', title: 'Comments' };
  }
}

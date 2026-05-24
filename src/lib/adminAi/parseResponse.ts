import type { AdminAiAction, AdminAiResponse } from './types';

export function parseAdminAiResponse(raw: string): AdminAiResponse {
  const trimmed = raw.trim();
  const fence = trimmed.match(/```json\s*([\s\S]*?)```/i);
  if (fence?.[1]) {
    try {
      const parsed = JSON.parse(fence[1]) as AdminAiResponse;
      if (typeof parsed.reply === 'string' && Array.isArray(parsed.actions)) {
        return { reply: parsed.reply, actions: sanitizeActions(parsed.actions) };
      }
    } catch {
      /* fall through */
    }
  }
  try {
    const parsed = JSON.parse(trimmed) as AdminAiResponse;
    if (typeof parsed.reply === 'string' && Array.isArray(parsed.actions)) {
      return { reply: parsed.reply, actions: sanitizeActions(parsed.actions) };
    }
  } catch {
    /* prose only */
  }
  return { reply: trimmed, actions: [] };
}

function sanitizeActions(actions: unknown[]): AdminAiAction[] {
  const out: AdminAiAction[] = [];
  for (const a of actions) {
    if (!a || typeof a !== 'object') continue;
    const o = a as Record<string, unknown>;
    const type = o.type;
    if (type === 'navigate' && typeof o.tab === 'string') {
      out.push({ type: 'navigate', tab: o.tab });
    } else if (type === 'patch_settings' && o.patch && typeof o.patch === 'object') {
      out.push({ type: 'patch_settings', patch: o.patch as Record<string, unknown> });
    } else if (type === 'patch_behavior' && o.patch && typeof o.patch === 'object') {
      out.push({ type: 'patch_behavior', patch: o.patch as Record<string, unknown> });
    } else if (type === 'set_service_draft' && o.draft && typeof o.draft === 'object') {
      const d = o.draft as Record<string, unknown>;
      if (typeof d.slug === 'string' && typeof d.title === 'string') {
        out.push({
          type: 'set_service_draft',
          draft: d as { slug: string; title: string } & Record<string, unknown>,
        });
      }
    } else if (type === 'set_page_draft' && o.draft && typeof o.draft === 'object') {
      const d = o.draft as Record<string, unknown>;
      if (typeof d.slug === 'string' && typeof d.title === 'string') {
        out.push({
          type: 'set_page_draft',
          draft: d as { slug: string; title: string } & Record<string, unknown>,
        });
      }
    } else if (type === 'append_homepage_button' && typeof o.label === 'string' && typeof o.href === 'string') {
      out.push({
        type: 'append_homepage_button',
        label: o.label,
        href: o.href,
        variant:
          o.variant === 'secondary' || o.variant === 'ghost' || o.variant === 'primary'
            ? o.variant
            : 'primary',
        align: o.align === 'left' || o.align === 'right' ? o.align : 'center',
      });
    } else if (
      type === 'remind_save' &&
      (o.target === 'studio' || o.target === 'settings' || o.target === 'services' || o.target === 'pages')
    ) {
      out.push({ type: 'remind_save', target: o.target });
    }
  }
  return out;
}

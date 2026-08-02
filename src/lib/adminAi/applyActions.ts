import type { Dispatch, SetStateAction } from 'react';
import type { PageSection, SiteService, SiteSettings } from '../../types';
import {
  ADMIN_AI_PAGE_DRAFT_KEY,
  ADMIN_AI_SERVICE_DRAFT_KEY,
  type AdminAiAction,
} from './types';

const SETTINGS_KEYS = new Set([
  'hero_title',
  'hero_subtitle',
  'site_visual_preset',
  'support_title',
  'support_body',
  'footer_text',
  'stripe_tip_url',
  'support_page_href',
]);

const BEHAVIOR_KEYS = new Set([
  'show_services_link',
  'show_apps_lab_link',
  'show_home_nav_link',
  'show_vault_link',
  'show_devlog_link',
  'enable_services_page',
  'enable_apps_hub_page',
  'enable_vault_page',
  'enable_devlog_section',
  'first_party_analytics_enabled',
  'maintenance_mode',
]);

export type ApplyAdminAiArgs = {
  actions: AdminAiAction[];
  setTab: (tab: string) => void;
  setSettings: Dispatch<SetStateAction<SiteSettings>>;
  flash: (msg: string) => void;
};

export function applyAdminAiActions({ actions, setTab, setSettings, flash }: ApplyAdminAiArgs): string[] {
  const notes: string[] = [];

  for (const action of actions) {
    switch (action.type) {
      case 'navigate':
        setTab(action.tab);
        notes.push(`Opened tab: ${action.tab}`);
        break;
      case 'patch_settings': {
        const patch: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(action.patch)) {
          if (SETTINGS_KEYS.has(k)) patch[k] = v;
        }
        if (Object.keys(patch).length) {
          setSettings((s) => ({ ...s, ...patch }));
          notes.push(`Updated settings: ${Object.keys(patch).join(', ')}`);
        }
        break;
      }
      case 'patch_behavior': {
        const bp: Record<string, unknown> = {};
        for (const [k, v] of Object.entries(action.patch)) {
          if (BEHAVIOR_KEYS.has(k)) bp[k] = v;
        }
        if (Object.keys(bp).length) {
          setSettings((s) => ({
            ...s,
            behavior: { ...s.behavior, ...bp },
          }));
          notes.push(`Updated behavior: ${Object.keys(bp).join(', ')}`);
        }
        break;
      }
      case 'append_homepage_button': {
        const btnId = crypto.randomUUID();
        const section: PageSection = {
          id: crypto.randomUUID(),
          kind: 'buttons',
          align: action.align ?? 'center',
          buttons: [
            {
              id: btnId,
              label: action.label.trim() || 'Button',
              href: action.href.trim() || '/',
              external: /^https?:\/\//i.test(action.href),
              variant: action.variant ?? 'primary',
            },
          ],
        };
        setSettings((s) => ({
          ...s,
          homepage_sections: [...(s.homepage_sections ?? []), section],
          homepage_layout_mode:
            s.homepage_layout_mode === 'replace' ? 'replace' : s.homepage_layout_mode ?? 'prepend',
        }));
        setTab('overview');
        notes.push(`Added homepage button “${action.label}” → ${action.href}`);
        break;
      }
      case 'set_service_draft': {
        const draft = action.draft as Partial<SiteService> & { slug: string; title: string };
        try {
          sessionStorage.setItem(ADMIN_AI_SERVICE_DRAFT_KEY, JSON.stringify(draft));
          setTab('services');
          notes.push(`Loaded service draft “${draft.title}” — open Services tab and Save.`);
        } catch {
          notes.push('Could not stash service draft (storage blocked).');
        }
        break;
      }
      case 'set_page_draft': {
        const draft = action.draft as { slug: string; title: string } & Record<string, unknown>;
        try {
          sessionStorage.setItem(ADMIN_AI_PAGE_DRAFT_KEY, JSON.stringify(draft));
          setTab('pages');
          notes.push(`Loaded page draft “${draft.title}” — open Pages tab and Save.`);
        } catch {
          notes.push('Could not stash page draft (storage blocked).');
        }
        break;
      }
      case 'remind_save':
        flash(
          action.target === 'settings'
            ? 'AI updated draft — click Save on Site copy.'
            : action.target === 'services'
              ? 'AI loaded a service draft — review Services tab and Save.'
              : action.target === 'pages'
                ? 'AI loaded a page draft — review Pages tab and Save.'
                : 'AI updated studio draft — click Save studio settings.',
        );
        notes.push(`Reminder: save ${action.target}`);
        break;
      default:
        break;
    }
  }

  return notes;
}

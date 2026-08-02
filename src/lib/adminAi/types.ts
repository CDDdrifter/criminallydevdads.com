import type { SitePage, SiteService, SiteSettings } from '../../types';

export type AdminAiProvider = 'gemini';

export type AdminAiAction =
  | { type: 'navigate'; tab: string }
  | { type: 'patch_settings'; patch: Record<string, unknown> }
  | { type: 'patch_behavior'; patch: Record<string, unknown> }
  | { type: 'set_service_draft'; draft: Partial<SiteService> & { slug: string; title: string } }
  | { type: 'set_page_draft'; draft: Partial<SitePage> & { slug: string; title: string } }
  | {
      type: 'append_homepage_button';
      label: string;
      href: string;
      variant?: 'primary' | 'secondary' | 'ghost';
      align?: 'left' | 'center' | 'right';
    }
  | { type: 'remind_save'; target: 'studio' | 'settings' | 'services' | 'pages' };

export type AdminAiResponse = {
  reply: string;
  actions: AdminAiAction[];
};

export type AdminAiContext = {
  currentTab: string;
  settingsSummary: string;
  gamesCount: number;
  pagesCount: number;
  servicesCount: number;
};

export const ADMIN_AI_SERVICE_DRAFT_KEY = 'cdd_admin_ai_service_draft';
export const ADMIN_AI_PAGE_DRAFT_KEY = 'cdd_admin_ai_page_draft';
export const ADMIN_AI_GEMINI_KEY_STORAGE = 'cdd_admin_gemini_api_key';

export type AllowedSettingsPatch = Partial<
  Pick<
    SiteSettings,
    | 'hero_title'
    | 'hero_subtitle'
    | 'support_title'
    | 'support_body'
    | 'footer_text'
    | 'stripe_tip_url'
    | 'site_visual_preset'
    | 'support_page_href'
  >
>;

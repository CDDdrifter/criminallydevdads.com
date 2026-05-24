import type { SiteService, SiteSettings } from '../../types';

export type AdminAiProvider = 'gemini';

export type AdminAiAction =
  | { type: 'navigate'; tab: string }
  | { type: 'patch_settings'; patch: Record<string, unknown> }
  | { type: 'patch_behavior'; patch: Record<string, unknown> }
  | { type: 'set_service_draft'; draft: Partial<SiteService> & { slug: string; title: string } }
  | { type: 'remind_save'; target: 'studio' | 'settings' | 'services' };

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

export type AllowedSettingsPatch = Partial<
  Pick<
    SiteSettings,
    | 'hero_title'
    | 'hero_subtitle'
    | 'support_title'
    | 'support_body'
    | 'footer_text'
    | 'stripe_donation_url'
    | 'site_visual_preset'
    | 'support_page_href'
  >
>;

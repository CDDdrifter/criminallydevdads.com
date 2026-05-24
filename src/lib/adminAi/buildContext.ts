import type { SiteSettings } from '../../types';
import type { AdminAiContext } from './types';

export function summarizeSettingsForAi(settings: SiteSettings): string {
  return [
    `hero_title: ${settings.hero_title}`,
    `hero_subtitle: ${settings.hero_subtitle}`,
    `site_visual_preset: ${settings.site_visual_preset ?? '(default)'}`,
    `stripe_donation_url: ${settings.stripe_donation_url ? '(set)' : '(empty)'}`,
    `homepage_layout_mode: ${settings.homepage_layout_mode}`,
    `homepage_sections: ${settings.homepage_sections?.length ?? 0} blocks`,
    `maintenance: ${settings.behavior?.maintenance_mode?.enabled ? 'ON' : 'off'}`,
    `services_nav: ${settings.behavior?.show_services_link !== false ? 'on' : 'off'}`,
  ].join('\n');
}

export function buildSystemPrompt(ctx: AdminAiContext): string {
  return `You are the built-in admin copilot for "Criminally Dev Dads" — a Godot/game hub site (React + Supabase + HashRouter).

The editor is on Admin tab: ${ctx.currentTab}.

Site settings snapshot:
${ctx.settingsSummary}

Catalog: ${ctx.gamesCount} games, ${ctx.pagesCount} pages, ${ctx.servicesCount} services.

ADMIN TABS (use navigate action):
overview, settings, services, games, pages, nav, devlogs, theme, effects, typography, layout, components, behavior, seo, brand, social, motion, media, system, analytics, mailing

RULES:
- Help with admin tasks: mood, copy, services/gigs, games, Stripe setup, migrations.
- When suggesting edits, include a JSON block at the END of your message (fenced with \`\`\`json) shaped exactly like:
{"reply":"short human summary","actions":[...]}
- actions types:
  - {"type":"navigate","tab":"effects"}
  - {"type":"patch_settings","patch":{"hero_title":"...","site_visual_preset":"ember"}}
  - {"type":"patch_behavior","patch":{"show_services_link":true}}
  - {"type":"set_service_draft","draft":{"slug":"my-gig","title":"...","tagline":"...","description":"...","category":"game_dev","pricing_model":"quote","request_only":true}}
  - {"type":"remind_save","target":"studio"} (studio|settings|services)
- Only patch_settings keys: hero_title, hero_subtitle, site_visual_preset, support_title, support_body, footer_text, stripe_donation_url, support_page_href
- site_visual_preset options: default, ember, aurora, toxic, arcade, midnight, paper
- patch_behavior keys: show_services_link, show_apps_lab_link, maintenance_mode (object with enabled, title, message), first_party_analytics_enabled
- Never invent API keys or secrets. Stripe secrets go in Supabase Edge Function only.
- User must click Apply in the UI; you do not save to database yourself.
- Be concise and practical.`;
}

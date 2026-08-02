/**
 * Zero-cost admin copilot fallback — pattern matching + structured edit actions.
 */
import { hireUsPageDraft } from '../pageTemplates';
import type { AdminAiAction, AdminAiContext, AdminAiResponse } from './types';

const TABS = [
  'overview',
  'ai',
  'settings',
  'services',
  'games',
  'pages',
  'nav',
  'devlogs',
  'theme',
  'effects',
  'typography',
  'layout',
  'components',
  'behavior',
  'seo',
  'brand',
  'social',
  'motion',
  'media',
  'system',
  'analytics',
  'mailing',
] as const;

const MOODS = ['default', 'ember', 'aurora', 'toxic', 'arcade', 'midnight', 'paper'] as const;

const TAB_ALIASES: Record<string, string> = {
  home: 'overview',
  homepage: 'overview',
  copy: 'settings',
  'site copy': 'settings',
  gig: 'services',
  gigs: 'services',
  fiverr: 'services',
  upwork: 'services',
  commerce: 'services',
  game: 'games',
  page: 'pages',
  navigation: 'nav',
  devlog: 'devlogs',
  blog: 'devlogs',
  mood: 'effects',
  fx: 'effects',
  colors: 'theme',
  colour: 'theme',
  font: 'typography',
  fonts: 'typography',
  hero: 'brand',
  logo: 'brand',
  stats: 'analytics',
  email: 'mailing',
  newsletter: 'mailing',
  subscribers: 'mailing',
};

type FaqEntry = {
  id: string;
  test: (msg: string) => boolean;
  reply: string;
  actions?: AdminAiAction[];
};

function norm(msg: string): string {
  return msg.toLowerCase().replace(/\s+/g, ' ').trim();
}

function findTab(msg: string): string | null {
  const n = norm(msg);
  for (const tab of TABS) {
    if (new RegExp(`\\b${tab}\\b`).test(n)) return tab;
  }
  for (const [alias, tab] of Object.entries(TAB_ALIASES)) {
    if (new RegExp(`\\b${alias}\\b`).test(n)) return tab;
  }
  if (/\b(open|go to|show|switch to)\b/.test(n)) {
    const m = n.match(/\b(open|go to|show|switch to)\s+(?:the\s+)?(\w+(?:\s+\w+)?)/);
    if (m?.[2]) {
      const word = m[2].replace(/\s+/g, ' ');
      if (TAB_ALIASES[word]) return TAB_ALIASES[word];
      for (const tab of TABS) {
        if (word.startsWith(tab)) return tab;
      }
    }
  }
  return null;
}

function findMood(msg: string): string | null {
  const n = norm(msg);
  for (const m of MOODS) {
    if (new RegExp(`\\b${m}\\b`).test(n)) return m;
  }
  return null;
}

function extractQuotedOrAfter(msg: string, labels: string[]): string | null {
  const q = msg.match(/["“]([^"”]+)["”]/);
  if (q?.[1]) return q[1].trim();
  for (const label of labels) {
    const re = new RegExp(`${label}\\s*(?:to|=|:)\\s*(.+)$`, 'i');
    const m = msg.match(re);
    if (m?.[1]) return m[1].trim().replace(/\.$/, '');
  }
  return null;
}

const FAQ: FaqEntry[] = [
  {
    id: 'help',
    test: (m) => /^(help|what can you do|commands)\??$/.test(norm(m)),
    reply: `I'm the built-in fallback copilot. For real AI edits, add GEMINI_API_KEY in Supabase Edge secrets (free Google AI Studio key).

I can still:
• Add homepage buttons ("add button Hire us → /p/hire-us")
• Open tabs, change hero/mood, hide built-in pages while editing
• Draft services/pages and load them into Admin

Try: "add button Get a quote → /services" or "hide services page while I edit".`,
  },
  {
    id: 'stripe',
    test: (m) => /\bstripe\b/.test(norm(m)) && /\b(how|setup|set up|configure|secret)\b/.test(norm(m)),
    reply: `Stripe (no keys in GitHub):
1. Create Stripe account + Products/Prices or Payment Links.
2. Supabase → Edge Functions → Secrets: STRIPE_SECRET_KEY, SITE_URL (your public hub URL), SERVICE_ROLE_KEY.
3. Deploy: create-checkout-session
4. Games tab: pricing model + price OR Games/Services → external Payment Link URL.
5. Site copy: Stripe tip URL for homepage tips.

Docs in repo: docs/STRIPE_CHECKOUT.md and docs/SERVICES_COMMERCE.md`,
    actions: [{ type: 'navigate', tab: 'services' }],
  },
  {
    id: 'migrations',
    test: (m) => /\b(migration|sql|supabase)\b/.test(norm(m)) && /\b(run|which|020|021|022|024|025)\b/.test(norm(m)),
    reply: `Run these in Supabase SQL Editor (in order if fresh):
020 — profiles, comments, analytics
021 — analytics extended
022 — usernames + mailing list
024 — admin comment/user lists + per-game analytics
025 — services & gigs catalog

After SQL, redeploy site from GitHub Actions. Edge functions: create-checkout-session, mailing-broadcast (needs Resend only if you email subscribers).`,
  },
  {
    id: 'mood-help',
    test: (m) => /\b(mood|preset|visual)\b/.test(norm(m)) && /\b(what|where|how|explain)\b/.test(norm(m)),
    reply: `Hub mood = Effects → Site mood preset (applies to Home, Vault, Dev log). Per-game mood = Games/Pages → Appearance panel. Homepage was fixed to respect hub mood. After changes: Save studio settings, then refresh the public site.`,
    actions: [{ type: 'navigate', tab: 'effects' }],
  },
  {
    id: 'services-page',
    test: (m) => /\b(services page|sell|gig|commission|fiverr)\b/.test(norm(m)) && !/\b(set|change|mood)\b/.test(norm(m)),
    reply: `Public services hub: /services. Edit offerings in Admin → Services. Each row can be quote-only (email form), Stripe fixed/PWYW/tip, or external Gumroad/Stripe link. Overview → Monetization panel has shortcuts.`,
    actions: [{ type: 'navigate', tab: 'services' }],
  },
  {
    id: 'hire-us',
    test: (m) => /\bhire\b/.test(norm(m)),
    reply: `Hire Us page: Admin → Pages → "New: Hire Us page" loads a template at /#/p/hire-us. Edit blocks, Save page, enable Show in top nav. Or add a service row in Services for the same offer.`,
    actions: [{ type: 'navigate', tab: 'pages' }],
  },
];

export function askCopilotAgent(userMessage: string, ctx: AdminAiContext): AdminAiResponse {
  const msg = userMessage.trim();
  const n = norm(msg);
  const actions: AdminAiAction[] = [];
  const lines: string[] = [];

  for (const faq of FAQ) {
    if (faq.test(msg)) {
      return { reply: faq.reply, actions: faq.actions ?? [] };
    }
  }

  const tab = findTab(msg);
  if (tab && /\b(open|go to|show|switch|navigate)\b/.test(n)) {
    actions.push({ type: 'navigate', tab });
    lines.push(`Opening **${tab}** tab.`);
  }

  const mood = findMood(msg);
  if (mood && /\b(mood|preset|theme|visual|set|change)\b/.test(n)) {
    actions.push({ type: 'patch_settings', patch: { site_visual_preset: mood } });
    actions.push({ type: 'navigate', tab: 'effects' });
    actions.push({ type: 'remind_save', target: 'studio' });
    lines.push(`Setting hub mood to **${mood}**. Open Effects to preview, then Save studio settings.`);
  }

  const heroTitle = extractQuotedOrAfter(msg, ['hero title', 'title', 'hero']);
  if (heroTitle && /\b(hero|title|heading)\b/.test(n)) {
    actions.push({ type: 'patch_settings', patch: { hero_title: heroTitle } });
    actions.push({ type: 'remind_save', target: 'studio' });
    lines.push(`Hero title → "${heroTitle}".`);
  }

  const heroSub = extractQuotedOrAfter(msg, ['hero subtitle', 'subtitle', 'tagline']);
  if (heroSub && /\b(subtitle|tagline)\b/.test(n)) {
    actions.push({ type: 'patch_settings', patch: { hero_subtitle: heroSub } });
    actions.push({ type: 'remind_save', target: 'studio' });
    lines.push(`Hero subtitle → "${heroSub}".`);
  }

  if (/\b(hide|turn off|disable)\b.*\b(services|vault|dev ?log|apps)\b.*\b(page|section|route)\b/.test(n)) {
    const patch: Record<string, unknown> = {};
    if (/\bservices\b/.test(n)) {
      patch.enable_services_page = false;
      patch.show_services_link = false;
    }
    if (/\bvault\b/.test(n)) {
      patch.enable_vault_page = false;
      patch.show_vault_link = false;
    }
    if (/\bdev\b/.test(n)) {
      patch.enable_devlog_section = false;
      patch.show_devlog_link = false;
    }
    if (/\bapps\b/.test(n)) {
      patch.enable_apps_hub_page = false;
      patch.show_apps_lab_link = false;
    }
    if (Object.keys(patch).length) {
      actions.push({ type: 'patch_behavior', patch });
      actions.push({ type: 'remind_save', target: 'studio' });
      lines.push('Turned off the requested built-in page(s) for visitors — Save studio settings.');
    }
  }

  if (/\b(show|enable|turn on)\b.*\b(services|vault|dev ?log|apps)\b.*\b(page|section|route)\b/.test(n)) {
    const patch: Record<string, unknown> = {};
    if (/\bservices\b/.test(n)) {
      patch.enable_services_page = true;
      patch.show_services_link = true;
    }
    if (/\bvault\b/.test(n)) {
      patch.enable_vault_page = true;
      patch.show_vault_link = true;
    }
    if (/\bdev\b/.test(n)) {
      patch.enable_devlog_section = true;
      patch.show_devlog_link = true;
    }
    if (/\bapps\b/.test(n)) {
      patch.enable_apps_hub_page = true;
      patch.show_apps_lab_link = true;
    }
    if (Object.keys(patch).length) {
      actions.push({ type: 'patch_behavior', patch });
      actions.push({ type: 'remind_save', target: 'studio' });
      lines.push('Re-enabled the requested built-in page(s) for visitors.');
    }
  }

  if (/\b(add|create|put)\b.*\bbutton\b/.test(n) || /\bbutton\b.*\b(add|to)\b/.test(n)) {
    const label =
      extractQuotedOrAfter(msg, ['button', 'labeled', 'label', 'called', 'saying', 'text']) ||
      (n.match(/\bbutton\s+(?:to|for)\s+([^.]+)/)?.[1]?.trim() ?? 'Learn more');
    const hrefMatch = msg.match(
      /(?:to|href|link|→|->)\s*(\/[\w/-]+|https?:\/\/[^\s"'<>]+)/i,
    );
    const href = hrefMatch?.[1]?.trim() ?? '/services';
    actions.push({
      type: 'append_homepage_button',
      label: label.slice(0, 80),
      href,
      variant: /\bsecondary\b/.test(n) ? 'secondary' : 'primary',
    });
    actions.push({ type: 'navigate', tab: 'overview' });
    actions.push({ type: 'remind_save', target: 'studio' });
    lines.push(`Added homepage button “${label.slice(0, 40)}” → ${href}. Save studio settings.`);
  }

  if (/\b(draft|load|edit)\b.*\bhire\b/.test(n) || /\bhire us page\b/.test(n)) {
    actions.push({
      type: 'set_page_draft',
      draft: { ...hireUsPageDraft(), published: false, show_in_nav: false },
    });
    actions.push({ type: 'remind_save', target: 'pages' });
    lines.push('Loaded Hire Us page draft (unpublished) → Pages tab.');
  }

  if (/\b(enable|turn on|show)\b.*\bservices\b.*\b(nav|link)\b/.test(n) || /\bservices nav on\b/.test(n)) {
    actions.push({ type: 'patch_behavior', patch: { show_services_link: true } });
    actions.push({ type: 'remind_save', target: 'studio' });
    lines.push('Services link in navigation: **on**.');
  }

  if (/\b(disable|turn off|hide)\b.*\bservices\b.*\b(nav|link)\b/.test(n)) {
    actions.push({ type: 'patch_behavior', patch: { show_services_link: false } });
    actions.push({ type: 'remind_save', target: 'studio' });
    lines.push('Services link in navigation: **off**.');
  }

  if (/\bmaintenance\b.*\b(off|disable)\b/.test(n)) {
    actions.push({
      type: 'patch_behavior',
      patch: {
        maintenance_mode: { enabled: false, title: '', message: '', allow_admin_bypass: true },
      },
    });
    actions.push({ type: 'remind_save', target: 'studio' });
    lines.push('Maintenance mode: **off**.');
  }

  if (/\bmaintenance\b.*\b(on|enable)\b/.test(n)) {
    actions.push({
      type: 'patch_behavior',
      patch: {
        maintenance_mode: {
          enabled: true,
          title: 'We will be right back',
          message: 'The hub is in maintenance. Check back soon.',
          allow_admin_bypass: true,
        },
      },
    });
    actions.push({ type: 'remind_save', target: 'studio' });
    lines.push('Maintenance mode: **on** (admins can still bypass).');
  }

  if (/\b(game demo|prototype)\b/.test(n) && /\b(service|gig|create|add|draft)\b/.test(n)) {
    actions.push({
      type: 'set_service_draft',
      draft: {
        slug: 'game-demo-prototype',
        title: 'Game demo / prototype',
        tagline: 'Playable vertical slice in Godot (web export)',
        description:
          'Scoped playable demo: core loop, one level, web build. Perfect before full production.',
        category: 'game_dev',
        kind: 'service',
        icon_emoji: '🎮',
        pricing_model: 'quote',
        request_only: true,
        request_form_enabled: true,
        cta_label: 'Request a quote',
        features: ['Godot 4 web export', 'Source handoff', '1–3 week typical scope'],
      },
    });
    lines.push('Loaded **Game demo / prototype** service draft → Services tab. Review and Save.');
  }

  if (/\b(website|web site)\b/.test(n) && /\b(service|create|build|gig)\b/.test(n)) {
    actions.push({
      type: 'set_service_draft',
      draft: {
        slug: 'website-creation',
        title: 'Website creation',
        tagline: 'Marketing sites and game hubs',
        description: 'Custom sites with CMS, games, auth, and Stripe when you are ready.',
        category: 'web',
        pricing_model: 'quote',
        request_only: true,
        request_form_enabled: true,
        cta_label: 'Build my site',
        icon_emoji: '🌐',
      },
    });
    lines.push('Loaded **Website creation** service draft.');
  }

  if (lines.length) {
    return {
      reply: `${lines.join('\n')}\n\nClick **Apply suggestions**, then **Save** on the tab I opened.\n\nCurrent tab: ${ctx.currentTab}. Catalog: ${ctx.gamesCount} games, ${ctx.pagesCount} pages, ${ctx.servicesCount} services.`,
      actions,
    };
  }

  if (tab) {
    return {
      reply: `Opening **${tab}**. You are on **${ctx.currentTab}** now.\n\nSite snapshot:\n${ctx.settingsSummary}\n\nAsk "help" for commands, or be specific: "set mood to ember", "set hero title to …".`,
      actions: [{ type: 'navigate', tab }],
    };
  }

  return {
    reply: `No match in built-in fallback. For natural-language edits, set **GEMINI_API_KEY** in Supabase → Edge Functions → Secrets (free key from Google AI Studio), deploy \`admin-copilot\`, and sign in as admin.

**Built-in still understands:**
• "add button Hire us → /p/hire-us"
• "hide services page while I edit"
• "set mood to ember" · "open pages"

**Now:** tab \`${ctx.currentTab}\` · ${ctx.gamesCount} games · ${ctx.pagesCount} pages · ${ctx.servicesCount} services.`,
    actions: [],
  };
}

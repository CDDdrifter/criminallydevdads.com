/**
 * Zero-cost admin copilot — runs entirely in the browser (no API keys).
 * Pattern matching + built-in site knowledge + structured edit actions.
 */
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
    reply: `I'm your built-in admin copilot (100% free, no API keys). I can:
• Open admin tabs ("open effects", "go to services")
• Change hero title/subtitle, hub mood, support copy
• Toggle Services nav, maintenance mode, analytics
• Draft a service gig and load it into Services
• Explain Stripe, migrations, and where to click Save

Try: "set mood to ember" or "set hero title to CRIMINALLY DEV DADS" then Apply.`,
  },
  {
    id: 'stripe',
    test: (m) => /\bstripe\b/.test(norm(m)) && /\b(how|setup|set up|configure|secret)\b/.test(norm(m)),
    reply: `Stripe (no keys in GitHub):
1. Create Stripe account + Products/Prices or Payment Links.
2. Supabase → Edge Functions → Secrets: STRIPE_SECRET_KEY, SITE_URL (your public hub URL), SERVICE_ROLE_KEY.
3. Deploy: create-checkout-session
4. Games tab: pricing model + price OR Games/Services → external Payment Link URL.
5. Site copy: Stripe donation URL for homepage tips.

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
    reply: `Public services hub: /#/services. Edit offerings in Admin → Services (migration 025). Each row can be quote-only (email form), Stripe fixed/PWYW/donation, or external Gumroad/Stripe link. Overview → Monetization panel has shortcuts.`,
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
    reply: `I didn't match that command yet (I run free, on-device — no ChatGPT).

**Try:**
• "help"
• "open effects" / "go to services"
• "set mood to ember"
• "set hero title to CRIMINALLY DEV DADS"
• "turn on services nav"
• "how do I set up stripe"
• "create game demo service"

**Now:** tab \`${ctx.currentTab}\` · ${ctx.gamesCount} games · ${ctx.pagesCount} pages · ${ctx.servicesCount} services.`,
    actions: [],
  };
}

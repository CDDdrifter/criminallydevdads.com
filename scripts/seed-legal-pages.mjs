/**
 * Append draft legal CMS pages to cms/site-pages.json (unpublished).
 * Run once: node scripts/seed-legal-pages.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';

const path = new URL('../cms/site-pages.json', import.meta.url);
const pages = JSON.parse(readFileSync(path, 'utf8'));

const disclaimer = {
  id: randomUUID(),
  kind: 'callout',
  tone: 'warning',
  icon: '⚠️',
  title: 'Template — review before publishing',
  body: 'Starter text only. Replace placeholders and have a qualified professional review before you publish or accept payments.',
};

function legalPage(slug, title, bodyText, sortOrder) {
  return {
    id: randomUUID(),
    slug,
    title,
    body: '',
    sections: [
      { id: randomUUID(), kind: 'heading', title },
      disclaimer,
      { id: randomUUID(), kind: 'text', body: bodyText },
    ],
    show_in_nav: false,
    published: false,
    comments_enabled: false,
    sort_order: sortOrder,
    page_mode: 'blocks',
    raw_html: '',
    unlisted: true,
    show_on_apps_hub: false,
    html_app_summary: '',
    html_iframe_compat: false,
    visual_preset: null,
    immersive_layout: false,
    custom_mood_css: '',
  };
}

const seeds = [
  legalPage(
    'terms',
    'Terms of Service',
    'By accessing Criminally Dev Dads (the "Site") or purchasing products or services, you agree to these Terms. If you do not agree, do not use the Site. We may update these Terms at any time; continued use means acceptance. Eligibility: you must be the age of majority in your jurisdiction. Accounts: you are responsible for activity under your account. Purchases are governed by our Refund Policy. We provide the Site "as is" and disclaim warranties to the fullest extent permitted by law. Our liability is limited to the amount you paid in the prior 12 months. Contact: support@criminallydevdads.com.',
    900,
  ),
  legalPage(
    'privacy',
    'Privacy Policy',
    'This Policy explains how Criminally Dev Dads collects and uses information. We collect: account details (email), order/payment metadata (processed by Stripe — we do not store card numbers), mailing-list opt-ins, and basic analytics. We use this to provide services, process orders, send updates you opt into, and improve the Site. We share data only with processors (e.g. Stripe, hosting/email providers) as needed. You may request access or deletion at support@criminallydevdads.com. See our Cookie Policy for cookies and local storage.',
    901,
  ),
  legalPage(
    'refund',
    'Refund Policy',
    'All sales are final for digital products (downloads, keys, game access) and commissioned/custom work once delivered or once work has begun. By completing checkout you waive any right of withdrawal for digital goods supplied immediately, where permitted by law. Physical products may be returned only if they arrive damaged or defective — contact support@criminallydevdads.com within 14 days with photos. Chargebacks filed without first contacting us may result in account suspension. Where local law grants non-waivable refund rights, those rights still apply.',
    902,
  ),
  legalPage(
    'cookie',
    'Cookie Policy',
    'Criminally Dev Dads uses essential cookies and local storage to run the Site (sessions, preferences, cookie-consent state). If analytics are enabled, we may set analytics cookies to understand usage. You can clear cookies in your browser at any time; disabling essential cookies may break parts of the Site.',
    903,
  ),
  legalPage(
    'dmca',
    'DMCA / Copyright',
    'If you believe content on our Site infringes your copyright, email support@criminallydevdads.com with: your contact info, identification of the copyrighted work, the URL of the infringing material, and a statement of good faith. We respond to valid notices and may remove or disable access to allegedly infringing material.',
    904,
  ),
  legalPage(
    'disclaimer',
    'Disclaimer',
    'Games and content on this Site are provided for entertainment. We do not guarantee uninterrupted access. Nothing on the Site is professional advice. Use at your own risk.',
    905,
  ),
];

const existing = new Set(pages.map((p) => p.slug));
let added = 0;
for (const page of seeds) {
  if (existing.has(page.slug)) {
    console.log(`skip ${page.slug} (already exists)`);
    continue;
  }
  pages.push(page);
  existing.add(page.slug);
  added++;
}

writeFileSync(path, `${JSON.stringify(pages, null, 2)}\n`, 'utf8');
console.log(`Done — added ${added} draft legal page(s) to cms/site-pages.json`);

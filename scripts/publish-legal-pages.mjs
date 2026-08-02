/**
 * Publish legal CMS pages + ensure professional starter content in cms/site-pages.json.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';

const path = new URL('../cms/site-pages.json', import.meta.url);
const pages = JSON.parse(readFileSync(path, 'utf8'));

function section(kind, data) {
  return { id: randomUUID(), kind, ...data };
}

const LEGAL_CONTENT = {
  terms: {
    title: 'Terms of Service',
    sections: [
      section('heading', { title: 'Terms of Service', subtitle: 'Criminally Dev Dads' }),
      section('panel', {
        title: 'Agreement',
        variant: 'default',
        body: 'By accessing criminallydevdads.com (the "Site") or purchasing products, tips, or services from us, you agree to these Terms of Service. If you do not agree, please do not use the Site. We may update these Terms from time to time; continued use after changes means you accept the updated Terms.',
      }),
      section('panel', {
        title: 'Eligibility & accounts',
        variant: 'default',
        body: 'You must be at least the age of majority in your jurisdiction to use the Site or make purchases. When you sign in with Google, you are responsible for all activity under your account. Keep your account secure and notify us if you suspect unauthorized access.',
      }),
      section('panel', {
        title: 'Purchases & digital goods',
        variant: 'default',
        body: 'Prices, tips, and purchases are processed by Stripe or other payment providers we designate. Voluntary tips are not tax-deductible charitable contributions. Digital products, game access, and custom work are governed by our Refund Policy. We provide the Site and games "as is" and disclaim warranties to the fullest extent permitted by law. Our total liability is limited to the amount you paid us in the twelve (12) months before the claim.',
      }),
      section('panel', {
        title: 'Contact',
        variant: 'default',
        body: 'Questions about these Terms: support@criminallydevdads.com',
      }),
    ],
  },
  privacy: {
    title: 'Privacy Policy',
    sections: [
      section('heading', { title: 'Privacy Policy', subtitle: 'How we handle your information' }),
      section('panel', {
        title: 'Information we collect',
        variant: 'default',
        body: 'We collect: account details (email when you sign in with Google), mailing-list preferences, support messages, and first-party analytics when enabled — including pages visited, games played, session ID, referrer URL, marketing UTM parameters, browser language, and screen size. Payment metadata comes from Stripe; we never store full card numbers.',
      }),
      section('panel', {
        title: 'How we use it',
        variant: 'default',
        body: 'We use this information to operate the Site, deliver games and services, process purchases and tips, send updates you opt into, measure traffic, improve our products, and show ads when enabled. We do not sell your personal information to data brokers.',
      }),
      section('panel', {
        title: 'Advertising & third parties',
        variant: 'default',
        body: 'If we display ads (e.g. Google AdSense), those partners may use cookies or similar technologies under their own policies. Payment processing is handled by Stripe. Hosting and analytics providers process data on our behalf under contract.',
      }),
      section('panel', {
        title: 'Your rights & contact',
        variant: 'default',
        body: 'You may request access, correction, or deletion of your personal data by emailing support@criminallydevdads.com. See our Cookie Policy for cookies and local storage.',
      }),
    ],
  },
  refund: {
    title: 'Refund Policy',
    sections: [
      section('heading', { title: 'Refund Policy', subtitle: 'Digital goods & services' }),
      section('callout', {
        tone: 'neutral',
        icon: 'ℹ️',
        title: 'Digital products',
        body: 'Tips, downloads, game access, and commissioned or custom digital work are generally non-refundable once delivered or once work has begun, except where applicable law requires otherwise.',
      }),
      section('panel', {
        title: 'Voluntary tips',
        variant: 'default',
        body: 'Tips to support development are voluntary payments for creative work — not charitable donations. Tips are final and non-refundable except where required by law or at our sole discretion for clear billing errors.',
      }),
      section('panel', {
        title: 'Physical goods',
        variant: 'default',
        body: 'If we sell physical merchandise, items may be returned only if they arrive damaged or defective. Contact support@criminallydevdads.com within 14 days with your order details and photos.',
      }),
      section('panel', {
        title: 'Chargebacks',
        variant: 'default',
        body: 'Please contact us before initiating a chargeback so we can resolve the issue. Abuse of chargebacks may result in account suspension.',
      }),
    ],
  },
  cookie: {
    title: 'Cookie Policy',
    sections: [
      section('heading', { title: 'Cookie Policy', subtitle: 'Cookies & local storage' }),
      section('panel', {
        title: 'What we use',
        variant: 'default',
        body: 'Criminally Dev Dads uses essential cookies and local storage to run the Site (sign-in, preferences, cookie-consent acknowledgement). When analytics are enabled, we store first-party usage events. When ads are enabled, advertising partners may set additional cookies under their own policies.',
      }),
      section('panel', {
        title: 'Analytics',
        variant: 'default',
        body: 'Analytics may record pages visited, games played, session IDs, referrer URLs, marketing UTM tags, browser language, and screen size. This helps us understand traffic and improve the hub.',
      }),
      section('panel', {
        title: 'Your choices',
        variant: 'default',
        body: 'You can clear cookies and site data in your browser at any time. Disabling essential cookies may prevent sign-in or other core features from working correctly.',
      }),
    ],
  },
  dmca: {
    title: 'DMCA / Copyright',
    sections: [
      section('heading', { title: 'Copyright & DMCA', subtitle: 'Reporting infringement' }),
      section('panel', {
        title: 'Our content',
        variant: 'default',
        body: 'Games, art, and other materials on this Site are owned by Criminally Dev Dads or our licensors unless otherwise noted.',
      }),
      section('panel', {
        title: 'Copyright notices',
        variant: 'default',
        body: 'If you believe content on the Site infringes your copyright, email support@criminallydevdads.com with: (1) your contact information, (2) identification of the copyrighted work, (3) the URL of the material in question, and (4) a statement of good-faith belief that use is not authorized. We will respond to valid notices and may remove or disable access to allegedly infringing material.',
      }),
    ],
  },
  disclaimer: {
    title: 'Disclaimer',
    sections: [
      section('heading', { title: 'Disclaimer', subtitle: 'General information' }),
      section('panel', {
        title: 'Entertainment only',
        variant: 'default',
        body: 'Games and content on Criminally Dev Dads are provided for entertainment. We do not guarantee uninterrupted or error-free access.',
      }),
      section('panel', {
        title: 'No professional advice',
        variant: 'default',
        body: 'Nothing on this Site constitutes legal, financial, medical, or other professional advice. Use the Site and our games at your own risk.',
      }),
    ],
  },
};

const bySlug = new Map(pages.map((p) => [p.slug, p]));

for (const [slug, content] of Object.entries(LEGAL_CONTENT)) {
  const existing = bySlug.get(slug);
  const page = existing ?? { id: randomUUID(), slug, body: '' };
  page.title = content.title;
  page.sections = content.sections;
  page.show_in_nav = false;
  page.published = true;
  page.comments_enabled = false;
  page.unlisted = true;
  page.show_on_apps_hub = false;
  page.page_mode = 'blocks';
  page.raw_html = page.raw_html ?? '';
  page.sort_order = page.sort_order ?? 900;
  if (!existing) pages.push(page);
}

const support = bySlug.get('support');
if (support) {
  support.title = 'Contact & Support';
  support.published = true;
  support.comments_enabled = false;
  support.show_in_nav = true;
}

writeFileSync(path, `${JSON.stringify(pages, null, 2)}\n`, 'utf8');
console.log('Published legal pages in cms/site-pages.json');

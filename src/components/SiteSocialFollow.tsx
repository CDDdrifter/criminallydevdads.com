/**
 * SiteSocialFollow — a row of social-media icons that can render in the
 * header, footer, or both. Driven entirely by `settings.social`.
 *
 * Icons are inline SVGs so we don't pull in any third-party icon library
 * and they re-colour cleanly with `currentColor`.
 */
import { useSiteSettings } from '../hooks/useSiteSettings';
import type { SocialLink } from '../types';

const PLATFORM_LABEL: Record<SocialLink['platform'], string> = {
  discord: 'Discord',
  twitter: 'Twitter / X',
  bluesky: 'Bluesky',
  mastodon: 'Mastodon',
  youtube: 'YouTube',
  twitch: 'Twitch',
  tiktok: 'TikTok',
  itch: 'itch.io',
  github: 'GitHub',
  patreon: 'Patreon',
  kofi: 'Ko-fi',
  instagram: 'Instagram',
  email: 'Email',
  rss: 'RSS',
  custom: 'Website',
};

// Brand colours used when `style === 'colour'`.
const BRAND_COLOR: Partial<Record<SocialLink['platform'], string>> = {
  discord: '#5865f2',
  twitter: '#1da1f2',
  bluesky: '#0085ff',
  mastodon: '#6364ff',
  youtube: '#ff0000',
  twitch: '#9146ff',
  tiktok: '#ff0050',
  itch: '#fa5c5c',
  github: '#e6edf3',
  patreon: '#f96854',
  kofi: '#13c3ff',
  instagram: '#e1306c',
  rss: '#f26522',
};

function Icon({ platform }: { platform: SocialLink['platform'] }) {
  // 24x24 viewBox glyphs — kept compact, monochrome via `currentColor`.
  const path: Record<SocialLink['platform'], string> = {
    discord: 'M20 4.5a18 18 0 0 0-5.3-1.6l-.2.3a13 13 0 0 0-5 0l-.3-.3A18 18 0 0 0 4 4.5C1.6 8 1 11.5 1.3 14.9c2 1.5 4 2.4 6 3l.5-.7a11 11 0 0 1-1.7-.9l.4-.3a12 12 0 0 0 11 0l.4.3c-.5.3-1.1.6-1.8.9l.5.7a17 17 0 0 0 6-3c.4-3.9-.4-7.4-2.6-10.4ZM8.6 13c-1 0-1.8-.9-1.8-2s.8-2 1.8-2c1.1 0 1.9.9 1.9 2s-.8 2-1.9 2Zm6.8 0c-1 0-1.9-.9-1.9-2s.9-2 1.9-2 1.9.9 1.9 2-.9 2-1.9 2Z',
    twitter: 'M18 3h3l-7.5 8.6L22 21h-6.8l-5.3-7L4 21H1l8-9.2L1 3h7l4.8 6.4L18 3Zm-1.2 16h1.9L7.3 5H5.3l11.5 14Z',
    bluesky: 'M5 4.5C8.5 7 11 11 12 14.5 13 11 15.5 7 19 4.5c2 0 2 2.2 2 3.3v6c0 1.7-.8 2.7-1.5 3-1.3.5-3 .3-4-.3 1.5 1.3 1.8 3 .6 4.4-2.5 2.7-3.5-2.2-4.1-3-.6.8-1.6 5.7-4 3-1.3-1.4-1-3 .5-4.4-1 .6-2.7.8-4 .3C3.8 16.5 3 15.5 3 13.8v-6c0-1.1 0-3.3 2-3.3Z',
    mastodon: 'M22 7.6c0 5-3.3 6.4-6.6 6.8-1.7.2-3.5.2-5.2 0v1c.2 2.3 2.3 2.4 4.2 2.4 1.9 0 4-.5 4-.5l.1 1.8s-3 .9-6.4.9c-3.4 0-7.1-1-7.1-7C5 8 7 4 12 4c5 0 10 1.8 10 3.6ZM18 14V8.2c0-1-.7-1.7-2-1.7s-2 .8-2 1.7v3.4h-2V8.2c0-1-.7-1.7-2-1.7s-2 .8-2 1.7V14',
    youtube: 'M23 12s0-3.3-.4-4.9c-.2-.9-1-1.6-1.9-1.8C18.8 5 12 5 12 5s-6.8 0-8.7.3c-.9.2-1.7.9-1.9 1.8C1 8.7 1 12 1 12s0 3.3.4 4.9c.2.9 1 1.6 1.9 1.8 1.9.3 8.7.3 8.7.3s6.8 0 8.7-.3c.9-.2 1.7-.9 1.9-1.8.4-1.6.4-4.9.4-4.9ZM10 15V9l5 3-5 3Z',
    twitch: 'M4 2v18h5v3l3-3h4l6-6V2H4Zm17 11-4 4h-4l-3 3v-3H6V4h15v9Zm-6-7h2v6h-2V6Zm-4 0h2v6h-2V6Z',
    tiktok: 'M22 9.5a8.4 8.4 0 0 1-4.9-1.7v8.7a6.5 6.5 0 1 1-5.6-6.4v3a3.4 3.4 0 1 0 2.4 3.3V2h3.2A5.2 5.2 0 0 0 22 6.6V9.5Z',
    itch: 'M2 4.7C4.6 3 7 2 12 2s7.4 1 10 2.7c-.5 1.5-2 2.3-3.3 2.3-.7 0-1.5-.2-2-1-1.6 1.5-3.2 1.6-4.7 1.6-1.5 0-3-.1-4.7-1.6-.5.8-1.3 1-2 1C4 7 2.5 6.2 2 4.7ZM4 9h16v9c0 2-1 4-3 4h-2c-2 0-2-2-3-2H10c-1 0-1 2-3 2H5c-2 0-3-2-3-4V9h2Zm5.5 3v3l-2-1.5L9 16v-4H7.5Zm5 0v3l-2-1.5L14 16v-4h-1.5Z',
    github: 'M12 2C6.5 2 2 6.6 2 12.3 2 17 5 20.8 9 22c.5.1.7-.2.7-.5v-2c-2.8.6-3.4-1.2-3.4-1.2-.5-1.2-1.2-1.5-1.2-1.5-.9-.6.1-.6.1-.6 1 .1 1.5 1 1.5 1 .9 1.5 2.4 1.1 3 .8.1-.7.4-1.2.7-1.5-2.2-.3-4.5-1.1-4.5-5 0-1.1.4-2 1-2.7-.1-.3-.5-1.3.1-2.8 0 0 .9-.3 2.8 1a9.5 9.5 0 0 1 5 0c2-1.3 2.8-1 2.8-1 .6 1.5.2 2.5.1 2.8.7.7 1 1.6 1 2.7 0 3.9-2.3 4.7-4.6 5 .4.3.7.9.7 1.9v2.8c0 .3.2.6.7.5 4-1.3 7-5.1 7-9.8C22 6.6 17.5 2 12 2Z',
    patreon: 'M9 4h4.5C18 4 21 7.2 21 11s-3 6.8-7.5 6.8c-1.4 0-2.6-.3-3.5-.8V21H6V4h3Z',
    kofi: 'M22 8c0-2-1.6-4-4-4H4C2.6 4 2 4.6 2 6v9.3C2 18 4 20 6.7 20H14c2.4 0 4.4-1.6 4.9-4 1.7 0 3.1-1.4 3.1-3V8Zm-2 5c0 .6-.4 1-1 1V9c.6 0 1 .4 1 1v3Zm-9 0c-1.5 0-2.5-.7-3.5-1.7L7.7 10c.4.5 1 1 1.8 1 .8 0 1.5-.7 1.5-1.5 0-.4-.2-.7-.4-1 .4-.3.9-.5 1.4-.5 1.4 0 2.5 1.1 2.5 2.5 0 1.4-1.1 2.5-2.5 2.5Z',
    instagram: 'M12 2.2c3.2 0 3.6 0 4.8.1 1.2 0 1.8.3 2.2.4.6.2 1 .5 1.4.9.4.4.7.8.9 1.4.2.4.4 1 .4 2.2.1 1.2.1 1.6.1 4.8 0 3.2 0 3.6-.1 4.8 0 1.2-.3 1.8-.4 2.2-.2.6-.5 1-.9 1.4-.4.4-.8.7-1.4.9-.4.2-1 .4-2.2.4-1.2.1-1.6.1-4.8.1-3.2 0-3.6 0-4.8-.1-1.2 0-1.8-.3-2.2-.4-.6-.2-1-.5-1.4-.9-.4-.4-.7-.8-.9-1.4-.2-.4-.4-1-.4-2.2-.1-1.2-.1-1.6-.1-4.8 0-3.2 0-3.6.1-4.8 0-1.2.3-1.8.4-2.2.2-.6.5-1 .9-1.4.4-.4.8-.7 1.4-.9.4-.2 1-.4 2.2-.4 1.2-.1 1.6-.1 4.8-.1ZM12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10Zm0 1.8a3.2 3.2 0 1 1 0 6.4 3.2 3.2 0 0 1 0-6.4Zm6.4-2a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4Z',
    email: 'M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Zm17 3.4-8 5.3-8-5.3V18h16V8.4ZM20 7H4l8 5.3L20 7Z',
    rss: 'M5 5v3a13 13 0 0 1 13 13h3A16 16 0 0 0 5 5Zm0 6v3a7 7 0 0 1 7 7h3a10 10 0 0 0-10-10Zm1.5 6a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5Z',
    custom: 'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 1 0-5.6-5.6L11.5 7M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 1 0 5.6 5.6L12.5 17',
  };
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" width="100%" height="100%">
      <path d={path[platform] ?? path.custom} />
    </svg>
  );
}

type Slot = 'header' | 'footer';

export function SiteSocialFollow({ slot }: { slot: Slot }) {
  const { settings } = useSiteSettings();
  const social = settings.social;
  const show = slot === 'header' ? social.show_in_header : social.show_in_footer;
  if (!show || social.links.length === 0) return null;

  return (
    <nav
      className="site-social-follow"
      aria-label="Social media links"
      style={{ display: 'inline-flex', gap: 12, alignItems: 'center' }}
    >
      {social.links.map((l) => {
        const color =
          social.style === 'colour'
            ? (BRAND_COLOR[l.platform] ?? 'currentColor')
            : 'currentColor';
        return (
          <a
            key={l.id}
            href={l.url}
            target={l.url.startsWith('http') ? '_blank' : undefined}
            rel="noreferrer noopener"
            title={l.label || PLATFORM_LABEL[l.platform]}
            aria-label={l.label || PLATFORM_LABEL[l.platform]}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              width: social.style === 'text' ? 'auto' : social.size_px,
              height: social.style === 'text' ? 'auto' : social.size_px,
              color,
              textDecoration: 'none',
            }}
          >
            {social.style === 'text' ? l.label || PLATFORM_LABEL[l.platform] : <Icon platform={l.platform} />}
          </a>
        );
      })}
    </nav>
  );
}

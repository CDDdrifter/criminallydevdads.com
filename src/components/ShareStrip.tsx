/**
 * ShareStrip — "share this" buttons for game / custom-page detail screens.
 *
 * Reads `settings.sharing` for which networks to render. Each button opens
 * the network's share intent URL with the page title + URL pre-filled.
 */
import { useCallback, useMemo } from 'react';
import { useSiteSettings } from '../hooks/useSiteSettings';

type Props = {
  title: string;
  /** Override the URL (defaults to current location). */
  url?: string;
  /** Where to render — used so admins can scope it (games vs pages). */
  surface: 'game' | 'page';
};

export function ShareStrip({ title, url, surface }: Props) {
  const { settings } = useSiteSettings();
  const sharing = settings.sharing;
  const branding = settings.branding;

  const enabled =
    (surface === 'game' && sharing.show_on_games) ||
    (surface === 'page' && sharing.show_on_pages);

  const shareUrl = url ?? (typeof window !== 'undefined' ? window.location.href : '');
  const shareText = useMemo(() => {
    return (sharing.text_template || 'Check out {title} on {site}')
      .replace('{title}', title)
      .replace('{url}', shareUrl)
      .replace('{site}', branding.site_name || 'this site');
  }, [sharing.text_template, title, shareUrl, branding.site_name]);

  const onCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(shareUrl);
    } catch {
      window.prompt('Copy link:', shareUrl);
    }
  }, [shareUrl]);

  if (!enabled) return null;
  const enc = encodeURIComponent;

  return (
    <nav
      className="share-strip"
      aria-label="Share"
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: 8,
        margin: '16px 0',
        fontSize: '0.85rem',
      }}
    >
      <span className="admin-muted" style={{ alignSelf: 'center' }}>
        Share:
      </span>
      {sharing.twitter ? (
        <a
          href={`https://twitter.com/intent/tweet?text=${enc(shareText)}&url=${enc(shareUrl)}`}
          target="_blank"
          rel="noreferrer"
        >
          Twitter
        </a>
      ) : null}
      {sharing.reddit ? (
        <a
          href={`https://www.reddit.com/submit?title=${enc(title)}&url=${enc(shareUrl)}`}
          target="_blank"
          rel="noreferrer"
        >
          Reddit
        </a>
      ) : null}
      {sharing.bluesky ? (
        <a
          href={`https://bsky.app/intent/compose?text=${enc(`${shareText} ${shareUrl}`)}`}
          target="_blank"
          rel="noreferrer"
        >
          Bluesky
        </a>
      ) : null}
      {sharing.facebook ? (
        <a
          href={`https://www.facebook.com/sharer/sharer.php?u=${enc(shareUrl)}`}
          target="_blank"
          rel="noreferrer"
        >
          Facebook
        </a>
      ) : null}
      {sharing.hacker_news ? (
        <a
          href={`https://news.ycombinator.com/submitlink?u=${enc(shareUrl)}&t=${enc(title)}`}
          target="_blank"
          rel="noreferrer"
        >
          HN
        </a>
      ) : null}
      {sharing.email ? (
        <a href={`mailto:?subject=${enc(title)}&body=${enc(`${shareText}\n\n${shareUrl}`)}`}>
          Email
        </a>
      ) : null}
      {sharing.copy_link ? (
        <button
          type="button"
          onClick={onCopy}
          style={{
            background: 'transparent',
            border: '1px solid var(--border)',
            color: 'var(--text)',
            padding: '2px 8px',
            borderRadius: 6,
            cursor: 'pointer',
          }}
        >
          Copy link
        </button>
      ) : null}
    </nav>
  );
}

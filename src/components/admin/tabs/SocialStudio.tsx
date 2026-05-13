/**
 * SocialStudio — public social media links + per-page share buttons.
 *
 * `settings.social` is the bar of "follow us" icons we paint in the header /
 * footer. `settings.sharing` controls the "share this game / page" strip on
 * detail pages (Twitter/Reddit/Bluesky/HN/Email/Copy).
 */
import type { SiteSettings, SocialLink } from '../../../types';
import {
  FieldGroup,
  NumberSliderField,
  SelectField,
  TextField,
  ToggleField,
} from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

const PLATFORM_OPTIONS = [
  { value: 'discord', label: 'Discord' },
  { value: 'twitter', label: 'Twitter / X' },
  { value: 'bluesky', label: 'Bluesky' },
  { value: 'mastodon', label: 'Mastodon' },
  { value: 'youtube', label: 'YouTube' },
  { value: 'twitch', label: 'Twitch' },
  { value: 'tiktok', label: 'TikTok' },
  { value: 'itch', label: 'itch.io' },
  { value: 'github', label: 'GitHub' },
  { value: 'patreon', label: 'Patreon' },
  { value: 'kofi', label: 'Ko-fi' },
  { value: 'instagram', label: 'Instagram' },
  { value: 'email', label: 'Email (mailto:)' },
  { value: 'rss', label: 'RSS feed' },
  { value: 'custom', label: 'Custom (URL only)' },
] as const;

function uid() {
  return `s-${Math.random().toString(36).slice(2, 9)}`;
}

export function SocialStudio({ settings, setSettings }: Props) {
  const social = settings.social;
  const sharing = settings.sharing;
  const setSocial = (patch: Partial<typeof social>) =>
    setSettings({ ...settings, social: { ...social, ...patch } });
  const setSharing = (patch: Partial<typeof sharing>) =>
    setSettings({ ...settings, sharing: { ...sharing, ...patch } });

  const updateLink = (id: string, patch: Partial<SocialLink>) =>
    setSocial({
      links: social.links.map((l) => (l.id === id ? { ...l, ...patch } : l)),
    });
  const removeLink = (id: string) =>
    setSocial({ links: social.links.filter((l) => l.id !== id) });
  const addLink = () =>
    setSocial({
      links: [
        ...social.links,
        { id: uid(), platform: 'discord', url: '', label: '' },
      ],
    });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Where to render"
        tone="accent"
        description="Choose where the follow-bar appears. Header is great for prominent communities; footer is the standard place for socials."
      >
        <ToggleField
          label="Show in header (right of nav)"
          checked={social.show_in_header}
          onChange={(show_in_header) => setSocial({ show_in_header })}
        />
        <ToggleField
          label="Show in footer"
          checked={social.show_in_footer}
          onChange={(show_in_footer) => setSocial({ show_in_footer })}
        />
        <SelectField
          label="Icon style"
          value={social.style}
          options={[
            { value: 'monochrome', label: 'Monochrome (inherits accent colour)' },
            { value: 'colour', label: 'Brand colour per platform' },
            { value: 'text', label: 'Text label only' },
          ]}
          onChange={(v) => setSocial({ style: v as typeof social.style })}
        />
        <NumberSliderField
          label="Icon size (px)"
          value={social.size_px}
          min={14}
          max={48}
          step={1}
          onChange={(size_px) => setSocial({ size_px })}
        />
      </FieldGroup>

      <FieldGroup
        title="Social links"
        description="Add as many platforms as you want. Drag the list to reorder (coming soon)."
      >
        {social.links.length === 0 ? (
          <p className="admin-muted" style={{ fontSize: '0.85rem' }}>
            No links yet — click <strong>+ Add link</strong> below.
          </p>
        ) : null}
        {social.links.map((l, idx) => (
          <div
            key={l.id}
            className="admin-panel"
            style={{ borderStyle: 'dashed', padding: 12, display: 'grid', gap: 10 }}
          >
            <strong style={{ fontSize: '0.82rem', color: 'var(--muted)' }}>
              Link #{idx + 1}
            </strong>
            <SelectField
              label="Platform"
              value={l.platform}
              options={PLATFORM_OPTIONS.map((p) => ({ value: p.value, label: p.label }))}
              onChange={(platform) =>
                updateLink(l.id, { platform: platform as SocialLink['platform'] })
              }
            />
            <TextField
              label="URL"
              value={l.url}
              onChange={(url) => updateLink(l.id, { url })}
              placeholder={
                l.platform === 'email'
                  ? 'mailto:hello@example.com'
                  : l.platform === 'discord'
                    ? 'https://discord.gg/your-invite'
                    : 'https://…'
              }
            />
            <TextField
              label="Visible label (optional)"
              value={l.label}
              onChange={(label) => updateLink(l.id, { label })}
              placeholder="(defaults to platform name)"
            />
            <div>
              <button type="button" onClick={() => removeLink(l.id)}>
                Remove
              </button>
            </div>
          </div>
        ))}
        <div>
          <button type="button" onClick={addLink}>
            + Add link
          </button>
        </div>
      </FieldGroup>

      {/* ---------------------------- Sharing ----------------------------- */}
      <FieldGroup
        title="Share buttons"
        tone="accent"
        description="A strip of 'share this' buttons that appears on game / custom-page detail screens."
      >
        <ToggleField
          label="Show share strip on game pages"
          checked={sharing.show_on_games}
          onChange={(show_on_games) => setSharing({ show_on_games })}
        />
        <ToggleField
          label="Show share strip on custom pages"
          checked={sharing.show_on_pages}
          onChange={(show_on_pages) => setSharing({ show_on_pages })}
        />
        <ToggleField
          label="Twitter / X"
          checked={sharing.twitter}
          onChange={(twitter) => setSharing({ twitter })}
        />
        <ToggleField
          label="Reddit"
          checked={sharing.reddit}
          onChange={(reddit) => setSharing({ reddit })}
        />
        <ToggleField
          label="Bluesky"
          checked={sharing.bluesky}
          onChange={(bluesky) => setSharing({ bluesky })}
        />
        <ToggleField
          label="Facebook"
          checked={sharing.facebook}
          onChange={(facebook) => setSharing({ facebook })}
        />
        <ToggleField
          label="Hacker News"
          checked={sharing.hacker_news}
          onChange={(hacker_news) => setSharing({ hacker_news })}
        />
        <ToggleField
          label="Email"
          checked={sharing.email}
          onChange={(email) => setSharing({ email })}
        />
        <ToggleField
          label="Copy link"
          checked={sharing.copy_link}
          onChange={(copy_link) => setSharing({ copy_link })}
        />
        <TextField
          label="Share text template"
          value={sharing.text_template}
          onChange={(text_template) => setSharing({ text_template })}
          placeholder="Check out {title} on {site}"
          help="Tokens: {title}, {url}, {site}."
        />
      </FieldGroup>
    </div>
  );
}

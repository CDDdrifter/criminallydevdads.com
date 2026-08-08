/**
 * BehaviorStudio
 *
 * Feature flags, maintenance mode, default homepage filter, and small UX
 * niceties (click sound, autoplay previews, homepage intro HTML). Writes
 * into `SiteSettings.behavior`.
 */
import type { CSSProperties } from 'react';
import type { SiteSettings } from '../../../types';
import { defaultStripeBuyButtonPlacements } from '../../../lib/themeDefaults';
import {
  FieldGroup,
  NumberSliderField,
  SelectField,
  TextAreaField,
  TextField,
  ToggleField,
} from '../StudioFields';

type RouteVisibilityProps = {
  label: string;
  publicUrl: string;
  checked: boolean;
  onChange: (next: boolean) => void;
};

const pillStyle = (live: boolean): CSSProperties => ({
  display: 'inline-flex',
  alignItems: 'center',
  gap: 6,
  padding: '4px 10px',
  borderRadius: 999,
  fontSize: '0.72rem',
  fontWeight: 700,
  letterSpacing: '0.05em',
  textTransform: 'uppercase',
  background: live ? 'rgba(62, 207, 142, 0.18)' : 'rgba(255, 120, 120, 0.18)',
  color: live ? '#7be1b1' : '#ffb0b0',
  border: `1px solid ${live ? 'rgba(62, 207, 142, 0.55)' : 'rgba(255, 120, 120, 0.55)'}`,
});

function RouteVisibilityToggle({ label, publicUrl, checked, onChange }: RouteVisibilityProps) {
  return (
    <div
      className="admin-row"
      style={{
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 12,
        flexWrap: 'wrap',
        padding: '8px 0',
        borderBottom: '1px dashed rgba(115, 248, 255, 0.15)',
      }}
    >
      <label
        className="admin-row"
        style={{ alignItems: 'center', gap: 10, cursor: 'pointer', flex: '1 1 240px', minWidth: 0 }}
      >
        <input
          type="checkbox"
          checked={checked}
          onChange={(e) => onChange(e.target.checked)}
          style={{ width: 18, height: 18 }}
        />
        <span style={{ fontWeight: 600 }}>{label}</span>
        <code style={{ fontSize: '0.78rem', color: 'var(--muted)' }}>{publicUrl}</code>
      </label>
      <div className="admin-row" style={{ alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
        <span style={pillStyle(checked)}>{checked ? '● Live · public' : '● Hidden · admin only'}</span>
        <a
          href={publicUrl}
          target="_blank"
          rel="noopener noreferrer"
          style={{ fontSize: '0.78rem', color: 'var(--accent)' }}
        >
          Open in new tab ↗
        </a>
      </div>
    </div>
  );
}

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

export function BehaviorStudio({ settings, setSettings }: Props) {
  const b = settings.behavior;
  const buyPlacements = { ...defaultStripeBuyButtonPlacements(), ...b.stripe_buy_button_placements };
  const set = (patch: Partial<typeof b>) => setSettings({ ...settings, behavior: { ...b, ...patch } });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Maintenance mode"
        tone="danger"
        description={
          <>
            When enabled, every non-/admin route shows a maintenance card instead of the real page.
            Admin bypass keeps the studio reachable so you can disable it again.
          </>
        }
      >
        <ToggleField
          label="Enable maintenance mode"
          checked={b.maintenance_mode.enabled}
          onChange={(enabled) =>
            set({ maintenance_mode: { ...b.maintenance_mode, enabled } })
          }
          help="Hides all pages from public visitors."
        />
        <TextField
          label="Title"
          value={b.maintenance_mode.title}
          onChange={(title) => set({ maintenance_mode: { ...b.maintenance_mode, title } })}
          placeholder="We’ll be right back"
        />
        <TextAreaField
          label="Message"
          rows={4}
          value={b.maintenance_mode.message}
          onChange={(message) => set({ maintenance_mode: { ...b.maintenance_mode, message } })}
          help="Plain text. Newlines preserved."
        />
        <ToggleField
          label="Admins bypass maintenance"
          checked={b.maintenance_mode.allow_admin_bypass}
          onChange={(allow_admin_bypass) =>
            set({ maintenance_mode: { ...b.maintenance_mode, allow_admin_bypass } })
          }
          help="Recommended ON — without this you can lock yourself out."
        />
      </FieldGroup>

      <FieldGroup
        title="Site chrome — navigation placement"
        description={
          <>
            The hub used to always pin primary links at the top. These toggles give you full control: hide the top bar
            entirely, mirror the same links under the page, or strip the header brand strip. Use{' '}
            <strong>Pages → Page blocks → Add block → Buttons / CTA / Hero</strong> for buttons inside article content
            (not tied to the global nav).
          </>
        }
      >
        <ToggleField
          label="Show header brand strip (logo + tagline above nav)"
          checked={b.show_header_brand_strip}
          onChange={(show_header_brand_strip) => set({ show_header_brand_strip })}
          help="Turn off for a minimal chrome look; Brand studio fields stay saved for when you turn this back on."
        />
        <ToggleField
          label="Show primary navigation at the top"
          checked={b.show_primary_nav_header}
          onChange={(show_primary_nav_header) => set({ show_primary_nav_header })}
          help="When off, Home / Vault / Dev log / CMS nav links disappear from the top. Turn on “Footer nav” below so visitors can still move around."
        />
        <ToggleField
          label="Mirror primary navigation in the site footer (below page content)"
          checked={b.show_primary_nav_footer}
          onChange={(show_primary_nav_footer) => set({ show_primary_nav_footer })}
          help="Same link set as the top bar, rendered after the main page body. Social icons use the footer slot from Social + Sharing."
        />
        <ToggleField
          label="Show Home link in primary navigation"
          checked={b.show_home_nav_link}
          onChange={(show_home_nav_link) => set({ show_home_nav_link })}
          help="Applies to both top and footer nav rows when those rows are visible."
        />
        <ToggleField
          label="Show Apps lab link in primary navigation (/apps)"
          checked={b.show_apps_lab_link}
          onChange={(show_apps_lab_link) => set({ show_apps_lab_link })}
          help="Lists HTML-app pages that opt into the hub. Off by default — turn on when you publish sandboxed tools."
        />
        <ToggleField
          label="Show Services link in primary navigation (/services)"
          checked={b.show_services_link !== false}
          onChange={(show_services_link) => set({ show_services_link })}
          help="Gigs, tips, commissions — catalog from Admin → Services (migration 025)."
        />
      </FieldGroup>

      <FieldGroup
        title="Community — sign-in, comments, cloud saves"
        description={
          <>
            <strong>Any Google account</strong> can sign in as a visitor when the provider is on — there is no
            per-email allowlist for players (only the{' '}
            <strong>Admin / editor</strong> list in SQL: <code>site_admin_emails</code> /{' '}
            <code>site_admin_domains</code>). Enable Google under Supabase → Authentication → Providers. Under URL
            Configuration, set Site URL and add your exact deploy root to <strong>Redirect URLs</strong> (see{' '}
            <code>src/lib/authRedirect.ts</code>). If sign-in fails after redirect, check the error on the callback
            page — common fix is a trailing-slash mismatch; use <code>VITE_AUTH_REDIRECT_URL</code> to pin one URL.
          </>
        }
      >
        <ToggleField
          label="Allow public Google sign-in"
          checked={b.player_google_sign_in_enabled !== false}
          onChange={(player_google_sign_in_enabled) => set({ player_google_sign_in_enabled })}
          help="When off, hides Google OAuth for visitors. Editors may still use magic link if configured."
        />
        <ToggleField
          label="Show sign-in / account in header"
          checked={b.show_player_sign_in_nav !== false}
          onChange={(show_player_sign_in_nav) => set({ show_player_sign_in_nav })}
        />
        <ToggleField
          label="Enable comments site-wide"
          checked={b.comments_globally_enabled !== false}
          onChange={(comments_globally_enabled) => set({ comments_globally_enabled })}
          help="Turn off to hide all comment blocks until you are ready for public discussion."
        />
        <ToggleField
          label="First-party analytics (traffic, referrers, UTM tags)"
          checked={b.first_party_analytics_enabled !== false}
          onChange={(first_party_analytics_enabled) => set({ first_party_analytics_enabled })}
          help="Records page views, game plays, session ID, referrer, and marketing UTM params in Firestore. View under Admin → Analytics. Disclosed in Privacy Policy."
        />
        <ToggleField
          label="Show ad slot on public pages"
          checked={b.ads_enabled === true}
          onChange={(ads_enabled) => set({ ads_enabled })}
          help="Displays an ad banner above the legal footer. Add your Google AdSense publisher ID below, or paste ad scripts in SEO → Custom head."
        />
        <TextField
          label="Google AdSense client ID (optional)"
          value={b.adsense_client_id ?? ''}
          onChange={(adsense_client_id) => set({ adsense_client_id })}
          placeholder="ca-pub-XXXXXXXXXXXXXXXX"
          help="From AdSense → Account → Account information. The verification script is also in index.html for Google site review."
        />
      </FieldGroup>

      <FieldGroup
        title="Built-in pages — public visibility (page-down mode per route)"
        tone="accent"
        description={
          <>
            Each toggle is a kill switch for one entire hub section. <strong>Off</strong> = visitors see a short “section
            offline” card and the nav link disappears; <strong>signed-in admins still see the page</strong> with a yellow
            banner so you can keep editing. Save with the floating <em>Save site settings</em> bar at the bottom — these
            apply instantly across the whole site.
          </>
        }
      >
        <RouteVisibilityToggle
          label="Services page"
          publicUrl="/#/services"
          checked={b.enable_services_page !== false}
          onChange={(enable_services_page) => set({ enable_services_page })}
        />
        <RouteVisibilityToggle
          label="Apps lab"
          publicUrl="/#/apps"
          checked={b.enable_apps_hub_page !== false}
          onChange={(enable_apps_hub_page) => set({ enable_apps_hub_page })}
        />
        <RouteVisibilityToggle
          label="Vault (secret catalog)"
          publicUrl="/#/vault"
          checked={b.enable_vault_page !== false}
          onChange={(enable_vault_page) => set({ enable_vault_page })}
        />
        <RouteVisibilityToggle
          label="Dev log"
          publicUrl="/#/devlog"
          checked={b.enable_devlog_section !== false}
          onChange={(enable_devlog_section) => set({ enable_devlog_section })}
        />
      </FieldGroup>

      <FieldGroup
        title="Visibility — what shows on the homepage"
        description="Toggle whole sections off without deleting them."
      >
        <ToggleField label="Show Vault nav link" checked={b.show_vault_link} onChange={(show_vault_link) => set({ show_vault_link })} />
        <ToggleField label="Show Dev log nav link" checked={b.show_devlog_link} onChange={(show_devlog_link) => set({ show_devlog_link })} />
        <ToggleField label="Show filter buttons (ALL / GAMES / ASSETS)" checked={b.show_filter_buttons} onChange={(show_filter_buttons) => set({ show_filter_buttons })} />
        <ToggleField label="Show support / tips section" checked={b.show_support_section} onChange={(show_support_section) => set({ show_support_section })} />
        <ToggleField label="Show footer" checked={b.show_footer} onChange={(show_footer) => set({ show_footer })} />
        <ToggleField
          label="Show ‘Admin / Team login’ link in top nav"
          checked={b.show_admin_link_in_nav}
          onChange={(show_admin_link_in_nav) => set({ show_admin_link_in_nav })}
          help="Independent of the VITE_SHOW_ADMIN_NAV build flag — set either to show the link."
        />
      </FieldGroup>

      <FieldGroup
        title="Stripe buy button placement"
        description="Requires buy button ID + publishable key in Site copy. Applies on every public page wrapped in SiteChrome."
      >
        <ToggleField
          label="Top of every page (below header nav)"
          checked={buyPlacements.site_top}
          onChange={(site_top) =>
            set({
              stripe_buy_button_placements: { ...buyPlacements, site_top },
            })
          }
        />
        <ToggleField
          label="Bottom of every page (above footer nav)"
          checked={buyPlacements.site_bottom}
          onChange={(site_bottom) =>
            set({
              stripe_buy_button_placements: { ...buyPlacements, site_bottom },
            })
          }
        />
        <ToggleField
          label="Homepage support section"
          checked={buyPlacements.homepage_support}
          onChange={(homepage_support) =>
            set({
              stripe_buy_button_placements: { ...buyPlacements, homepage_support },
            })
          }
          help="The “Support the Devs” block at the bottom of the hub."
        />
      </FieldGroup>

      <FieldGroup title="Homepage filter + hover">
        <SelectField
          label="Default game filter on load"
          value={b.default_game_filter}
          onChange={(default_game_filter) => set({ default_game_filter })}
          options={[
            { value: 'all', label: 'All' },
            { value: 'game', label: 'Games only' },
            { value: 'asset', label: 'Assets only' },
          ]}
        />
        <SelectField
          label="Card hover effect"
          value={b.game_card_hover_effect}
          onChange={(game_card_hover_effect) => set({ game_card_hover_effect })}
          options={[
            { value: 'lift', label: 'Lift (default)' },
            { value: 'shine', label: 'Shine sweep' },
            { value: 'glow', label: 'Glow' },
            { value: 'tilt', label: 'Tilt' },
            { value: 'pulse', label: 'Pulse outline' },
            { value: 'none', label: 'No hover effect' },
          ]}
        />
        <ToggleField
          label="Auto-play game preview videos on the homepage"
          checked={b.homepage_autoplay_previews}
          onChange={(homepage_autoplay_previews) => set({ homepage_autoplay_previews })}
          help="Hover-only autoplay; videos still respect mute/preload on cellular networks."
        />
      </FieldGroup>

      <FieldGroup title="Homepage intro banner">
        <ToggleField label="Show banner above hero" checked={b.homepage_intro.enabled} onChange={(enabled) => set({ homepage_intro: { ...b.homepage_intro, enabled } })} />
        <TextAreaField
          label="Banner HTML (trusted)"
          rows={6}
          monospace
          value={b.homepage_intro.html}
          onChange={(html) => set({ homepage_intro: { ...b.homepage_intro, html } })}
          help="Rendered as raw HTML — keep it tight. Plain text + simple tags."
        />
      </FieldGroup>

      <FieldGroup title="Click sound (optional)" description="Plays a short MP3 / WAV when nav buttons are clicked.">
        <TextField
          label="Audio URL"
          value={b.click_sound_url}
          onChange={(click_sound_url) => set({ click_sound_url })}
          placeholder="https://… (MP3 / WAV / OGG)"
          help="Leave empty to disable."
        />
        <NumberSliderField
          label="Volume"
          min={0}
          max={1}
          step={0.05}
          value={b.click_sound_volume}
          onChange={(click_sound_volume) => set({ click_sound_volume })}
        />
      </FieldGroup>
    </div>
  );
}

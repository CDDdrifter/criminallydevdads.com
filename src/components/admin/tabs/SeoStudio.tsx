/**
 * SeoStudio
 *
 * SEO meta + analytics + favicon + custom <head> snippet. Writes into
 * `SiteSettings.seo` and `SiteSettings.custom_head_html`.
 *
 * Note: the SPA is a hash router, so search-engine SEO is limited at best.
 * These fields still help with social previews, browser theming, and
 * analytics adoption.
 */
import type { SiteSettings } from '../../../types';
import { BrandingAssetsGuide } from '../BrandingAssetsGuide';
import {
  AssetUploadField,
  ColorField,
  FieldGroup,
  SelectField,
  TextAreaField,
  TextField,
} from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

export function SeoStudio({ settings, setSettings }: Props) {
  const s = settings.seo;
  const set = (patch: Partial<typeof s>) => setSettings({ ...settings, seo: { ...s, ...patch } });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <BrandingAssetsGuide />

      <FieldGroup
        title="Page meta"
        tone="accent"
        description={
          <>
            Updates <code>&lt;title&gt;</code>, <code>meta description</code>, OpenGraph image, and
            the browser theme colour live.
          </>
        }
      >
        <TextField
          label="Title template"
          value={s.title_template}
          onChange={(title_template) => set({ title_template })}
          placeholder="%s — Criminally Dev Dads"
          help={<>Use <code>%s</code> as a placeholder for the page name. Affects social previews.</>}
        />
        <TextAreaField
          label="Default meta description"
          rows={3}
          value={s.default_meta_description}
          onChange={(default_meta_description) => set({ default_meta_description })}
          help="Shown by Google + Twitter + Discord when there’s no per-page override."
        />
        <AssetUploadField
          label="OpenGraph image URL"
          value={s.og_image_url}
          onChange={(og_image_url) => set({ og_image_url })}
          placeholder="https://…/og.png"
          help="1200×630 recommended."
        />
        <TextField
          label="Twitter handle"
          value={s.twitter_handle}
          onChange={(twitter_handle) => set({ twitter_handle })}
          placeholder="@criminallydevdads"
        />
        <AssetUploadField
          label="Favicon URL"
          value={s.favicon_url}
          onChange={(favicon_url) => set({ favicon_url })}
          placeholder="https://…/favicon.png"
          help="Browser tab icon (32×32 or 64×64 square). Leave empty to use /favicon.svg bundled with the site."
        />
        <AssetUploadField
          label="Apple touch icon URL"
          value={s.apple_touch_icon_url}
          onChange={(apple_touch_icon_url) => set({ apple_touch_icon_url })}
          placeholder="https://…/apple-touch-icon.png"
          help="180×180 for Add to Home Screen. Empty → favicon → bundled /apple-touch-icon.svg."
        />
        <ColorField
          label="Browser theme colour"
          value={s.theme_color}
          onChange={(theme_color) => set({ theme_color })}
          help="Mobile browsers tint the URL bar with this colour."
        />
      </FieldGroup>

      <FieldGroup
        title="Analytics"
        description={
          <>
            Optional analytics. The studio loads the provider script from this row at runtime so
            it deploys with the rest of the CMS — no rebuild needed.
          </>
        }
      >
        <SelectField
          label="Provider"
          value={s.analytics_provider}
          onChange={(analytics_provider) => set({ analytics_provider })}
          options={[
            { value: 'none', label: '— None —' },
            { value: 'plausible', label: 'Plausible' },
            { value: 'umami', label: 'Umami' },
            { value: 'ga4', label: 'Google Analytics 4' },
            { value: 'custom', label: 'Custom <script>' },
          ]}
        />
        {s.analytics_provider !== 'none' ? (
          <>
            <TextField
              label={
                s.analytics_provider === 'plausible'
                  ? 'Site domain (data-domain)'
                  : s.analytics_provider === 'umami'
                    ? 'Website ID (data-website-id)'
                    : s.analytics_provider === 'ga4'
                      ? 'Measurement ID (G-XXXXXXXXXX)'
                      : 'Optional data-id'
              }
              value={s.analytics_id}
              onChange={(analytics_id) => set({ analytics_id })}
            />
            <TextField
              label="Custom script src (optional)"
              value={s.analytics_script_src}
              onChange={(analytics_script_src) => set({ analytics_script_src })}
              monospace
              help={
                s.analytics_provider === 'custom'
                  ? 'Full URL of the JS to inject (e.g. self-hosted analytics).'
                  : 'Override the provider’s default CDN URL.'
              }
            />
          </>
        ) : null}
      </FieldGroup>

      <FieldGroup
        title="Custom <head> HTML"
        tone="danger"
        description={
          <>
            Injected verbatim into <code>&lt;head&gt;</code>. Trusted admin content — anything you
            paste runs in the page. Use this for things like Cloudflare beacons, pixel scripts, or
            preconnect hints.
          </>
        }
      >
        <TextAreaField
          label="HTML"
          rows={12}
          monospace
          value={settings.custom_head_html}
          onChange={(custom_head_html) => setSettings({ ...settings, custom_head_html })}
        />
      </FieldGroup>
    </div>
  );
}

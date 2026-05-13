/**
 * BrandHeroStudio
 *
 * Branding (site name, logo, footer) + hero block (logo, badge, CTA buttons,
 * scroll indicator). Combined into one tab because they always travel
 * together — the site name + logo appear in both the header chrome AND the
 * hero area.
 */
import type { HeroButton, SiteSettings } from '../../../types';
import {
  AssetUploadField,
  ColorField,
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

function uid() {
  return `btn-${Math.random().toString(36).slice(2, 9)}`;
}

export function BrandHeroStudio({ settings, setSettings }: Props) {
  const brand = settings.branding;
  const hero = settings.hero;

  const setBrand = (patch: Partial<typeof brand>) =>
    setSettings({ ...settings, branding: { ...brand, ...patch } });
  const setHero = (patch: Partial<typeof hero>) =>
    setSettings({ ...settings, hero: { ...hero, ...patch } });

  const updateButton = (id: string, patch: Partial<HeroButton>) => {
    setHero({
      buttons: hero.buttons.map((b) => (b.id === id ? { ...b, ...patch } : b)),
    });
  };
  const removeButton = (id: string) => {
    setHero({ buttons: hero.buttons.filter((b) => b.id !== id) });
  };
  const addButton = () => {
    setHero({
      buttons: [
        ...hero.buttons,
        { id: uid(), label: 'New CTA', href: '/vault', external: false, variant: 'primary' },
      ],
    });
  };

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      {/* ---------------------------- Branding ----------------------------- */}
      <FieldGroup
        title="Site identity"
        tone="accent"
        description="Used in the header, footer, and as the default title bar text."
      >
        <TextField
          label="Site name"
          value={brand.site_name}
          onChange={(v) => setBrand({ site_name: v })}
          placeholder="Criminally Dev Dads"
          help="Substitutes for `%s` in the SEO title template."
        />
        <TextField
          label="Header tagline"
          value={brand.header_tagline}
          onChange={(v) => setBrand({ header_tagline: v })}
          placeholder="Indie games + dev experiments"
        />
        <AssetUploadField
          label="Header logo URL"
          value={brand.header_logo_url}
          onChange={(v) => setBrand({ header_logo_url: v })}
          placeholder="https://… or /assets/logo.svg"
          help="If set, appears next to the site name in the top bar."
        />
        <NumberSliderField
          label="Header logo height (px)"
          value={brand.header_logo_height_px}
          min={16}
          max={120}
          step={1}
          onChange={(v) => setBrand({ header_logo_height_px: v })}
        />
      </FieldGroup>

      <FieldGroup title="Footer" description="Auto-copyright + watermark.">
        <ToggleField
          label="Show auto-copyright line"
          checked={brand.footer_show_auto_copyright}
          onChange={(footer_show_auto_copyright) => setBrand({ footer_show_auto_copyright })}
          help="Renders the template below with {year} → current year and {name} → site name."
        />
        <TextField
          label="Copyright template"
          value={brand.footer_copyright_template}
          onChange={(v) => setBrand({ footer_copyright_template: v })}
          placeholder="© {year} {name} — All rights reserved."
        />
        <TextField
          label="Watermark text"
          value={brand.watermark_text}
          onChange={(v) => setBrand({ watermark_text: v })}
          placeholder="(optional) e.g. v2.1 build 419"
          help="Small text painted at the bottom-right of every page."
        />
        <AssetUploadField
          label="Watermark image URL"
          value={brand.watermark_url}
          onChange={(v) => setBrand({ watermark_url: v })}
          placeholder="https://…"
        />
        <ToggleField
          label="Show 'Made with ❤' line"
          checked={brand.show_made_with}
          onChange={(show_made_with) => setBrand({ show_made_with })}
        />
      </FieldGroup>

      {/* ------------------------------ Hero ------------------------------- */}
      <FieldGroup
        title="Hero logo"
        tone="accent"
        description="Painted above the homepage title. Leave URL blank to keep the text-only hero."
      >
        <AssetUploadField
          label="Logo image URL"
          value={hero.logo_image_url}
          onChange={(v) => setHero({ logo_image_url: v })}
          placeholder="https://…"
        />
        <NumberSliderField
          label="Logo max height (px)"
          value={hero.logo_max_height_px}
          min={32}
          max={400}
          step={2}
          onChange={(v) => setHero({ logo_max_height_px: v })}
        />
        <ToggleField
          label="Show title text"
          checked={hero.show_title}
          onChange={(show_title) => setHero({ show_title })}
        />
        <ToggleField
          label="Show subtitle text"
          checked={hero.show_subtitle}
          onChange={(show_subtitle) => setHero({ show_subtitle })}
        />
        <TextField
          label="Extra tagline"
          value={hero.tagline}
          onChange={(v) => setHero({ tagline: v })}
          placeholder="(optional) shown under subtitle"
        />
      </FieldGroup>

      <FieldGroup
        title="Hero badge / ribbon"
        description="Small label sitting above the title (e.g. OPEN BETA, v2.0, NEW)."
      >
        <ToggleField
          label="Enable badge"
          checked={hero.badge.enabled}
          onChange={(enabled) => setHero({ badge: { ...hero.badge, enabled } })}
        />
        <TextField
          label="Badge text"
          value={hero.badge.text}
          onChange={(text) => setHero({ badge: { ...hero.badge, text } })}
        />
        <ColorField
          label="Badge background"
          value={hero.badge.bg}
          onChange={(bg) => setHero({ badge: { ...hero.badge, bg } })}
        />
        <ColorField
          label="Badge text colour"
          value={hero.badge.color}
          onChange={(color) => setHero({ badge: { ...hero.badge, color } })}
        />
      </FieldGroup>

      <FieldGroup
        title="Scroll indicator"
        description="Small bouncing arrow at the bottom of the hero."
      >
        <ToggleField
          label="Show scroll indicator"
          checked={hero.scroll_indicator.enabled}
          onChange={(enabled) =>
            setHero({ scroll_indicator: { ...hero.scroll_indicator, enabled } })
          }
        />
        <TextField
          label="Symbol"
          value={hero.scroll_indicator.emoji}
          onChange={(emoji) =>
            setHero({ scroll_indicator: { ...hero.scroll_indicator, emoji } })
          }
          placeholder="↓ ⌄ 🎮 …"
        />
        <ColorField
          label="Colour"
          value={hero.scroll_indicator.color}
          onChange={(color) =>
            setHero({ scroll_indicator: { ...hero.scroll_indicator, color } })
          }
        />
      </FieldGroup>

      {/* ----------------------------- CTA list ---------------------------- */}
      <FieldGroup
        title="Hero CTA buttons"
        description="Adds extra buttons under the hero (one or many). Each can be internal (e.g. /vault) or external (https://…)."
      >
        {hero.buttons.length === 0 ? (
          <p className="admin-muted" style={{ fontSize: '0.85rem' }}>
            No CTA buttons yet — click <strong>Add CTA</strong> below.
          </p>
        ) : null}
        {hero.buttons.map((b, idx) => (
          <div
            key={b.id}
            className="admin-panel"
            style={{ borderStyle: 'dashed', padding: 12, display: 'grid', gap: 10 }}
          >
            <strong style={{ fontSize: '0.82rem', color: 'var(--muted)' }}>
              Button #{idx + 1}
            </strong>
            <TextField
              label="Label"
              value={b.label}
              onChange={(label) => updateButton(b.id, { label })}
            />
            <TextField
              label="URL"
              value={b.href}
              onChange={(href) => updateButton(b.id, { href })}
              placeholder="/vault or https://…"
            />
            <ToggleField
              label="External link (opens in a new tab)"
              checked={b.external}
              onChange={(external) => updateButton(b.id, { external })}
            />
            <SelectField
              label="Style"
              value={b.variant}
              options={[
                { value: 'primary', label: 'Primary (accent)' },
                { value: 'secondary', label: 'Secondary (subtle)' },
                { value: 'ghost', label: 'Ghost (outline)' },
              ]}
              onChange={(variant) =>
                updateButton(b.id, { variant: variant as HeroButton['variant'] })
              }
            />
            <div>
              <button type="button" onClick={() => removeButton(b.id)}>
                Remove
              </button>
            </div>
          </div>
        ))}
        <div>
          <button type="button" onClick={addButton}>
            + Add CTA
          </button>
        </div>
      </FieldGroup>
    </div>
  );
}

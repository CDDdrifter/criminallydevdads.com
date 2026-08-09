/**
 * SystemStudio — performance + accessibility toggles.
 *
 * Kill-switches for FX that hurt low-end devices live here, together with
 * the accessibility passes (focus ring, font scaling, dyslexia font, high
 * contrast). These map directly to CSS rules emitted by `themeApply.ts`.
 */
import type { AccessibilityConfig, SiteSettings } from '../../../types';
import {
  getGitHubBranch,
  getGitHubToken,
  githubCmsConfigured,
  setGitHubBranch,
  setGitHubToken,
} from '../../../lib/githubCms';
import {
  ColorField,
  FieldGroup,
  NumberSliderField,
  SelectField,
  ToggleField,
} from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

export function SystemStudio({ settings, setSettings }: Props) {
  const p = settings.performance;
  const a = settings.accessibility;
  const setP = (patch: Partial<typeof p>) =>
    setSettings({ ...settings, performance: { ...p, ...patch } });
  const setA = (patch: Partial<AccessibilityConfig>) =>
    setSettings({ ...settings, accessibility: { ...a, ...patch } });

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <FieldGroup
        title="Performance"
        tone="accent"
        description="Turn off expensive effects when CPU/GPU is scarce. Useful for low-end laptops and mobile devices."
      >
        <ToggleField
          label="Disable ALL studio animations"
          checked={p.disable_all_animations}
          onChange={(disable_all_animations) => setP({ disable_all_animations })}
          help="Overrides every animation + transition with `none !important`."
        />
        <ToggleField
          label="Disable backdrop-filter blur"
          checked={p.disable_backdrop_filter}
          onChange={(disable_backdrop_filter) => setP({ disable_backdrop_filter })}
          help="Drops the frosted-glass blur on panels. Big GPU win on Safari."
        />
        <ToggleField
          label="Disable filter blur effects"
          checked={p.disable_blur_effects}
          onChange={(disable_blur_effects) => setP({ disable_blur_effects })}
        />
        <ToggleField
          label="Battery saver (dims hero FX)"
          checked={p.battery_saver}
          onChange={(battery_saver) => setP({ battery_saver })}
        />
        <ToggleField
          label="Lazy-load images"
          checked={p.image_lazy_load}
          onChange={(image_lazy_load) => setP({ image_lazy_load })}
        />
        <ToggleField
          label="Prefetch nav routes"
          checked={p.prefetch_nav}
          onChange={(prefetch_nav) => setP({ prefetch_nav })}
          help="Adds <link rel=prefetch> for every nav target so click→render feels instant."
        />
      </FieldGroup>

      <FieldGroup
        title="Accessibility"
        tone="accent"
        description="Settings here apply globally — they help keyboard, low-vision, and dyslexic users."
      >
        <ColorField
          label="Focus ring colour"
          value={a.focus_ring_color}
          onChange={(focus_ring_color) => setA({ focus_ring_color })}
        />
        <NumberSliderField
          label="Focus ring width (px)"
          value={a.focus_ring_width_px}
          min={1}
          max={8}
          step={1}
          onChange={(focus_ring_width_px) => setA({ focus_ring_width_px })}
        />
        <SelectField
          label="Focus ring style"
          value={a.focus_ring_style}
          options={[
            { value: 'solid', label: 'Solid' },
            { value: 'dashed', label: 'Dashed' },
            { value: 'double', label: 'Double' },
          ]}
          onChange={(v) => setA({ focus_ring_style: v as AccessibilityConfig['focus_ring_style'] })}
        />
        <NumberSliderField
          label="Font size scale"
          value={a.font_size_scale}
          min={0.75}
          max={1.5}
          step={0.05}
          onChange={(font_size_scale) => setA({ font_size_scale })}
          help="1.0 = default. Above 1 enlarges every rem-based font."
        />
        <ToggleField
          label="Dyslexia-friendly font"
          checked={a.dyslexia_friendly_font}
          onChange={(dyslexia_friendly_font) => setA({ dyslexia_friendly_font })}
          help="Loads Atkinson Hyperlegible from Google Fonts and applies it to body text."
        />
        <ToggleField
          label="Always underline links"
          checked={a.always_underline_links}
          onChange={(always_underline_links) => setA({ always_underline_links })}
        />
        <ToggleField
          label="High contrast pass"
          checked={a.high_contrast_mode}
          onChange={(high_contrast_mode) => setA({ high_contrast_mode })}
          help="Forces white text + black background + 2px borders. Overrides theme colours."
        />
        <ToggleField
          label="Show 'Skip to content' link for keyboards"
          checked={a.skip_link_enabled}
          onChange={(skip_link_enabled) => setA({ skip_link_enabled })}
        />
      </FieldGroup>

      <FieldGroup
        title="GitHub sync (optional backup)"
        tone="accent"
        description="CMS saves to Firebase when you are signed in at /admin. Covers and clips upload to Firebase Storage — no GitHub token needed. GitHub sync is optional for game ZIP builds and repo backup only."
      >
        <div className="admin-field">
          <label htmlFor="gh_pat">GitHub Personal Access Token</label>
          <input
            id="gh_pat"
            type="password"
            autoComplete="off"
            placeholder="ghp_…"
            defaultValue={getGitHubToken()}
            onChange={(e) => setGitHubToken(e.target.value)}
          />
          <p className="admin-muted" style={{ marginTop: 6, fontSize: '0.82rem' }}>
            Status:{' '}
            {githubCmsConfigured()
              ? '✓ Token saved (this browser) — optional: game ZIP uploads + repo backup'
              : 'Optional — only needed for game ZIP uploads to the repo'}
          </p>
        </div>
        <div className="admin-field">
          <label htmlFor="gh_branch">Target branch</label>
          <input
            id="gh_branch"
            type="text"
            defaultValue={getGitHubBranch()}
            onChange={(e) => setGitHubBranch(e.target.value)}
          />
        </div>
        <p className="admin-muted" style={{ fontSize: '0.82rem', lineHeight: 1.5 }}>
          Create token: GitHub → Settings → Developer settings → Personal access tokens → Generate (classic) → check{' '}
          <strong>repo</strong> scope. Optional — for uploading game ZIP builds to <code>games/</code> on this repo. Cover
          images use Firebase when you are signed in at /admin.
        </p>
      </FieldGroup>
    </div>
  );
}

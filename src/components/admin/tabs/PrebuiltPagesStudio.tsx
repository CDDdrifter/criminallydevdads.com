/**
 * PrebuiltPagesStudio — edit the four built-in hub routes that aren't CMS
 * pages: Services, Vault, Apps, and the Dev-log list. Each exposes an editable
 * header (eyebrow / heading / subtitle) plus block zones rendered ABOVE
 * (intro) and BELOW (outro) the built-in body, using the same block engine as
 * CMS pages. Writes into `site_settings.prebuilt_pages`; the floating save bar
 * persists the change.
 */
import { useState } from 'react';
import { PageSectionsForm } from '../PageSectionsForm';
import type { PrebuiltPageConfig, PrebuiltPageKey, SiteSettings } from '../../../types';
import { defaultPrebuiltPagesConfig } from '../../../types';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
  onNotify?: (msg: string) => void;
};

const ROUTES: { key: PrebuiltPageKey; label: string; url: string }[] = [
  { key: 'services', label: '💼 Services', url: '/#/services' },
  { key: 'vault', label: '🗄️ Vault', url: '/#/vault' },
  { key: 'apps', label: '⚡ Apps & tools', url: '/#/apps' },
  { key: 'devlog', label: '📝 Dev log', url: '/#/devlog' },
];

export function PrebuiltPagesStudio({ settings, setSettings, onNotify }: Props) {
  const [active, setActive] = useState<PrebuiltPageKey>('services');
  const all = settings.prebuilt_pages ?? defaultPrebuiltPagesConfig();
  const cfg = all[active];
  const route = ROUTES.find((r) => r.key === active)!;

  const patch = (p: Partial<PrebuiltPageConfig>) =>
    setSettings({
      ...settings,
      prebuilt_pages: { ...all, [active]: { ...cfg, ...p } },
    });

  return (
    <div className="admin-grid" style={{ gap: 20 }}>
      <div className="admin-panel">
        <h2 style={{ margin: '0 0 8px', fontSize: '1rem', color: 'var(--accent)' }}>🧱 Built-in pages</h2>
        <p className="admin-muted" style={{ marginTop: 0, fontSize: '0.88rem', lineHeight: 1.55 }}>
          Reshape the four built-in hub routes. Edit the header text and drop any block above (intro) or below
          (outro) the built-in catalog / grid / list. Requires migration{' '}
          <code>030_prebuilt_pages_devlog_sections.sql</code>. Save with the floating bar at the bottom.
        </p>
        <div className="admin-row" style={{ flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
          {ROUTES.map((r) => (
            <button
              key={r.key}
              type="button"
              onClick={() => setActive(r.key)}
              style={{
                fontWeight: active === r.key ? 700 : 400,
                borderColor: active === r.key ? 'var(--accent)' : undefined,
              }}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>

      <div className="admin-panel admin-grid">
        <div className="admin-row" style={{ justifyContent: 'space-between', gridColumn: '1 / -1' }}>
          <h3 style={{ margin: 0, fontSize: '0.9rem' }}>{route.label} header</h3>
          <a href={route.url} target="_blank" rel="noreferrer" className="admin-muted" style={{ fontSize: '0.8rem' }}>
            Open {route.url} ↗
          </a>
        </div>
        <div className="admin-field">
          <label>Eyebrow (small label)</label>
          <input value={cfg.eyebrow} onChange={(e) => patch({ eyebrow: e.target.value })} />
        </div>
        <div className="admin-field">
          <label>Heading</label>
          <input value={cfg.heading} onChange={(e) => patch({ heading: e.target.value })} />
        </div>
        <div className="admin-field" style={{ gridColumn: '1 / -1' }}>
          <label>Subtitle / lead</label>
          <textarea rows={2} value={cfg.subtitle} onChange={(e) => patch({ subtitle: e.target.value })} />
        </div>
      </div>

      <div className="admin-panel">
        <h3 style={{ margin: '0 0 4px', fontSize: '0.9rem' }}>Intro blocks (above the body)</h3>
        <p className="admin-muted" style={{ marginTop: 0, fontSize: '0.82rem' }}>
          Rendered between the header and the built-in catalog / grid / list.
        </p>
        <PageSectionsForm
          sections={cfg.intro_sections}
          onChange={(intro_sections) => patch({ intro_sections })}
          pageSlug={`prebuilt-${active}-intro`}
          mediaStorageFolder="prebuilt"
          onNotify={onNotify}
        />
      </div>

      <div className="admin-panel">
        <h3 style={{ margin: '0 0 4px', fontSize: '0.9rem' }}>Outro blocks (below the body)</h3>
        <p className="admin-muted" style={{ marginTop: 0, fontSize: '0.82rem' }}>
          Rendered after the built-in body — great for FAQs, CTAs, or fine print.
        </p>
        <PageSectionsForm
          sections={cfg.outro_sections}
          onChange={(outro_sections) => patch({ outro_sections })}
          pageSlug={`prebuilt-${active}-outro`}
          mediaStorageFolder="prebuilt"
          onNotify={onNotify}
        />
      </div>
    </div>
  );
}

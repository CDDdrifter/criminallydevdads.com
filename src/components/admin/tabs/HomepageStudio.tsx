/**
 * HomepageStudio
 *
 * Admin-driven homepage builder. Renders the universal `PageSectionsForm`
 * so the entire block library (hero, gallery, columns, CTA, tabs, FAQ,
 * pricing, team, game_grid, …) is available on the home page.
 *
 * Layout mode picker decides whether the admin blocks render below the
 * built-in hero + grid (default), above them, or instead of them — meaning
 * an admin can build a totally custom landing page without touching code.
 */
import type { SiteSettings } from '../../../types';
import { PageSectionsForm } from '../PageSectionsForm';
import { FieldGroup, SelectField } from '../StudioFields';

type Props = {
  settings: SiteSettings;
  setSettings: (next: SiteSettings) => void;
};

export function HomepageStudio({ settings, setSettings }: Props) {
  return (
    <div className="admin-grid" style={{ gap: 20 }}>
      <FieldGroup title="Layout">
        <p className="admin-muted" style={{ marginTop: 0 }}>
          Choose how your custom homepage blocks combine with the built-in
          hero, promo strip, and game grid. <strong>Replace</strong> hides
          everything default — the admin owns the page top to bottom.
        </p>
        <SelectField
          label="Layout mode"
          help="append = blocks below built-ins · prepend = blocks above · replace = only your blocks"
          value={settings.homepage_layout_mode}
          onChange={(v) =>
            setSettings({
              ...settings,
              homepage_layout_mode: v as 'append' | 'prepend' | 'replace',
            })
          }
          options={[
            { value: 'append', label: 'Append (below built-ins)' },
            { value: 'prepend', label: 'Prepend (above built-ins)' },
            { value: 'replace', label: 'Replace (only my blocks)' },
          ]}
        />
      </FieldGroup>

      <FieldGroup
        title="Blocks"
        description="Drop in any block — hero banners, image galleries, columns, tabs, FAQs, pricing tables, game grids, anything from the universal block library."
      >
        <PageSectionsForm
          sections={settings.homepage_sections ?? []}
          onChange={(homepage_sections) => setSettings({ ...settings, homepage_sections })}
          pageSlug="_homepage"
          mediaStorageFolder="homepage"
        />
      </FieldGroup>
    </div>
  );
}

import { VISUAL_PRESET_OPTIONS } from '../../lib/visualPresets';
import { ROUTE_FX_KEYS } from '../../lib/routeFx';
import type { FxIntensity, RouteFxOverride, RouteFxTriState } from '../../types';

type AppearanceFields = {
  visual_preset?: string | null;
  custom_mood_css?: string | null;
  immersive_layout?: boolean | null;
  route_fx?: RouteFxOverride | null;
};

type Props = {
  kind: 'game' | 'page';
  value: AppearanceFields;
  onChange: (patch: Partial<AppearanceFields>) => void;
  customCssError?: string;
  onClearCustomCssError?: () => void;
  onOpenEffectsTab?: () => void;
};

const FX_LABELS: Record<(typeof ROUTE_FX_KEYS)[number], string> = {
  scanlines: '📺 Scanlines',
  noise: '🌫️ Noise / grain',
  vignette: '🔲 Vignette',
  hue_shift: '🌈 Hue wash',
  cursor_spotlight: '✨ Cursor spotlight',
};

function TriSelect({
  label,
  value,
  onChange,
}: {
  label: string;
  value: RouteFxTriState;
  onChange: (v: RouteFxTriState) => void;
}) {
  return (
    <div className="admin-field">
      <label>{label}</label>
      <select value={value} onChange={(e) => onChange(e.target.value as RouteFxTriState)}>
        <option value="inherit">↩️ Inherit site</option>
        <option value="on">✅ On</option>
        <option value="off">⛔ Off</option>
      </select>
    </div>
  );
}

export function RouteAppearancePanel({
  kind,
  value,
  onChange,
  customCssError,
  onClearCustomCssError,
  onOpenEffectsTab,
}: Props) {
  const routeFx = value.route_fx ?? {};
  const setFx = (patch: Partial<RouteFxOverride>) =>
    onChange({ route_fx: { ...routeFx, ...patch } });

  return (
    <details className="admin-panel" open style={{ borderColor: 'rgba(166, 115, 255, 0.45)' }}>
      <summary style={{ cursor: 'pointer', fontWeight: 700, color: 'var(--accent)' }}>
        🎨 Appearance — this {kind} only
      </summary>
      <p className="admin-muted" style={{ margin: '12px 0', fontSize: '0.82rem', lineHeight: 1.55 }}>
        Global theme + FX live in <strong>⚡ Effects</strong> / <strong>🎨 Theme</strong> (one save for the whole site).
        Override mood, layout, and FX layers here for <strong>this {kind}</strong> only.
      </p>

      <div className="admin-field">
        <label htmlFor={`${kind}_visual_preset`}>Page mood</label>
        <select
          id={`${kind}_visual_preset`}
          value={value.visual_preset ?? ''}
          onChange={(e) => {
            onClearCustomCssError?.();
            onChange({ visual_preset: e.target.value });
          }}
        >
          {VISUAL_PRESET_OPTIONS.map((o) => (
            <option key={o.value || 'default'} value={o.value} title={o.hint}>
              {o.label}
              {o.value ? '' : ' — inherit hub mood'}
            </option>
          ))}
        </select>
      </div>

      <div className="admin-field">
        <label htmlFor={`${kind}_custom_mood_css`}>Custom mood CSS</label>
        <textarea
          id={`${kind}_custom_mood_css`}
          rows={6}
          value={value.custom_mood_css ?? ''}
          onChange={(e) => {
            onClearCustomCssError?.();
            onChange({ custom_mood_css: e.target.value });
          }}
          style={{
            width: '100%',
            fontFamily: 'ui-monospace, Consolas, monospace',
            fontSize: '0.82rem',
            lineHeight: 1.45,
          }}
        />
        {customCssError ? (
          <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
            <span aria-hidden>✗ </span>
            {customCssError}
          </p>
        ) : null}
      </div>

      <label className="admin-row" style={{ gap: 8, marginBottom: 12 }}>
        <input
          type="checkbox"
          checked={Boolean(value.immersive_layout)}
          onChange={(e) => onChange({ immersive_layout: e.target.checked })}
        />
        🌍 Immersive layout — wider frame, lighter chrome
      </label>

      <h4 style={{ fontSize: '0.8rem', textTransform: 'uppercase', color: 'var(--muted)', margin: '16px 0 8px' }}>
        FX layers (override site)
      </h4>
      <div className="admin-grid" style={{ gap: 10 }}>
        {ROUTE_FX_KEYS.map((key) => (
          <TriSelect
            key={key}
            label={FX_LABELS[key]}
            value={routeFx[key] ?? 'inherit'}
            onChange={(v) => setFx({ [key]: v })}
          />
        ))}
        <div className="admin-field">
          <label>FX intensity</label>
          <select
            value={routeFx.intensity ?? 'inherit'}
            onChange={(e) =>
              setFx({
                intensity: e.target.value as FxIntensity | 'inherit',
              })
            }
          >
            <option value="inherit">↩️ Inherit site</option>
            <option value="subtle">Subtle</option>
            <option value="normal">Normal</option>
            <option value="intense">Intense</option>
          </select>
        </div>
      </div>

      {onOpenEffectsTab ? (
        <p className="admin-muted" style={{ marginTop: 14, fontSize: '0.8rem' }}>
          Site-wide defaults:{' '}
          <button type="button" onClick={onOpenEffectsTab}>
            ⚡ Open Effects Studio
          </button>
        </p>
      ) : null}
    </details>
  );
}

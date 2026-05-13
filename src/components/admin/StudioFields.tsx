/**
 * StudioFields.tsx
 *
 * Reusable form widgets used by every Admin Studio tab. The studio writes a
 * lot of fields, so the shared building blocks here let each tab stay tiny
 * and readable instead of repeating the same wrapper markup.
 *
 * Widgets exported
 * -----------------
 *  - `ColorField`       — text input + native colour picker swatch + alpha
 *                         slider for rgba editing.
 *  - `NumberSliderField` — numeric input with a synced range slider and
 *                         min/max/step bounds.
 *  - `ToggleField`      — checkbox with inline label + help.
 *  - `SelectField`      — `<select>` with optional inline hint per option.
 *  - `TextField`        — small wrapper around `<input type="text">`.
 *  - `TextAreaField`    — `<textarea>` with monospace mode.
 *  - `FieldGroup`       — dashed inner panel with title + description.
 *  - `parseRgba`        — parse hex/rgb/rgba strings into `{r,g,b,a}`.
 *  - `formatRgba`       — render `{r,g,b,a}` as canonical `rgba(...)` text.
 *
 * Every widget is unstyled beyond the existing `.admin-field` and
 * `.admin-panel` classes from `index.css`, so the studio inherits site
 * theming automatically.
 */
import type { ChangeEvent, ReactNode } from 'react';
import { useCallback, useId, useMemo } from 'react';

// ---------------------------------------------------------------------------
// Field group — dashed panel used by every studio section.
// ---------------------------------------------------------------------------
export function FieldGroup({
  title,
  description,
  children,
  tone = 'normal',
}: {
  title: string;
  description?: ReactNode;
  children: ReactNode;
  tone?: 'normal' | 'accent' | 'danger';
}) {
  const border =
    tone === 'accent'
      ? 'rgba(115, 248, 255, 0.5)'
      : tone === 'danger'
        ? 'var(--danger)'
        : 'var(--border)';
  return (
    <div className="admin-panel" style={{ borderStyle: 'dashed', borderColor: border }}>
      <h3
        style={{
          fontSize: '0.85rem',
          textTransform: 'uppercase',
          color: 'var(--muted)',
          marginBottom: 8,
          letterSpacing: '0.06em',
        }}
      >
        {title}
      </h3>
      {description ? (
        <p
          className="admin-muted"
          style={{ marginTop: 0, marginBottom: 12, fontSize: '0.82rem', lineHeight: 1.55 }}
        >
          {description}
        </p>
      ) : null}
      <div className="admin-grid" style={{ gap: 12 }}>
        {children}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Colour parsing helpers.
//
// We support three input formats users (and our presets) commonly use:
//   - #rrggbb      / #rrggbbaa
//   - rgb(r,g,b)
//   - rgba(r,g,b,a)
// CSS named colours and `hsla()` pass through untouched (the `<input
// type=color>` simply won't change them, but the text input still works).
// ---------------------------------------------------------------------------
export type Rgba = { r: number; g: number; b: number; a: number };

const HEX_RE = /^#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i;

function clamp(n: number, lo: number, hi: number): number {
  if (!Number.isFinite(n)) return lo;
  return Math.max(lo, Math.min(hi, n));
}

export function parseRgba(value: string): Rgba | null {
  const s = (value ?? '').trim();
  if (!s) return null;
  if (HEX_RE.test(s)) {
    const hex = s.replace('#', '');
    if (hex.length === 3) {
      const r = parseInt(`${hex[0]}${hex[0]}`, 16);
      const g = parseInt(`${hex[1]}${hex[1]}`, 16);
      const b = parseInt(`${hex[2]}${hex[2]}`, 16);
      return { r, g, b, a: 1 };
    }
    if (hex.length === 6 || hex.length === 8) {
      const r = parseInt(hex.substring(0, 2), 16);
      const g = parseInt(hex.substring(2, 4), 16);
      const b = parseInt(hex.substring(4, 6), 16);
      const a = hex.length === 8 ? parseInt(hex.substring(6, 8), 16) / 255 : 1;
      return { r, g, b, a };
    }
  }
  const m = s.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+))?\s*\)$/i);
  if (m) {
    return {
      r: clamp(parseFloat(m[1] ?? '0'), 0, 255),
      g: clamp(parseFloat(m[2] ?? '0'), 0, 255),
      b: clamp(parseFloat(m[3] ?? '0'), 0, 255),
      a: m[4] === undefined ? 1 : clamp(parseFloat(m[4]), 0, 1),
    };
  }
  return null;
}

export function formatRgba(c: Rgba): string {
  const r = Math.round(c.r);
  const g = Math.round(c.g);
  const b = Math.round(c.b);
  if (c.a >= 0.999) return `rgb(${r}, ${g}, ${b})`;
  return `rgba(${r}, ${g}, ${b}, ${Number(c.a.toFixed(3))})`;
}

/** Force a value into `#rrggbb` for `<input type=color>` (which can't show alpha). */
function toHex(c: Rgba): string {
  const h = (n: number) => clamp(Math.round(n), 0, 255).toString(16).padStart(2, '0');
  return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
}

// ---------------------------------------------------------------------------
// ColorField — text input + native picker + alpha slider.
// ---------------------------------------------------------------------------
export function ColorField({
  label,
  value,
  onChange,
  help,
  presets,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  help?: ReactNode;
  /** Optional quick-pick palette shown as 16x16 swatches under the input. */
  presets?: string[];
}) {
  const id = useId();
  const rgba = useMemo(() => parseRgba(value), [value]);
  const onPicker = useCallback(
    (e: ChangeEvent<HTMLInputElement>) => {
      const hex = parseRgba(e.target.value);
      if (!hex) return;
      const a = rgba?.a ?? 1;
      onChange(formatRgba({ ...hex, a }));
    },
    [onChange, rgba?.a],
  );
  const onAlpha = useCallback(
    (e: ChangeEvent<HTMLInputElement>) => {
      const a = Math.max(0, Math.min(1, parseFloat(e.target.value)));
      const base = rgba ?? { r: 255, g: 255, b: 255, a: 1 };
      onChange(formatRgba({ ...base, a }));
    },
    [onChange, rgba],
  );
  const pickerHex = rgba ? toHex(rgba) : '#000000';
  return (
    <div className="admin-field">
      <label htmlFor={id}>{label}</label>
      <div className="admin-row" style={{ gap: 8, alignItems: 'center' }}>
        <input
          type="color"
          aria-label={`${label} — colour picker`}
          value={pickerHex}
          onChange={onPicker}
          style={{
            width: 44,
            height: 36,
            padding: 0,
            background: 'transparent',
            border: '1px solid var(--border)',
            borderRadius: 4,
            cursor: 'pointer',
          }}
        />
        <input
          id={id}
          value={value ?? ''}
          onChange={(e) => onChange(e.target.value)}
          style={{ flex: 1, fontFamily: 'ui-monospace, Consolas, monospace', fontSize: '0.85rem' }}
        />
      </div>
      <div className="admin-row" style={{ marginTop: 6, alignItems: 'center', gap: 8 }}>
        <span className="admin-muted" style={{ fontSize: '0.72rem', minWidth: 28 }}>
          α {rgba ? rgba.a.toFixed(2) : '—'}
        </span>
        <input
          type="range"
          min={0}
          max={1}
          step={0.01}
          aria-label={`${label} — alpha`}
          value={rgba?.a ?? 1}
          onChange={onAlpha}
          style={{ flex: 1 }}
        />
        <span
          aria-hidden
          style={{
            width: 36,
            height: 22,
            borderRadius: 4,
            border: '1px solid var(--border)',
            background: value || 'transparent',
          }}
        />
      </div>
      {presets && presets.length > 0 ? (
        <div className="admin-row" style={{ marginTop: 6, flexWrap: 'wrap', gap: 4 }}>
          {presets.map((p) => (
            <button
              key={p}
              type="button"
              title={p}
              aria-label={`Set to ${p}`}
              onClick={() => onChange(p)}
              style={{
                width: 22,
                height: 22,
                borderRadius: 4,
                padding: 0,
                border: '1px solid var(--border)',
                background: p,
                cursor: 'pointer',
              }}
            />
          ))}
        </div>
      ) : null}
      {help ? (
        <p className="admin-muted" style={{ marginTop: 6, fontSize: '0.78rem', lineHeight: 1.4 }}>
          {help}
        </p>
      ) : null}
    </div>
  );
}

// ---------------------------------------------------------------------------
// NumberSliderField — number input + range slider.
// ---------------------------------------------------------------------------
export function NumberSliderField({
  label,
  value,
  onChange,
  min,
  max,
  step = 1,
  unit,
  help,
}: {
  label: string;
  value: number;
  onChange: (n: number) => void;
  min: number;
  max: number;
  step?: number;
  unit?: string;
  help?: ReactNode;
}) {
  const id = useId();
  return (
    <div className="admin-field">
      <label htmlFor={id}>
        {label}
        {unit ? <span className="admin-muted"> ({unit})</span> : null}
      </label>
      <div className="admin-row" style={{ gap: 10, alignItems: 'center' }}>
        <input
          type="range"
          min={min}
          max={max}
          step={step}
          value={Number.isFinite(value) ? value : min}
          onChange={(e) => onChange(parseFloat(e.target.value))}
          style={{ flex: 1 }}
          aria-label={`${label} — slider`}
        />
        <input
          id={id}
          type="number"
          min={min}
          max={max}
          step={step}
          value={Number.isFinite(value) ? value : ''}
          onChange={(e) => {
            const n = parseFloat(e.target.value);
            onChange(Number.isFinite(n) ? n : min);
          }}
          style={{ width: 88 }}
        />
      </div>
      {help ? (
        <p className="admin-muted" style={{ marginTop: 4, fontSize: '0.78rem' }}>{help}</p>
      ) : null}
    </div>
  );
}

// ---------------------------------------------------------------------------
// ToggleField — labelled checkbox.
// ---------------------------------------------------------------------------
export function ToggleField({
  label,
  checked,
  onChange,
  help,
}: {
  label: ReactNode;
  checked: boolean;
  onChange: (v: boolean) => void;
  help?: ReactNode;
}) {
  return (
    <div className="admin-field">
      <label className="admin-row" style={{ gap: 8, alignItems: 'center' }}>
        <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
        <span>{label}</span>
      </label>
      {help ? (
        <p className="admin-muted" style={{ marginLeft: 24, marginTop: 2, fontSize: '0.78rem' }}>
          {help}
        </p>
      ) : null}
    </div>
  );
}

// ---------------------------------------------------------------------------
// SelectField — drop-down with option labels + optional inline hint per option.
// ---------------------------------------------------------------------------
export function SelectField<T extends string>({
  label,
  value,
  onChange,
  options,
  help,
}: {
  label: string;
  value: T;
  onChange: (v: T) => void;
  options: { value: T; label: string; hint?: string }[];
  help?: ReactNode;
}) {
  const id = useId();
  return (
    <div className="admin-field">
      <label htmlFor={id}>{label}</label>
      <select id={id} value={value} onChange={(e) => onChange(e.target.value as T)}>
        {options.map((o) => (
          <option key={o.value} value={o.value} title={o.hint}>
            {o.label}
          </option>
        ))}
      </select>
      {help ? (
        <p className="admin-muted" style={{ marginTop: 6, fontSize: '0.78rem' }}>{help}</p>
      ) : null}
    </div>
  );
}

// ---------------------------------------------------------------------------
// TextField / TextAreaField — small wrappers so studio tabs stay declarative.
// ---------------------------------------------------------------------------
export function TextField({
  label,
  value,
  onChange,
  placeholder,
  help,
  monospace,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  help?: ReactNode;
  monospace?: boolean;
}) {
  const id = useId();
  return (
    <div className="admin-field">
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        value={value ?? ''}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        style={monospace ? { fontFamily: 'ui-monospace, Consolas, monospace', fontSize: '0.85rem' } : undefined}
      />
      {help ? (
        <p className="admin-muted" style={{ marginTop: 6, fontSize: '0.78rem' }}>{help}</p>
      ) : null}
    </div>
  );
}

export function TextAreaField({
  label,
  value,
  onChange,
  rows = 6,
  help,
  monospace,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  rows?: number;
  help?: ReactNode;
  monospace?: boolean;
}) {
  const id = useId();
  return (
    <div className="admin-field">
      <label htmlFor={id}>{label}</label>
      <textarea
        id={id}
        rows={rows}
        value={value ?? ''}
        onChange={(e) => onChange(e.target.value)}
        style={monospace ? { fontFamily: 'ui-monospace, Consolas, monospace', fontSize: '0.82rem', lineHeight: 1.45 } : undefined}
      />
      {help ? (
        <p className="admin-muted" style={{ marginTop: 6, fontSize: '0.78rem' }}>{help}</p>
      ) : null}
    </div>
  );
}

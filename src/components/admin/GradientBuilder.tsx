/**
 * GradientBuilder.tsx
 *
 * Visual editor for the Admin Studio's `Gradient` type. Lets admins:
 *   - switch between linear / radial / conic
 *   - tune angle (linear / conic) and size+position (radial)
 *   - add / remove / reorder colour stops
 *   - drag stops along a 0–100 range slider
 *   - paste a CSS gradient string and parse it back into a `Gradient`
 *   - preview the result against the live theme accents.
 *
 * Pure component — the parent owns the `Gradient` state and provides
 * `onChange`. Used by ThemeStudio for the body background gradient and
 * (eventually) reusable for any other gradient field.
 */
import { useId, useMemo } from 'react';
import type { Gradient, GradientStop } from '../../types';
import { ColorField, NumberSliderField, SelectField, TextField } from './StudioFields';
import { previewGradientCss } from '../../lib/themeApply';

function uid(): string {
  return Math.random().toString(36).slice(2, 9);
}

function defaultStop(): GradientStop {
  return { id: uid(), color: '#ffffff', position: 50 };
}

function reorder<T>(arr: T[], from: number, to: number): T[] {
  if (from === to) return arr;
  const next = arr.slice();
  const removed = next.splice(from, 1);
  if (removed.length === 0) return arr;
  next.splice(to, 0, removed[0] as T);
  return next;
}

export function GradientBuilder({
  label,
  value,
  onChange,
  description,
}: {
  label: string;
  value: Gradient;
  onChange: (g: Gradient) => void;
  description?: string;
}) {
  const stops = value.stops ?? [];
  const previewId = useId();

  const previewBg = useMemo(() => previewGradientCss(value), [value]);

  return (
    <div className="admin-panel" style={{ borderStyle: 'dashed' }}>
      <h3
        style={{
          fontSize: '0.85rem',
          textTransform: 'uppercase',
          color: 'var(--muted)',
          marginBottom: 8,
          letterSpacing: '0.06em',
        }}
      >
        {label}
      </h3>
      {description ? (
        <p
          className="admin-muted"
          style={{ marginTop: 0, marginBottom: 12, fontSize: '0.82rem', lineHeight: 1.55 }}
        >
          {description}
        </p>
      ) : null}

      {/* Live preview ------------------------------------------------------ */}
      <div
        id={previewId}
        aria-label={`${label} preview`}
        style={{
          height: 80,
          borderRadius: 6,
          border: '1px solid var(--border)',
          background: previewBg,
          marginBottom: 12,
        }}
      />

      {/* Gradient type + axis controls ------------------------------------ */}
      <SelectField
        label="Gradient type"
        value={value.type}
        onChange={(t) => onChange({ ...value, type: t })}
        options={[
          { value: 'linear', label: 'Linear' },
          { value: 'radial', label: 'Radial' },
          { value: 'conic', label: 'Conic' },
        ]}
      />
      {value.type === 'linear' || value.type === 'conic' ? (
        <NumberSliderField
          label={value.type === 'linear' ? 'Angle' : 'Start angle'}
          unit="deg"
          min={0}
          max={360}
          step={1}
          value={value.angle ?? 130}
          onChange={(angle) => onChange({ ...value, angle })}
        />
      ) : null}
      {value.type === 'radial' ? (
        <>
          <TextField
            label="Size"
            value={value.size ?? '800px 600px'}
            onChange={(size) => onChange({ ...value, size })}
            placeholder="800px 600px"
            help={<>e.g. <code>800px 600px</code>, <code>40% 60%</code>, <code>closest-side</code>.</>}
            monospace
          />
          <TextField
            label="Position"
            value={value.position ?? 'center'}
            onChange={(position) => onChange({ ...value, position })}
            placeholder="85% 10%"
            help={<>CSS background-position. e.g. <code>85% 10%</code>, <code>center</code>, <code>top right</code>.</>}
            monospace
          />
        </>
      ) : null}
      {value.type === 'conic' ? (
        <TextField
          label="Position"
          value={value.position ?? 'center'}
          onChange={(position) => onChange({ ...value, position })}
          placeholder="center"
          monospace
        />
      ) : null}

      {/* Stops ------------------------------------------------------------ */}
      <div style={{ marginTop: 12 }}>
        <h4 style={{ fontSize: '0.78rem', textTransform: 'uppercase', color: 'var(--muted)', marginBottom: 6 }}>
          Colour stops
        </h4>
        {stops.map((s, i) => (
          <div key={s.id} className="admin-panel" style={{ marginBottom: 8, padding: 10 }}>
            <div className="admin-row" style={{ justifyContent: 'space-between', marginBottom: 6 }}>
              <strong style={{ fontSize: '0.78rem' }}>Stop {i + 1}</strong>
              <span className="admin-row">
                <button
                  type="button"
                  disabled={i === 0}
                  onClick={() => onChange({ ...value, stops: reorder(stops, i, i - 1) })}
                >
                  Up
                </button>
                <button
                  type="button"
                  disabled={i === stops.length - 1}
                  onClick={() => onChange({ ...value, stops: reorder(stops, i, i + 1) })}
                >
                  Down
                </button>
                <button
                  type="button"
                  disabled={stops.length <= 2}
                  onClick={() => onChange({ ...value, stops: stops.filter((_, idx) => idx !== i) })}
                >
                  Remove
                </button>
              </span>
            </div>
            <ColorField
              label="Colour"
              value={s.color}
              onChange={(color) =>
                onChange({
                  ...value,
                  stops: stops.map((x, idx) => (idx === i ? { ...x, color } : x)),
                })
              }
            />
            <NumberSliderField
              label="Position"
              unit="%"
              min={0}
              max={100}
              step={1}
              value={s.position}
              onChange={(position) =>
                onChange({
                  ...value,
                  stops: stops.map((x, idx) => (idx === i ? { ...x, position } : x)),
                })
              }
            />
          </div>
        ))}
        <button type="button" onClick={() => onChange({ ...value, stops: [...stops, defaultStop()] })}>
          Add colour stop
        </button>
      </div>
    </div>
  );
}

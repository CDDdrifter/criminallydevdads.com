import type { CSSProperties } from 'react';

type SaveStatus = 'idle' | 'success' | 'error';

type Props = {
  visible: boolean;
  busy: boolean;
  dirty: boolean;
  status: SaveStatus;
  detail?: string | null;
  onSave: () => void;
  onDiscard?: () => void;
};

const wrapStyle: CSSProperties = {
  position: 'fixed',
  left: '50%',
  bottom: 18,
  transform: 'translateX(-50%)',
  zIndex: 70,
  maxWidth: 720,
  width: 'min(92vw, 720px)',
  display: 'flex',
  alignItems: 'center',
  gap: 14,
  padding: '12px 16px',
  borderRadius: 14,
  border: '1px solid rgba(115, 248, 255, 0.55)',
  background: 'rgba(8, 12, 22, 0.96)',
  boxShadow: '0 18px 52px rgba(0, 0, 0, 0.55), 0 0 0 1px rgba(166, 115, 255, 0.18)',
  backdropFilter: 'blur(8px)',
  flexWrap: 'wrap',
};

const labelStyle: CSSProperties = {
  flex: '1 1 auto',
  minWidth: 0,
  fontSize: '0.86rem',
  lineHeight: 1.4,
  color: 'var(--text)',
};

const dotStyle = (color: string): CSSProperties => ({
  display: 'inline-block',
  width: 8,
  height: 8,
  borderRadius: 999,
  background: color,
  marginRight: 8,
  verticalAlign: 'middle',
});

const saveBtn: CSSProperties = {
  flex: '0 0 auto',
  padding: '10px 18px',
  fontSize: '0.85rem',
  fontWeight: 700,
  letterSpacing: '0.04em',
  textTransform: 'uppercase',
  borderRadius: 10,
  border: '1px solid rgba(62, 207, 142, 0.7)',
  background: 'rgba(62, 207, 142, 0.18)',
  color: '#defff0',
  cursor: 'pointer',
};

const discardBtn: CSSProperties = {
  flex: '0 0 auto',
  padding: '10px 14px',
  fontSize: '0.78rem',
  borderRadius: 10,
  border: '1px solid rgba(255, 120, 120, 0.45)',
  background: 'transparent',
  color: '#ffd6d6',
  cursor: 'pointer',
};

export function FloatingSettingsSaveBar({
  visible,
  busy,
  dirty,
  status,
  detail,
  onSave,
  onDiscard,
}: Props) {
  if (!visible) return null;

  const message = (() => {
    if (busy) return 'Saving site settings…';
    if (status === 'error') return detail ?? 'Save failed — check the field error above.';
    if (dirty) return 'Unsaved changes — anything you edit lives here until you save.';
    if (status === 'success') return 'Saved — live site updated.';
    return 'No changes to save.';
  })();

  const dotColor = busy
    ? '#73f8ff'
    : status === 'error'
      ? 'var(--danger)'
      : dirty
        ? '#ffbf5f'
        : '#3ecf8e';

  return (
    <div role="status" aria-live="polite" style={wrapStyle}>
      <span style={labelStyle}>
        <span style={dotStyle(dotColor)} aria-hidden />
        {message}
      </span>
      {dirty && onDiscard ? (
        <button type="button" onClick={onDiscard} disabled={busy} style={discardBtn}>
          Discard
        </button>
      ) : null}
      <button
        type="button"
        onClick={onSave}
        disabled={busy || (!dirty && status !== 'error')}
        style={{
          ...saveBtn,
          opacity: busy || (!dirty && status !== 'error') ? 0.55 : 1,
        }}
      >
        {busy ? 'Saving…' : dirty || status === 'error' ? 'Save site settings' : 'Saved'}
      </button>
    </div>
  );
}

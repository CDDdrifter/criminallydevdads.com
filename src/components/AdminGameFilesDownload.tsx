import { useState } from 'react';
import { downloadPostedGameFiles, postedGameFolder } from '../lib/downloadPostedGameFiles';

type Props = {
  localFolder: string;
  launchPath?: string;
  title?: string;
};

export function AdminGameFilesDownload({ localFolder, launchPath = '', title }: Props) {
  const folder = postedGameFolder(localFolder, launchPath);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);

  if (!folder) {
    return null;
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <button
        type="button"
        className="btn-download"
        disabled={busy}
        onClick={() => {
          setBusy(true);
          setNote('Packing game files…');
          void downloadPostedGameFiles({
            folder,
            title,
            onProgress: (done, total, name) => {
              setNote(`Packing ${done}/${total}: ${name}`);
            },
          })
            .then((r) => {
              const extra = r.skipped.length ? ` (skipped missing: ${r.skipped.join(', ')})` : '';
              setNote(`Downloaded ${r.fileCount} files from games/${folder}/${extra}`);
            })
            .catch((e: unknown) => {
              setNote(e instanceof Error ? e.message : 'Download failed');
            })
            .finally(() => setBusy(false));
        }}
      >
        {busy ? 'Preparing zip…' : 'Download posted files'}
      </button>
      {note ? (
        <p className="admin-muted" style={{ margin: 0, fontSize: '0.78rem', lineHeight: 1.45 }}>
          {note}
        </p>
      ) : (
        <p className="admin-muted" style={{ margin: 0, fontSize: '0.78rem', lineHeight: 1.45 }}>
          Admin: zip of <code>games/{folder}/</code> as served on the site (Godot HTML5 + PWA).
        </p>
      )}
    </div>
  );
}

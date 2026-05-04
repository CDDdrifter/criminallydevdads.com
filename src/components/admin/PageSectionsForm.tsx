import { useState } from 'react';
import type { PageSection } from '../../types';
import { createEmptySection, newSectionId } from '../../lib/pageSections';
import { uploadPageSectionImage, uploadPageSectionVideo } from '../../lib/gameStorageUpload';

function updateSectionAt(
  sections: PageSection[],
  index: number,
  patch: Record<string, unknown>,
): PageSection[] {
  const next = [...sections];
  const cur = next[index];
  if (!cur) {
    return sections;
  }
  next[index] = { ...cur, ...patch } as PageSection;
  return next;
}

export function PageSectionsForm({
  sections,
  onChange,
  pageSlug = '',
  formDisabled = false,
  onNotify,
}: {
  sections: PageSection[];
  onChange: (s: PageSection[]) => void;
  /** Required before media upload — path uses <code>pages/&lt;slug&gt;/…</code> in Storage. */
  pageSlug?: string;
  formDisabled?: boolean;
  onNotify?: (msg: string) => void;
}) {
  const [mediaBusy, setMediaBusy] = useState(false);
  const slugOk = Boolean(pageSlug.trim());
  const disableUploads = formDisabled || mediaBusy;

  const move = (from: number, to: number) => {
    if (to < 0 || to >= sections.length) {
      return;
    }
    const next = [...sections];
    const [item] = next.splice(from, 1);
    if (item) {
      next.splice(to, 0, item);
    }
    onChange(next);
  };

  const remove = (index: number) => {
    onChange(sections.filter((_, i) => i !== index));
  };

  const addKind = (kind: PageSection['kind']) => {
    onChange([...sections, createEmptySection(kind)]);
  };

  async function handleImageFile(i: number, file: File | undefined) {
    if (!file) {
      return;
    }
    const sec = sections[i];
    if (!sec || sec.kind !== 'image') {
      return;
    }
    if (!slugOk) {
      onNotify?.('Set the page slug before uploading an image.');
      return;
    }
    setMediaBusy(true);
    try {
      const url = await uploadPageSectionImage(pageSlug, sec.id, file);
      onChange(updateSectionAt(sections, i, { url }));
      onNotify?.('Image uploaded.');
    } catch (e) {
      onNotify?.(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setMediaBusy(false);
    }
  }

  async function handleVideoFile(i: number, file: File | undefined) {
    if (!file) {
      return;
    }
    const sec = sections[i];
    if (!sec || sec.kind !== 'video') {
      return;
    }
    if (!slugOk) {
      onNotify?.('Set the page slug before uploading a video.');
      return;
    }
    setMediaBusy(true);
    try {
      const url = await uploadPageSectionVideo(pageSlug, sec.id, file);
      onChange(updateSectionAt(sections, i, { url }));
      onNotify?.('Video uploaded.');
    } catch (e) {
      onNotify?.(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setMediaBusy(false);
    }
  }

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      <div className="admin-row" style={{ flexWrap: 'wrap', gap: 8 }}>
        <span className="admin-muted" style={{ fontSize: '0.75rem', textTransform: 'uppercase' }}>
          Add block
        </span>
        <button type="button" onClick={() => addKind('heading')}>
          Heading
        </button>
        <button type="button" onClick={() => addKind('text')}>
          Text
        </button>
        <button type="button" onClick={() => addKind('panel')}>
          Panel
        </button>
        <button type="button" onClick={() => addKind('image')}>
          Image
        </button>
        <button type="button" onClick={() => addKind('video')}>
          Video
        </button>
        <button type="button" onClick={() => addKind('divider')}>
          Divider
        </button>
      </div>

      {sections.map((sec, i) => (
        <div key={sec.id} className="admin-panel" style={{ borderColor: 'rgba(166, 115, 255, 0.35)' }}>
          <div className="admin-row" style={{ justifyContent: 'space-between', marginBottom: 10 }}>
            <span className="admin-muted" style={{ fontSize: '0.75rem', textTransform: 'uppercase' }}>
              {sec.kind} · block {i + 1}
            </span>
            <span className="admin-row">
              <button type="button" onClick={() => move(i, i - 1)} disabled={i === 0}>
                Up
              </button>
              <button type="button" onClick={() => move(i, i + 1)} disabled={i === sections.length - 1}>
                Down
              </button>
              <button type="button" onClick={() => remove(i)}>
                Remove
              </button>
            </span>
          </div>

          {sec.kind === 'heading' && (
            <>
              <div className="admin-field">
                <label>Title</label>
                <input
                  value={sec.title}
                  onChange={(e) => onChange(updateSectionAt(sections, i, { title: e.target.value }))}
                />
              </div>
              <div className="admin-field">
                <label>Subtitle (optional)</label>
                <input
                  value={sec.subtitle ?? ''}
                  onChange={(e) =>
                    onChange(updateSectionAt(sections, i, { subtitle: e.target.value }))
                  }
                />
              </div>
            </>
          )}

          {sec.kind === 'text' && (
            <div className="admin-field">
              <label>Text</label>
              <textarea
                value={sec.body}
                onChange={(e) => onChange(updateSectionAt(sections, i, { body: e.target.value }))}
              />
            </div>
          )}

          {sec.kind === 'panel' && (
            <>
              <div className="admin-field">
                <label>Panel title</label>
                <input
                  value={sec.title}
                  onChange={(e) => onChange(updateSectionAt(sections, i, { title: e.target.value }))}
                />
              </div>
              <div className="admin-field">
                <label>Panel body</label>
                <textarea
                  value={sec.body}
                  onChange={(e) => onChange(updateSectionAt(sections, i, { body: e.target.value }))}
                />
              </div>
              <div className="admin-field">
                <label>Style</label>
                <select
                  value={sec.variant ?? 'default'}
                  onChange={(e) =>
                    onChange(
                      updateSectionAt(sections, i, {
                        variant: e.target.value as 'default' | 'accent' | 'muted',
                      }),
                    )
                  }
                >
                  <option value="default">Default</option>
                  <option value="accent">Accent</option>
                  <option value="muted">Muted</option>
                </select>
              </div>
            </>
          )}

          {sec.kind === 'image' && (
            <>
              <div className="admin-field">
                <label>Image URL</label>
                <input
                  value={sec.url}
                  onChange={(e) => onChange(updateSectionAt(sections, i, { url: e.target.value }))}
                />
              </div>
              <div className="admin-field">
                <label>Upload image</label>
                <input
                  type="file"
                  accept="image/png,image/jpeg,image/gif,image/webp,image/svg+xml,.svg"
                  disabled={disableUploads || !slugOk}
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    void handleImageFile(i, f);
                    e.target.value = '';
                  }}
                />
                {!slugOk ? (
                  <p className="admin-muted" style={{ margin: '8px 0 0' }}>
                    Save a page slug first — uploads go to <code>pages/&lt;slug&gt;/…</code>.
                  </p>
                ) : null}
              </div>
              <div className="admin-field">
                <label>Alt text</label>
                <input
                  value={sec.alt ?? ''}
                  onChange={(e) => onChange(updateSectionAt(sections, i, { alt: e.target.value }))}
                />
              </div>
              <div className="admin-field">
                <label>Caption (optional)</label>
                <input
                  value={sec.caption ?? ''}
                  onChange={(e) => onChange(updateSectionAt(sections, i, { caption: e.target.value }))}
                />
              </div>
            </>
          )}

          {sec.kind === 'video' && (
            <>
              <div className="admin-field">
                <label>Video URL</label>
                <input
                  value={sec.url}
                  onChange={(e) => onChange(updateSectionAt(sections, i, { url: e.target.value }))}
                />
              </div>
              <div className="admin-field">
                <label>Upload video (MP4 / WebM / MOV)</label>
                <input
                  type="file"
                  accept="video/mp4,video/webm,video/quicktime,.mp4,.webm,.mov"
                  disabled={disableUploads || !slugOk}
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    void handleVideoFile(i, f);
                    e.target.value = '';
                  }}
                />
                {!slugOk ? (
                  <p className="admin-muted" style={{ margin: '8px 0 0' }}>
                    Save a page slug first — uploads go to <code>pages/&lt;slug&gt;/…</code>.
                  </p>
                ) : null}
              </div>
              <div className="admin-field">
                <label>Caption (optional)</label>
                <input
                  value={sec.caption ?? ''}
                  onChange={(e) => onChange(updateSectionAt(sections, i, { caption: e.target.value }))}
                />
              </div>
            </>
          )}

          {sec.kind === 'divider' && (
            <p className="admin-muted" style={{ margin: 0 }}>
              Horizontal rule on the public page.
            </p>
          )}
        </div>
      ))}

      {sections.length === 0 && (
        <p className="admin-muted">
          No blocks yet. Add headings, text, panels, images, or videos. You can still use the legacy{' '}
          <strong>Body</strong> field below for a single text block when sections are empty.
        </p>
      )}
    </div>
  );
}

/** Ensure every section has a stable id (migration safety). */
export function ensureSectionIds(sections: PageSection[]): PageSection[] {
  return sections.map((s) => (s.id ? s : { ...s, id: newSectionId() }));
}

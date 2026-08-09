/**
 * PageSectionsForm — admin editor for every block type in the
 * `PageSection` union (see `types.ts`).
 *
 * Layout: one stack per block, with up/down/remove controls in the header.
 * For each `kind` we render a small inline editor. List-of-items blocks
 * (feature_list, stats, timeline, accordion, faq, gallery, buttons, …)
 * share the `ItemsEditor` helper so the UX is consistent across them.
 *
 * Storage uploads:
 *   - Image / video blocks: per-page Storage path `<folder>/<slug>/…`
 *   - Anything else (hero bg, gallery images, team avatars, etc.):
 *     `uploadStudioAsset` in `_studio/…` so blocks in homepage sections
 *     (which don't have a slug) can still upload.
 */
import { Fragment, useState } from 'react';
import { PAGE_BLOCK_LABELS } from '../../lib/adminLabels';
import type { PageItem, PageSection } from '../../types';
import { createEmptySection, newSectionId } from '../../lib/pageSections';
import {
  uploadPageSectionImage,
  uploadPageSectionVideo,
  uploadStudioAsset,
} from '../../lib/gameStorageUpload';
import { TIP_LINK_ALIAS } from '../../lib/tipLink';

// ===========================================================================
// State helpers.
// ===========================================================================

function updateSectionAt(
  sections: PageSection[],
  index: number,
  patch: Record<string, unknown>,
): PageSection[] {
  const next = [...sections];
  const cur = next[index];
  if (!cur) return sections;
  next[index] = { ...cur, ...patch } as PageSection;
  return next;
}

// ===========================================================================
// `ItemsEditor` — used by feature_list, stats, timeline, accordion, faq.
// ===========================================================================

function ItemsEditor({
  items,
  onChange,
  fields,
  blockName,
}: {
  items: PageItem[];
  onChange: (items: PageItem[]) => void;
  /** Which fields each item should expose. `title` and `body` are always shown. */
  fields: { icon?: boolean; href?: boolean; value?: boolean; status?: boolean };
  blockName: string;
}) {
  const update = (id: string, patch: Partial<PageItem>) =>
    onChange(items.map((it) => (it.id === id ? { ...it, ...patch } : it)));
  const remove = (id: string) => onChange(items.filter((it) => it.id !== id));
  const move = (from: number, to: number) => {
    if (to < 0 || to >= items.length) return;
    const next = [...items];
    const [it] = next.splice(from, 1);
    if (it) next.splice(to, 0, it);
    onChange(next);
  };
  return (
    <div className="admin-grid" style={{ gap: 8 }}>
      {items.length === 0 ? (
        <p className="admin-muted" style={{ fontSize: '0.82rem' }}>
          No {blockName} items yet. Click <strong>+ Add</strong> below.
        </p>
      ) : null}
      {items.map((it, idx) => (
        <div
          key={it.id}
          className="admin-panel"
          style={{ padding: 10, borderStyle: 'dashed', display: 'grid', gap: 8 }}
        >
          <div className="admin-row" style={{ justifyContent: 'space-between' }}>
            <span className="admin-muted" style={{ fontSize: '0.72rem', textTransform: 'uppercase' }}>
              {blockName} · {idx + 1}
            </span>
            <span className="admin-row">
              <button type="button" onClick={() => move(idx, idx - 1)} disabled={idx === 0}>↑</button>
              <button type="button" onClick={() => move(idx, idx + 1)} disabled={idx === items.length - 1}>↓</button>
              <button type="button" onClick={() => remove(it.id)}>✕</button>
            </span>
          </div>
          <div className="admin-field">
            <label>Title</label>
            <input value={it.title} onChange={(e) => update(it.id, { title: e.target.value })} />
          </div>
          <div className="admin-field">
            <label>Body</label>
            <textarea value={it.body} onChange={(e) => update(it.id, { body: e.target.value })} />
          </div>
          {fields.icon ? (
            <div className="admin-field">
              <label>Icon (emoji)</label>
              <input
                value={it.icon ?? ''}
                onChange={(e) => update(it.id, { icon: e.target.value })}
                placeholder="⚡ 🎮 …"
              />
            </div>
          ) : null}
          {fields.href ? (
            <div className="admin-field">
              <label>Link (optional)</label>
              <input
                value={it.href ?? ''}
                onChange={(e) => update(it.id, { href: e.target.value })}
                placeholder="/p/about or https://…"
              />
            </div>
          ) : null}
          {fields.value ? (
            <div className="admin-field">
              <label>Big value</label>
              <input
                value={it.value ?? ''}
                onChange={(e) => update(it.id, { value: e.target.value })}
                placeholder="12,453"
              />
            </div>
          ) : null}
          {fields.status ? (
            <div className="admin-field">
              <label>Status</label>
              <select
                value={it.status ?? 'planned'}
                onChange={(e) => update(it.id, { status: e.target.value as PageItem['status'] })}
              >
                <option value="done">Done</option>
                <option value="progress">In progress</option>
                <option value="planned">Planned</option>
                <option value="cancelled">Cancelled</option>
              </select>
            </div>
          ) : null}
        </div>
      ))}
      <div>
        <button
          type="button"
          onClick={() =>
            onChange([...items, { id: newSectionId(), title: 'New item', body: '' }])
          }
        >
          + Add {blockName}
        </button>
      </div>
    </div>
  );
}

// ===========================================================================
// Inline asset uploader — uploads to `_studio/…` and returns a public URL.
// Used by gallery / hero bg / team avatar / image_text image / etc.
// ===========================================================================

function StudioUploadButton({
  onUploaded,
  kind = 'image',
  accept = 'image/*',
  label = 'Upload',
}: {
  onUploaded: (url: string) => void;
  kind?: 'image' | 'audio' | 'video' | 'other';
  accept?: string;
  label?: string;
}) {
  const [busy, setBusy] = useState(false);
  return (
    <label
      className="admin-muted"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '4px 8px',
        borderRadius: 6,
        border: '1px solid var(--border)',
        cursor: busy ? 'wait' : 'pointer',
        fontSize: '0.8rem',
      }}
    >
      {busy ? 'Uploading…' : label}
      <input
        type="file"
        accept={accept}
        disabled={busy}
        style={{ display: 'none' }}
        onChange={async (e) => {
          const file = e.target.files?.[0];
          e.target.value = '';
          if (!file) return;
          setBusy(true);
          try {
            const url = await uploadStudioAsset(file, { kind });
            onUploaded(url);
          } catch {
            // Failures are surfaced via the inline error text on AssetUploadField;
            // here we just swallow so the user can retry.
          } finally {
            setBusy(false);
          }
        }}
      />
    </label>
  );
}

// ===========================================================================
// Main form.
// ===========================================================================

export function PageSectionsForm({
  sections,
  onChange,
  pageSlug = '',
  formDisabled = false,
  onNotify,
  /** Storage path prefix for media uploads (default: `pages/`). */
  mediaStorageFolder = 'pages',
}: {
  sections: PageSection[];
  onChange: (s: PageSection[]) => void;
  pageSlug?: string;
  formDisabled?: boolean;
  onNotify?: (msg: string) => void;
  mediaStorageFolder?: string;
}) {
  const [mediaBusy, setMediaBusy] = useState(false);
  const slugOk = Boolean(pageSlug.trim());
  const disableUploads = formDisabled || mediaBusy;

  const move = (from: number, to: number) => {
    if (to < 0 || to >= sections.length) return;
    const next = [...sections];
    const [item] = next.splice(from, 1);
    if (item) next.splice(to, 0, item);
    onChange(next);
  };

  const remove = (index: number) => {
    onChange(sections.filter((_, i) => i !== index));
  };

  const addKind = (kind: PageSection['kind']) => {
    onChange([...sections, createEmptySection(kind)]);
  };

  // Insert a fresh block at an arbitrary index so blocks can land anywhere,
  // not just at the end. `index` is the position the new block will occupy.
  const insertKindAt = (index: number, kind: PageSection['kind']) => {
    const next = [...sections];
    next.splice(index, 0, createEmptySection(kind));
    onChange(next);
  };

  async function handleImageFile(i: number, file: File | undefined) {
    if (!file) return;
    const sec = sections[i];
    if (!sec || sec.kind !== 'image') return;
    if (!slugOk) {
      onNotify?.('Set the page slug before uploading an image.');
      return;
    }
    setMediaBusy(true);
    try {
      const url = await uploadPageSectionImage(pageSlug, sec.id, file, { folder: mediaStorageFolder });
      onChange(updateSectionAt(sections, i, { url }));
      onNotify?.('Image uploaded.');
    } catch (e) {
      onNotify?.(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setMediaBusy(false);
    }
  }

  async function handleVideoFile(i: number, file: File | undefined) {
    if (!file) return;
    const sec = sections[i];
    if (!sec || sec.kind !== 'video') return;
    if (!slugOk) {
      onNotify?.('Set the page slug before uploading a video.');
      return;
    }
    setMediaBusy(true);
    try {
      const url = await uploadPageSectionVideo(pageSlug, sec.id, file, { folder: mediaStorageFolder });
      onChange(updateSectionAt(sections, i, { url }));
      onNotify?.('Video uploaded.');
    } catch (e) {
      onNotify?.(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setMediaBusy(false);
    }
  }

  // Convenience updater bound to a section index.
  const set = (i: number) => (patch: Record<string, unknown>) =>
    onChange(updateSectionAt(sections, i, patch));

  return (
    <div className="admin-grid" style={{ gap: 16 }}>
      {/* ===== "Add block" picker. ====================================== */}
      <details className="admin-panel" style={{ borderStyle: 'dashed' }}>
        <summary style={{ cursor: 'pointer', fontSize: '0.85rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
          + Add block
        </summary>
        <p className="admin-muted" style={{ fontSize: '0.8rem', marginTop: 8 }}>
          Pick any block — it appears at the end of the list. Use the <strong>+ Insert here</strong> strip between
          blocks to drop one anywhere, or the Up / Down buttons to reorder.
        </p>
        <div className="admin-row" style={{ flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
          {(Object.keys(PAGE_BLOCK_LABELS) as PageSection['kind'][]).map((k) => (
            <button key={k} type="button" onClick={() => addKind(k)}>
              {PAGE_BLOCK_LABELS[k]}
            </button>
          ))}
        </div>
      </details>

      {/* ===== Block list ============================================== */}
      {sections.map((sec, i) => (
        <Fragment key={sec.id}>
        <InsertBlockHere onInsert={(kind) => insertKindAt(i, kind)} />
        <div className="admin-panel" style={{ borderColor: 'rgba(166, 115, 255, 0.35)' }}>
          <div className="admin-row" style={{ justifyContent: 'space-between', marginBottom: 10 }}>
            <span className="admin-muted" style={{ fontSize: '0.75rem', textTransform: 'uppercase' }}>
              {sec.kind} · block {i + 1}
            </span>
            <span className="admin-row">
              <button type="button" onClick={() => move(i, i - 1)} disabled={i === 0}>Up</button>
              <button type="button" onClick={() => move(i, i + 1)} disabled={i === sections.length - 1}>Down</button>
              <button type="button" onClick={() => remove(i)}>Remove</button>
            </span>
          </div>

          {sec.kind === 'heading' && (
            <>
              <div className="admin-field">
                <label>Title</label>
                <input value={sec.title} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Subtitle (optional)</label>
                <input value={sec.subtitle ?? ''} onChange={(e) => set(i)({ subtitle: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Align</label>
                <select value={sec.align ?? 'left'} onChange={(e) => set(i)({ align: e.target.value })}>
                  <option value="left">Left</option>
                  <option value="center">Center</option>
                  <option value="right">Right</option>
                </select>
              </div>
            </>
          )}

          {sec.kind === 'text' && (
            <div className="admin-field">
              <label>Text</label>
              <textarea value={sec.body} onChange={(e) => set(i)({ body: e.target.value })} />
            </div>
          )}

          {sec.kind === 'panel' && (
            <>
              <div className="admin-field">
                <label>Panel title</label>
                <input value={sec.title} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Panel body</label>
                <textarea value={sec.body} onChange={(e) => set(i)({ body: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Style</label>
                <select
                  value={sec.variant ?? 'default'}
                  onChange={(e) => set(i)({ variant: e.target.value })}
                >
                  <option value="default">Default</option>
                  <option value="accent">Accent</option>
                  <option value="muted">Muted</option>
                </select>
              </div>
            </>
          )}

          {sec.kind === 'callout' && (
            <>
              <div className="admin-field">
                <label>Tone</label>
                <select value={sec.tone} onChange={(e) => set(i)({ tone: e.target.value })}>
                  <option value="info">Info (blue)</option>
                  <option value="tip">Tip (cyan)</option>
                  <option value="success">Success (green)</option>
                  <option value="warning">Warning (yellow)</option>
                  <option value="danger">Danger (red)</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Icon (emoji)</label>
                <input value={sec.icon ?? ''} onChange={(e) => set(i)({ icon: e.target.value })} placeholder="💡" />
              </div>
              <div className="admin-field">
                <label>Title</label>
                <input value={sec.title} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Body</label>
                <textarea value={sec.body} onChange={(e) => set(i)({ body: e.target.value })} />
              </div>
            </>
          )}

          {sec.kind === 'quote' && (
            <>
              <div className="admin-field">
                <label>Quote body</label>
                <textarea value={sec.body} onChange={(e) => set(i)({ body: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Author</label>
                <input value={sec.author ?? ''} onChange={(e) => set(i)({ author: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Role / source</label>
                <input value={sec.role ?? ''} onChange={(e) => set(i)({ role: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Avatar image URL</label>
                <div className="admin-row" style={{ gap: 8 }}>
                  <input
                    value={sec.avatar_url ?? ''}
                    onChange={(e) => set(i)({ avatar_url: e.target.value })}
                    style={{ flex: 1 }}
                  />
                  <StudioUploadButton onUploaded={(url) => set(i)({ avatar_url: url })} />
                </div>
              </div>
            </>
          )}

          {sec.kind === 'code' && (
            <>
              <div className="admin-field">
                <label>Code</label>
                <textarea
                  rows={8}
                  style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
                  value={sec.body}
                  onChange={(e) => set(i)({ body: e.target.value })}
                />
              </div>
              <div className="admin-field">
                <label>Language label (optional)</label>
                <input value={sec.language ?? ''} onChange={(e) => set(i)({ language: e.target.value })} placeholder="ts, py, sql…" />
              </div>
              <div className="admin-field">
                <label>Filename (optional)</label>
                <input value={sec.filename ?? ''} onChange={(e) => set(i)({ filename: e.target.value })} />
              </div>
            </>
          )}

          {sec.kind === 'markdown' && (
            <div className="admin-field">
              <label>Markdown</label>
              <textarea
                rows={12}
                style={{ fontFamily: 'monospace', fontSize: '0.85rem' }}
                value={sec.body}
                onChange={(e) => set(i)({ body: e.target.value })}
              />
            </div>
          )}

          {sec.kind === 'html' && (
            <div className="admin-field">
              <label>Raw HTML (admin trust)</label>
              <textarea
                rows={10}
                style={{ fontFamily: 'monospace', fontSize: '0.82rem' }}
                value={sec.html}
                onChange={(e) => set(i)({ html: e.target.value })}
              />
              <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 6 }}>
                Renders the HTML as-is — only paste from sources you trust.
              </p>
            </div>
          )}

          {sec.kind === 'divider' && (
            <p className="admin-muted" style={{ margin: 0 }}>Horizontal rule on the public page.</p>
          )}

          {sec.kind === 'spacer' && (
            <div className="admin-field">
              <label>Size</label>
              <select value={sec.size} onChange={(e) => set(i)({ size: e.target.value })}>
                <option value="xs">XS (8px)</option>
                <option value="sm">SM (16px)</option>
                <option value="md">MD (32px)</option>
                <option value="lg">LG (64px)</option>
                <option value="xl">XL (128px)</option>
              </select>
            </div>
          )}

          {sec.kind === 'image' && (
            <>
              <div className="admin-field">
                <label>Image URL</label>
                <div className="admin-row" style={{ gap: 8 }}>
                  <input
                    value={sec.url}
                    onChange={(e) => set(i)({ url: e.target.value })}
                    style={{ flex: 1 }}
                  />
                  <StudioUploadButton onUploaded={(url) => set(i)({ url })} />
                </div>
              </div>
              <div className="admin-field">
                <label>Upload image (uses page slug folder)</label>
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
                    Save the slug first — or use the Upload button next to URL above.
                  </p>
                ) : null}
              </div>
              <div className="admin-field">
                <label>Alt text</label>
                <input value={sec.alt ?? ''} onChange={(e) => set(i)({ alt: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Caption (optional)</label>
                <input value={sec.caption ?? ''} onChange={(e) => set(i)({ caption: e.target.value })} />
              </div>
            </>
          )}

          {sec.kind === 'video' && (
            <>
              <div className="admin-field">
                <label>Video URL</label>
                <div className="admin-row" style={{ gap: 8 }}>
                  <input
                    value={sec.url}
                    onChange={(e) => set(i)({ url: e.target.value })}
                    style={{ flex: 1 }}
                  />
                  <StudioUploadButton
                    onUploaded={(url) => set(i)({ url })}
                    kind="video"
                    accept="video/*"
                  />
                </div>
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
              </div>
              <div className="admin-field">
                <label>Caption (optional)</label>
                <input value={sec.caption ?? ''} onChange={(e) => set(i)({ caption: e.target.value })} />
              </div>
            </>
          )}

          {sec.kind === 'gallery' && (
            <>
              <div className="admin-field">
                <label>Columns</label>
                <select value={sec.columns ?? 3} onChange={(e) => set(i)({ columns: Number(e.target.value) })}>
                  <option value={2}>2</option>
                  <option value={3}>3</option>
                  <option value={4}>4</option>
                </select>
              </div>
              <label className="admin-row" style={{ gap: 8 }}>
                <input
                  type="checkbox"
                  checked={sec.lightbox !== false}
                  onChange={(e) => set(i)({ lightbox: e.target.checked })}
                />
                Click to open full-screen lightbox
              </label>
              <div className="admin-grid" style={{ gap: 8, marginTop: 8 }}>
                {sec.images.map((img, idx) => (
                  <div key={img.id} className="admin-panel" style={{ padding: 10, borderStyle: 'dashed' }}>
                    <div className="admin-row" style={{ justifyContent: 'space-between' }}>
                      <span className="admin-muted" style={{ fontSize: '0.72rem' }}>Image {idx + 1}</span>
                      <button
                        type="button"
                        onClick={() => set(i)({ images: sec.images.filter((g) => g.id !== img.id) })}
                      >✕</button>
                    </div>
                    <div className="admin-field">
                      <label>URL</label>
                      <div className="admin-row" style={{ gap: 8 }}>
                        <input
                          value={img.url}
                          onChange={(e) =>
                            set(i)({
                              images: sec.images.map((g) => (g.id === img.id ? { ...g, url: e.target.value } : g)),
                            })
                          }
                          style={{ flex: 1 }}
                        />
                        <StudioUploadButton
                          onUploaded={(url) =>
                            set(i)({
                              images: sec.images.map((g) => (g.id === img.id ? { ...g, url } : g)),
                            })
                          }
                        />
                      </div>
                    </div>
                    <div className="admin-field">
                      <label>Caption</label>
                      <input
                        value={img.caption ?? ''}
                        onChange={(e) =>
                          set(i)({
                            images: sec.images.map((g) => (g.id === img.id ? { ...g, caption: e.target.value } : g)),
                          })
                        }
                      />
                    </div>
                  </div>
                ))}
                <button
                  type="button"
                  onClick={() =>
                    set(i)({
                      images: [...sec.images, { id: newSectionId(), url: '', caption: '' }],
                    })
                  }
                >
                  + Add image
                </button>
              </div>
            </>
          )}

          {sec.kind === 'embed' && (
            <>
              <div className="admin-field">
                <label>Provider</label>
                <select value={sec.provider ?? 'custom'} onChange={(e) => set(i)({ provider: e.target.value })}>
                  <option value="youtube">YouTube</option>
                  <option value="vimeo">Vimeo</option>
                  <option value="twitch">Twitch</option>
                  <option value="codepen">CodePen</option>
                  <option value="soundcloud">SoundCloud</option>
                  <option value="custom">Custom (paste embed URL)</option>
                </select>
              </div>
              <div className="admin-field">
                <label>URL</label>
                <input value={sec.url} onChange={(e) => set(i)({ url: e.target.value })} />
                <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 4 }}>
                  Paste any YouTube/Vimeo/Twitch URL — we convert to the correct embed automatically.
                </p>
              </div>
              <div className="admin-field">
                <label>Aspect ratio</label>
                <select value={sec.aspect ?? '16/9'} onChange={(e) => set(i)({ aspect: e.target.value })}>
                  <option value="16/9">16:9 (widescreen)</option>
                  <option value="4/3">4:3</option>
                  <option value="1/1">1:1 (square)</option>
                  <option value="auto">Auto</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Caption (optional)</label>
                <input value={sec.caption ?? ''} onChange={(e) => set(i)({ caption: e.target.value })} />
              </div>
            </>
          )}

          {sec.kind === 'iframe' && (
            <>
              <div className="admin-field">
                <label>Iframe URL</label>
                <input value={sec.url} onChange={(e) => set(i)({ url: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Height (px)</label>
                <input
                  type="number"
                  value={sec.height_px ?? 480}
                  onChange={(e) => set(i)({ height_px: Number(e.target.value) })}
                />
              </div>
              <div className="admin-field">
                <label>Allow attribute (optional)</label>
                <input value={sec.allow ?? ''} onChange={(e) => set(i)({ allow: e.target.value })} placeholder="fullscreen; autoplay" />
              </div>
              <div className="admin-field">
                <label>Caption (optional)</label>
                <input value={sec.caption ?? ''} onChange={(e) => set(i)({ caption: e.target.value })} />
              </div>
            </>
          )}

          {sec.kind === 'sandbox_html' && (
            <>
              <p className="admin-muted" style={{ fontSize: '0.78rem', marginBottom: 10, lineHeight: 1.5 }}>
                Paste a full HTML document (e.g. a Gemini / single-file export). Runs in a{' '}
                <strong>sandboxed iframe</strong> — isolated from the hub. Enable compat only for apps that break
                without <code>allow-same-origin</code> (trusted code only).
              </p>
              <div className="admin-field">
                <label>HTML document</label>
                <textarea
                  value={sec.html}
                  onChange={(e) => set(i)({ html: e.target.value })}
                  rows={14}
                  style={{ width: '100%', fontFamily: 'monospace', fontSize: '0.8rem' }}
                />
              </div>
              <div className="admin-field">
                <label>Height (px)</label>
                <input
                  type="number"
                  value={sec.height_px ?? 560}
                  onChange={(e) => set(i)({ height_px: Number(e.target.value) })}
                />
              </div>
              <div className="admin-field">
                <label>
                  <input
                    type="checkbox"
                    checked={Boolean(sec.iframe_compat)}
                    onChange={(e) => set(i)({ iframe_compat: e.target.checked })}
                  />{' '}
                  Compat sandbox (allow-same-origin)
                </label>
              </div>
              <div className="admin-field">
                <label>Caption (optional)</label>
                <input value={sec.caption ?? ''} onChange={(e) => set(i)({ caption: e.target.value })} />
              </div>
            </>
          )}

          {sec.kind === 'hero' && (
            <>
              <div className="admin-field">
                <label>Title</label>
                <input value={sec.title} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Subtitle</label>
                <input value={sec.subtitle ?? ''} onChange={(e) => set(i)({ subtitle: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Background image</label>
                <div className="admin-row" style={{ gap: 8 }}>
                  <input
                    value={sec.bg_image_url ?? ''}
                    onChange={(e) => set(i)({ bg_image_url: e.target.value })}
                    style={{ flex: 1 }}
                  />
                  <StudioUploadButton onUploaded={(url) => set(i)({ bg_image_url: url })} />
                </div>
              </div>
              <div className="admin-field">
                <label>Background video (MP4/WebM)</label>
                <div className="admin-row" style={{ gap: 8 }}>
                  <input
                    value={sec.bg_video_url ?? ''}
                    onChange={(e) => set(i)({ bg_video_url: e.target.value })}
                    style={{ flex: 1 }}
                  />
                  <StudioUploadButton onUploaded={(url) => set(i)({ bg_video_url: url })} kind="video" accept="video/*" />
                </div>
              </div>
              <div className="admin-field">
                <label>Overlay darkness</label>
                <input
                  type="range"
                  min={0}
                  max={1}
                  step={0.05}
                  value={sec.overlay ?? 0.4}
                  onChange={(e) => set(i)({ overlay: Number(e.target.value) })}
                />
              </div>
              <div className="admin-field">
                <label>Height</label>
                <select value={sec.height ?? 'md'} onChange={(e) => set(i)({ height: e.target.value })}>
                  <option value="sm">Small (220px)</option>
                  <option value="md">Medium (320px)</option>
                  <option value="lg">Large (420px)</option>
                  <option value="screen">Full viewport (70vh)</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Alignment</label>
                <select value={sec.align ?? 'center'} onChange={(e) => set(i)({ align: e.target.value })}>
                  <option value="left">Left</option>
                  <option value="center">Center</option>
                  <option value="right">Right</option>
                </select>
              </div>
              <CtaEditor
                label="Call-to-action button"
                value={sec.cta}
                onChange={(cta) => set(i)({ cta })}
              />
            </>
          )}

          {sec.kind === 'cta' && (
            <>
              <div className="admin-field">
                <label>Title</label>
                <input value={sec.title} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Body</label>
                <textarea value={sec.body} onChange={(e) => set(i)({ body: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Background image (optional)</label>
                <div className="admin-row" style={{ gap: 8 }}>
                  <input
                    value={sec.bg_image_url ?? ''}
                    onChange={(e) => set(i)({ bg_image_url: e.target.value })}
                    style={{ flex: 1 }}
                  />
                  <StudioUploadButton onUploaded={(url) => set(i)({ bg_image_url: url })} />
                </div>
              </div>
              <CtaEditor label="Primary button" value={sec.primary} onChange={(primary) => set(i)({ primary })} />
              <CtaEditor label="Secondary button (optional)" value={sec.secondary} onChange={(secondary) => set(i)({ secondary })} />
            </>
          )}

          {sec.kind === 'tip_button' && (
            <>
              <p className="admin-muted" style={{ fontSize: '0.82rem', lineHeight: 1.45 }}>
                Uses the tip link from <strong>Site copy → Support / tip link</strong>. Leave label blank for the site
                default.
              </p>
              <div className="admin-field">
                <label>Button label (optional)</label>
                <input
                  value={sec.label ?? ''}
                  onChange={(e) => set(i)({ label: e.target.value })}
                  placeholder="Support the Devs"
                />
              </div>
              <div className="admin-field">
                <label>Align</label>
                <select value={sec.align ?? 'center'} onChange={(e) => set(i)({ align: e.target.value })}>
                  <option value="left">Left</option>
                  <option value="center">Center</option>
                  <option value="right">Right</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Style</label>
                <select
                  value={sec.variant ?? 'primary'}
                  onChange={(e) => set(i)({ variant: e.target.value as 'primary' | 'secondary' })}
                >
                  <option value="primary">Primary (gradient)</option>
                  <option value="secondary">Secondary</option>
                </select>
              </div>
            </>
          )}

          {sec.kind === 'buttons' && (
            <>
              <p className="admin-muted" style={{ fontSize: '0.82rem', lineHeight: 1.45 }}>
                Add any label + URL. Use <code>{TIP_LINK_ALIAS}</code> (or paste your Stripe link) to open the support /
                tip checkout — no need to copy the long URL again after you set it in Site copy.
              </p>
              <div className="admin-field">
                <label>Align</label>
                <select value={sec.align ?? 'left'} onChange={(e) => set(i)({ align: e.target.value })}>
                  <option value="left">Left</option>
                  <option value="center">Center</option>
                  <option value="right">Right</option>
                </select>
              </div>
              <div className="admin-grid" style={{ gap: 8, marginTop: 8 }}>
                {sec.buttons.map((b, idx) => (
                  <div key={b.id} className="admin-panel" style={{ padding: 10, borderStyle: 'dashed' }}>
                    <div className="admin-row" style={{ justifyContent: 'space-between' }}>
                      <span className="admin-muted" style={{ fontSize: '0.72rem' }}>Button {idx + 1}</span>
                      <button
                        type="button"
                        onClick={() => set(i)({ buttons: sec.buttons.filter((x) => x.id !== b.id) })}
                      >✕</button>
                    </div>
                    <div className="admin-field">
                      <label>Label</label>
                      <input
                        value={b.label}
                        onChange={(e) =>
                          set(i)({
                            buttons: sec.buttons.map((x) => (x.id === b.id ? { ...x, label: e.target.value } : x)),
                          })
                        }
                      />
                    </div>
                    <div className="admin-field">
                      <label>URL</label>
                      <input
                        value={b.href}
                        onChange={(e) =>
                          set(i)({
                            buttons: sec.buttons.map((x) => (x.id === b.id ? { ...x, href: e.target.value } : x)),
                          })
                        }
                        placeholder={`https://… or ${TIP_LINK_ALIAS} for support link`}
                      />
                      <button
                        type="button"
                        style={{ marginTop: 6, fontSize: '0.78rem' }}
                        onClick={() =>
                          set(i)({
                            buttons: sec.buttons.map((x) =>
                              x.id === b.id ? { ...x, href: TIP_LINK_ALIAS, external: true } : x,
                            ),
                          })
                        }
                      >
                        Use support link ({TIP_LINK_ALIAS})
                      </button>
                    </div>
                    <label className="admin-row" style={{ gap: 8 }}>
                      <input
                        type="checkbox"
                        checked={b.external ?? false}
                        onChange={(e) =>
                          set(i)({
                            buttons: sec.buttons.map((x) => (x.id === b.id ? { ...x, external: e.target.checked } : x)),
                          })
                        }
                      />
                      External (new tab)
                    </label>
                    <div className="admin-field">
                      <label>Style</label>
                      <select
                        value={b.variant ?? 'primary'}
                        onChange={(e) =>
                          set(i)({
                            buttons: sec.buttons.map((x) =>
                              x.id === b.id ? { ...x, variant: e.target.value as 'primary' | 'secondary' | 'ghost' } : x,
                            ),
                          })
                        }
                      >
                        <option value="primary">Primary</option>
                        <option value="secondary">Secondary</option>
                        <option value="ghost">Ghost (outline)</option>
                      </select>
                    </div>
                  </div>
                ))}
                <button
                  type="button"
                  onClick={() =>
                    set(i)({
                      buttons: [...sec.buttons, { id: newSectionId(), label: 'New', href: '', variant: 'primary' }],
                    })
                  }
                >
                  + Add button
                </button>
              </div>
            </>
          )}

          {sec.kind === 'download' && (
            <>
              <div className="admin-field">
                <label>Title</label>
                <input value={sec.title} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Body</label>
                <input value={sec.body} onChange={(e) => set(i)({ body: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Download URL</label>
                <div className="admin-row" style={{ gap: 8 }}>
                  <input value={sec.href} onChange={(e) => set(i)({ href: e.target.value })} style={{ flex: 1 }} />
                  <StudioUploadButton onUploaded={(url) => set(i)({ href: url })} kind="other" accept="*/*" />
                </div>
              </div>
              <div className="admin-field">
                <label>Icon (emoji)</label>
                <input value={sec.icon ?? ''} onChange={(e) => set(i)({ icon: e.target.value })} placeholder="📦" />
              </div>
              <div className="admin-field">
                <label>Format</label>
                <input value={sec.format ?? ''} onChange={(e) => set(i)({ format: e.target.value })} placeholder="ZIP, PDF…" />
              </div>
              <div className="admin-field">
                <label>Size</label>
                <input value={sec.size ?? ''} onChange={(e) => set(i)({ size: e.target.value })} placeholder="4.2 MB" />
              </div>
            </>
          )}

          {sec.kind === 'image_text' && (
            <>
              <div className="admin-field">
                <label>Image URL</label>
                <div className="admin-row" style={{ gap: 8 }}>
                  <input
                    value={sec.image_url}
                    onChange={(e) => set(i)({ image_url: e.target.value })}
                    style={{ flex: 1 }}
                  />
                  <StudioUploadButton onUploaded={(url) => set(i)({ image_url: url })} />
                </div>
              </div>
              <div className="admin-field">
                <label>Image side</label>
                <select value={sec.image_side ?? 'left'} onChange={(e) => set(i)({ image_side: e.target.value })}>
                  <option value="left">Left</option>
                  <option value="right">Right</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Title</label>
                <input value={sec.title} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Body</label>
                <textarea value={sec.body} onChange={(e) => set(i)({ body: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Image alt</label>
                <input value={sec.image_alt ?? ''} onChange={(e) => set(i)({ image_alt: e.target.value })} />
              </div>
              <CtaEditor label="CTA (optional)" value={sec.cta} onChange={(cta) => set(i)({ cta })} />
            </>
          )}

          {sec.kind === 'columns' && (
            <>
              <p className="admin-muted" style={{ fontSize: '0.8rem' }}>
                Columns can hold any other block — even nested columns. Use the picker inside each column.
              </p>
              <div className="admin-row" style={{ gap: 8, marginBottom: 8 }}>
                <button
                  type="button"
                  onClick={() =>
                    set(i)({
                      columns: [...sec.columns, { id: newSectionId(), sections: [] }],
                    })
                  }
                >+ Add column</button>
                <button
                  type="button"
                  onClick={() =>
                    set(i)({ columns: sec.columns.slice(0, -1) })
                  }
                  disabled={sec.columns.length <= 1}
                >− Remove column</button>
                <span className="admin-muted" style={{ fontSize: '0.8rem' }}>
                  {sec.columns.length} column{sec.columns.length === 1 ? '' : 's'}
                </span>
              </div>
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: `repeat(${Math.min(sec.columns.length, 3)}, 1fr)`,
                  gap: 12,
                }}
              >
                {sec.columns.map((col, idx) => (
                  <div key={col.id} className="admin-panel" style={{ padding: 10, borderStyle: 'dashed' }}>
                    <div className="admin-row" style={{ justifyContent: 'space-between' }}>
                      <span className="admin-muted" style={{ fontSize: '0.72rem' }}>Col {idx + 1}</span>
                    </div>
                    <PageSectionsForm
                      sections={col.sections}
                      onChange={(nextSections) =>
                        set(i)({
                          columns: sec.columns.map((c) =>
                            c.id === col.id ? { ...c, sections: nextSections } : c,
                          ),
                        })
                      }
                      pageSlug={pageSlug}
                      mediaStorageFolder={mediaStorageFolder}
                      formDisabled={formDisabled}
                      onNotify={onNotify}
                    />
                  </div>
                ))}
              </div>
            </>
          )}

          {sec.kind === 'tabs' && (
            <>
              <p className="admin-muted" style={{ fontSize: '0.8rem' }}>
                Each tab contains its own block list — perfect for "Overview / Story / Controls / Credits" pages.
              </p>
              <div className="admin-grid" style={{ gap: 8 }}>
                {sec.tabs.map((t, idx) => (
                  <div key={t.id} className="admin-panel" style={{ padding: 10, borderStyle: 'dashed' }}>
                    <div className="admin-row" style={{ justifyContent: 'space-between' }}>
                      <strong>Tab {idx + 1}</strong>
                      <button
                        type="button"
                        onClick={() => set(i)({ tabs: sec.tabs.filter((x) => x.id !== t.id) })}
                      >✕</button>
                    </div>
                    <div className="admin-field">
                      <label>Label</label>
                      <input
                        value={t.label}
                        onChange={(e) =>
                          set(i)({
                            tabs: sec.tabs.map((x) => (x.id === t.id ? { ...x, label: e.target.value } : x)),
                          })
                        }
                      />
                    </div>
                    <PageSectionsForm
                      sections={t.sections}
                      onChange={(nextSections) =>
                        set(i)({
                          tabs: sec.tabs.map((x) =>
                            x.id === t.id ? { ...x, sections: nextSections } : x,
                          ),
                        })
                      }
                      pageSlug={pageSlug}
                      mediaStorageFolder={mediaStorageFolder}
                      formDisabled={formDisabled}
                      onNotify={onNotify}
                    />
                  </div>
                ))}
                <button
                  type="button"
                  onClick={() =>
                    set(i)({
                      tabs: [...sec.tabs, { id: newSectionId(), label: 'New tab', sections: [] }],
                    })
                  }
                >+ Add tab</button>
              </div>
            </>
          )}

          {sec.kind === 'feature_list' && (
            <>
              <div className="admin-field">
                <label>Columns</label>
                <select value={sec.columns ?? 3} onChange={(e) => set(i)({ columns: Number(e.target.value) })}>
                  <option value={2}>2</option>
                  <option value={3}>3</option>
                  <option value={4}>4</option>
                </select>
              </div>
              <ItemsEditor
                items={sec.items}
                onChange={(items) => set(i)({ items })}
                fields={{ icon: true, href: true }}
                blockName="feature"
              />
            </>
          )}

          {sec.kind === 'stats' && (
            <>
              <div className="admin-field">
                <label>Columns</label>
                <select value={sec.columns ?? 3} onChange={(e) => set(i)({ columns: Number(e.target.value) })}>
                  <option value={2}>2</option>
                  <option value={3}>3</option>
                  <option value={4}>4</option>
                </select>
              </div>
              <ItemsEditor
                items={sec.items}
                onChange={(items) => set(i)({ items })}
                fields={{ value: true }}
                blockName="stat"
              />
            </>
          )}

          {sec.kind === 'timeline' && (
            <ItemsEditor
              items={sec.items}
              onChange={(items) => set(i)({ items })}
              fields={{ icon: true, status: true }}
              blockName="step"
            />
          )}

          {sec.kind === 'accordion' && (
            <ItemsEditor
              items={sec.items}
              onChange={(items) => set(i)({ items })}
              fields={{}}
              blockName="row"
            />
          )}

          {sec.kind === 'faq' && (
            <>
              <div className="admin-field">
                <label>Intro (optional)</label>
                <input value={sec.intro ?? ''} onChange={(e) => set(i)({ intro: e.target.value })} />
              </div>
              <ItemsEditor
                items={sec.items}
                onChange={(items) => set(i)({ items })}
                fields={{}}
                blockName="question"
              />
            </>
          )}

          {sec.kind === 'pricing' && (
            <>
              <div className="admin-grid" style={{ gap: 8 }}>
                {sec.columns.map((col, idx) => (
                  <div key={col.id} className="admin-panel" style={{ padding: 10, borderStyle: 'dashed' }}>
                    <div className="admin-row" style={{ justifyContent: 'space-between' }}>
                      <strong>Plan {idx + 1}</strong>
                      <button
                        type="button"
                        onClick={() => set(i)({ columns: sec.columns.filter((c) => c.id !== col.id) })}
                      >✕</button>
                    </div>
                    <div className="admin-field">
                      <label>Title</label>
                      <input
                        value={col.title}
                        onChange={(e) =>
                          set(i)({
                            columns: sec.columns.map((c) => (c.id === col.id ? { ...c, title: e.target.value } : c)),
                          })
                        }
                      />
                    </div>
                    <div className="admin-field">
                      <label>Price</label>
                      <input
                        value={col.price}
                        onChange={(e) =>
                          set(i)({
                            columns: sec.columns.map((c) => (c.id === col.id ? { ...c, price: e.target.value } : c)),
                          })
                        }
                      />
                    </div>
                    <div className="admin-field">
                      <label>Period</label>
                      <input
                        value={col.period ?? ''}
                        onChange={(e) =>
                          set(i)({
                            columns: sec.columns.map((c) => (c.id === col.id ? { ...c, period: e.target.value } : c)),
                          })
                        }
                      />
                    </div>
                    <div className="admin-field">
                      <label>Features (one per line)</label>
                      <textarea
                        value={col.features.join('\n')}
                        onChange={(e) =>
                          set(i)({
                            columns: sec.columns.map((c) =>
                              c.id === col.id ? { ...c, features: e.target.value.split('\n') } : c,
                            ),
                          })
                        }
                      />
                    </div>
                    <label className="admin-row" style={{ gap: 8 }}>
                      <input
                        type="checkbox"
                        checked={col.featured ?? false}
                        onChange={(e) =>
                          set(i)({
                            columns: sec.columns.map((c) => (c.id === col.id ? { ...c, featured: e.target.checked } : c)),
                          })
                        }
                      />
                      Featured plan (highlighted)
                    </label>
                    <CtaEditor
                      label="CTA"
                      value={col.cta}
                      onChange={(cta) =>
                        set(i)({
                          columns: sec.columns.map((c) => (c.id === col.id ? { ...c, cta } : c)),
                        })
                      }
                    />
                  </div>
                ))}
                <button
                  type="button"
                  onClick={() =>
                    set(i)({
                      columns: [
                        ...sec.columns,
                        { id: newSectionId(), title: 'New plan', price: '$0', features: [] },
                      ],
                    })
                  }
                >+ Add plan</button>
              </div>
            </>
          )}

          {sec.kind === 'team' && (
            <>
              <div className="admin-field">
                <label>Columns</label>
                <select value={sec.columns ?? 3} onChange={(e) => set(i)({ columns: Number(e.target.value) })}>
                  <option value={2}>2</option>
                  <option value={3}>3</option>
                  <option value={4}>4</option>
                </select>
              </div>
              <div className="admin-grid" style={{ gap: 8 }}>
                {sec.members.map((m) => (
                  <div key={m.id} className="admin-panel" style={{ padding: 10, borderStyle: 'dashed' }}>
                    <div className="admin-row" style={{ justifyContent: 'space-between' }}>
                      <span className="admin-muted" style={{ fontSize: '0.72rem' }}>{m.name || 'Unnamed'}</span>
                      <button
                        type="button"
                        onClick={() => set(i)({ members: sec.members.filter((x) => x.id !== m.id) })}
                      >✕</button>
                    </div>
                    <div className="admin-field">
                      <label>Name</label>
                      <input
                        value={m.name}
                        onChange={(e) =>
                          set(i)({ members: sec.members.map((x) => (x.id === m.id ? { ...x, name: e.target.value } : x)) })
                        }
                      />
                    </div>
                    <div className="admin-field">
                      <label>Role</label>
                      <input
                        value={m.role}
                        onChange={(e) =>
                          set(i)({ members: sec.members.map((x) => (x.id === m.id ? { ...x, role: e.target.value } : x)) })
                        }
                      />
                    </div>
                    <div className="admin-field">
                      <label>Avatar URL</label>
                      <div className="admin-row" style={{ gap: 8 }}>
                        <input
                          value={m.avatar_url ?? ''}
                          onChange={(e) =>
                            set(i)({
                              members: sec.members.map((x) =>
                                x.id === m.id ? { ...x, avatar_url: e.target.value } : x,
                              ),
                            })
                          }
                          style={{ flex: 1 }}
                        />
                        <StudioUploadButton
                          onUploaded={(url) =>
                            set(i)({
                              members: sec.members.map((x) =>
                                x.id === m.id ? { ...x, avatar_url: url } : x,
                              ),
                            })
                          }
                        />
                      </div>
                    </div>
                    <div className="admin-field">
                      <label>Bio (optional)</label>
                      <textarea
                        value={m.bio ?? ''}
                        onChange={(e) =>
                          set(i)({ members: sec.members.map((x) => (x.id === m.id ? { ...x, bio: e.target.value } : x)) })
                        }
                      />
                    </div>
                    <div className="admin-field">
                      <label>Link (optional)</label>
                      <input
                        value={m.href ?? ''}
                        onChange={(e) =>
                          set(i)({ members: sec.members.map((x) => (x.id === m.id ? { ...x, href: e.target.value } : x)) })
                        }
                      />
                    </div>
                  </div>
                ))}
                <button
                  type="button"
                  onClick={() =>
                    set(i)({
                      members: [...sec.members, { id: newSectionId(), name: 'New member', role: '' }],
                    })
                  }
                >+ Add member</button>
              </div>
            </>
          )}

          {sec.kind === 'newsletter' && (
            <>
              <div className="admin-field">
                <label>Title</label>
                <input value={sec.title} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Body</label>
                <textarea value={sec.body} onChange={(e) => set(i)({ body: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Provider</label>
                <select value={sec.provider} onChange={(e) => set(i)({ provider: e.target.value })}>
                  <option value="mailchimp">Mailchimp</option>
                  <option value="buttondown">Buttondown</option>
                  <option value="substack">Substack</option>
                  <option value="convertkit">ConvertKit</option>
                  <option value="custom">Custom form action</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Form action URL</label>
                <input value={sec.action_url} onChange={(e) => set(i)({ action_url: e.target.value })} />
                <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 4 }}>
                  Paste the embed action URL from your provider's signup form.
                </p>
              </div>
              <div className="admin-field">
                <label>Button label</label>
                <input value={sec.button_label ?? ''} onChange={(e) => set(i)({ button_label: e.target.value })} />
              </div>
            </>
          )}

          {sec.kind === 'game_grid' && (
            <>
              <div className="admin-field">
                <label>Section title (optional)</label>
                <input value={sec.title ?? ''} onChange={(e) => set(i)({ title: e.target.value })} placeholder="Featured games" />
              </div>
              <div className="admin-field">
                <label>Columns (cards per row)</label>
                <select value={sec.columns ?? 3} onChange={(e) => set(i)({ columns: Number(e.target.value) })}>
                  <option value={2}>2</option>
                  <option value={3}>3</option>
                  <option value={4}>4</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Game slugs (one per line)</label>
                <textarea
                  rows={4}
                  value={sec.slugs.join('\n')}
                  onChange={(e) => set(i)({ slugs: e.target.value.split('\n').map((s) => s.trim()).filter(Boolean) })}
                />
                <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 4 }}>
                  Match the slug you set on each game (Games tab). Order matters.
                </p>
              </div>
            </>
          )}

          {sec.kind === 'comments' && (
            <>
              <div className="admin-field">
                <label>Section title</label>
                <input value={sec.title ?? ''} onChange={(e) => set(i)({ title: e.target.value })} />
              </div>
              <p className="admin-muted" style={{ fontSize: '0.82rem', lineHeight: 1.5 }}>
                Leave target empty on game / page / dev log routes — the page slug is used automatically. Override
                only for cross-linking another thread.
              </p>
              <div className="admin-field">
                <label>Target type (optional)</label>
                <select
                  value={sec.target_type ?? ''}
                  onChange={(e) =>
                    set(i)({
                      target_type: (e.target.value || undefined) as 'game' | 'page' | 'devlog' | undefined,
                    })
                  }
                >
                  <option value="">Use page context</option>
                  <option value="game">Game</option>
                  <option value="page">CMS page</option>
                  <option value="devlog">Dev log</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Target key / slug (optional)</label>
                <input
                  value={sec.target_key ?? ''}
                  onChange={(e) => set(i)({ target_key: e.target.value })}
                  placeholder="my-game-slug"
                />
              </div>
            </>
          )}

          {sec.kind === 'tags' && (
            <div className="admin-grid" style={{ gap: 8 }}>
              {sec.items.map((t) => (
                <div key={t.id} className="admin-row" style={{ gap: 6 }}>
                  <input
                    value={t.label}
                    onChange={(e) =>
                      set(i)({ items: sec.items.map((x) => (x.id === t.id ? { ...x, label: e.target.value } : x)) })
                    }
                    style={{ flex: 1 }}
                  />
                  <input
                    value={t.href ?? ''}
                    onChange={(e) =>
                      set(i)({ items: sec.items.map((x) => (x.id === t.id ? { ...x, href: e.target.value } : x)) })
                    }
                    placeholder="link (optional)"
                    style={{ flex: 1 }}
                  />
                  <select
                    value={t.tone ?? 'default'}
                    onChange={(e) =>
                      set(i)({
                        items: sec.items.map((x) =>
                          x.id === t.id ? { ...x, tone: e.target.value as 'default' | 'accent' | 'muted' } : x,
                        ),
                      })
                    }
                  >
                    <option value="default">Default</option>
                    <option value="accent">Accent</option>
                    <option value="muted">Muted</option>
                  </select>
                  <button
                    type="button"
                    onClick={() => set(i)({ items: sec.items.filter((x) => x.id !== t.id) })}
                  >✕</button>
                </div>
              ))}
              <button
                type="button"
                onClick={() =>
                  set(i)({
                    items: [...sec.items, { id: newSectionId(), label: 'tag', tone: 'default' as const }],
                  })
                }
              >+ Add tag</button>
            </div>
          )}
        </div>
        {i === sections.length - 1 ? (
          <InsertBlockHere onInsert={(kind) => insertKindAt(i + 1, kind)} atEnd />
        ) : null}
        </Fragment>
      ))}

      {sections.length === 0 ? (
        <p className="admin-muted">
          No blocks yet. Add any kind — heading, panel, hero, gallery, columns, tabs, FAQ, pricing, team … the works.
        </p>
      ) : null}
    </div>
  );
}

/** Ensure every section has a stable id (migration safety). */
export function ensureSectionIds(sections: PageSection[]): PageSection[] {
  return sections.map((s) => (s.id ? s : { ...s, id: newSectionId() }));
}

// ===========================================================================
// InsertBlockHere — compact picker that drops a new block at this position.
// Collapsed to a thin "+ Insert here" strip until clicked.
// ===========================================================================

function InsertBlockHere({
  onInsert,
  atEnd = false,
}: {
  onInsert: (kind: PageSection['kind']) => void;
  atEnd?: boolean;
}) {
  const [open, setOpen] = useState(false);
  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="admin-muted"
        style={{
          alignSelf: 'stretch',
          background: 'transparent',
          border: '1px dashed var(--border)',
          borderRadius: 6,
          padding: '4px 8px',
          fontSize: '0.74rem',
          letterSpacing: '0.04em',
          textTransform: 'uppercase',
          cursor: 'pointer',
          opacity: 0.65,
        }}
      >
        + Insert {atEnd ? 'block at end' : 'here'}
      </button>
    );
  }
  return (
    <div
      className="admin-panel"
      style={{ borderStyle: 'dashed', padding: 10, display: 'grid', gap: 8 }}
    >
      <div className="admin-row" style={{ justifyContent: 'space-between' }}>
        <span className="admin-muted" style={{ fontSize: '0.74rem', textTransform: 'uppercase' }}>
          Insert block
        </span>
        <button type="button" onClick={() => setOpen(false)}>Cancel</button>
      </div>
      <div className="admin-row" style={{ flexWrap: 'wrap', gap: 6 }}>
        {(Object.keys(PAGE_BLOCK_LABELS) as PageSection['kind'][]).map((k) => (
          <button
            key={k}
            type="button"
            onClick={() => {
              onInsert(k);
              setOpen(false);
            }}
          >
            {PAGE_BLOCK_LABELS[k]}
          </button>
        ))}
      </div>
    </div>
  );
}

// ===========================================================================
// CtaEditor — small inline editor for `{ label, href, external }` triples.
// Used by hero / cta / pricing / image_text blocks.
// ===========================================================================

function CtaEditor({
  label,
  value,
  onChange,
}: {
  label: string;
  value: { label: string; href: string; external?: boolean } | undefined;
  onChange: (cta: { label: string; href: string; external?: boolean } | undefined) => void;
}) {
  const v = value ?? { label: '', href: '', external: false };
  const update = (patch: Partial<{ label: string; href: string; external: boolean }>) => {
    const next = { ...v, ...patch };
    onChange(next.label || next.href ? next : undefined);
  };
  return (
    <div className="admin-panel" style={{ padding: 10, borderStyle: 'dashed', marginTop: 8 }}>
      <strong className="admin-muted" style={{ fontSize: '0.78rem', textTransform: 'uppercase' }}>
        {label}
      </strong>
      <div className="admin-field">
        <label>Label</label>
        <input value={v.label} onChange={(e) => update({ label: e.target.value })} />
      </div>
      <div className="admin-field">
        <label>URL</label>
        <input
          value={v.href}
          onChange={(e) => update({ href: e.target.value })}
          placeholder={`/p/about, https://…, or ${TIP_LINK_ALIAS} for support link`}
        />
        <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 4 }}>
          Paste <code>{TIP_LINK_ALIAS}</code> to open your Stripe tip link from Site copy — or paste the full{' '}
          <code>https://buy.stripe.com/…</code> URL directly.
        </p>
      </div>
      <label className="admin-row" style={{ gap: 8 }}>
        <input
          type="checkbox"
          checked={v.external ?? false}
          onChange={(e) => update({ external: e.target.checked })}
        />
        External link
      </label>
    </div>
  );
}

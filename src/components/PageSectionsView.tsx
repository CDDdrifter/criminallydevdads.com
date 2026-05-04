import type { PageSection } from '../types';

export function PageSectionsView({ sections }: { sections: PageSection[] }) {
  if (sections.length === 0) {
    return null;
  }

  return (
    <div className="page-sections">
      {sections.map((s) => {
        switch (s.kind) {
          case 'heading':
            return (
              <header key={s.id} className="page-section-heading">
                <h2 className="page-section-title">{s.title}</h2>
                {s.subtitle ? <p className="page-section-subtitle">{s.subtitle}</p> : null}
              </header>
            );
          case 'text':
            return (
              <div key={s.id} className="page-section-text prose">
                <div className="page-section-pre">{s.body}</div>
              </div>
            );
          case 'panel':
            return (
              <section
                key={s.id}
                className={`page-section-panel page-section-panel--${s.variant ?? 'default'}`}
              >
                <h3 className="page-section-panel-title">{s.title}</h3>
                <div className="page-section-panel-body prose">
                  <div className="page-section-pre">{s.body}</div>
                </div>
              </section>
            );
          case 'image':
            return (
              <figure key={s.id} className="page-section-figure">
                {s.url ? (
                  <img src={s.url} alt={s.alt ?? ''} className="page-section-img" />
                ) : (
                  <div className="page-section-img-placeholder">Image URL missing</div>
                )}
                {s.caption ? <figcaption className="page-section-caption">{s.caption}</figcaption> : null}
              </figure>
            );
          case 'video':
            return (
              <figure key={s.id} className="page-section-figure page-section-video-wrap">
                {s.url ? (
                  <video src={s.url} controls playsInline className="page-section-video" />
                ) : (
                  <div className="page-section-img-placeholder">Video URL missing</div>
                )}
                {s.caption ? <figcaption className="page-section-caption">{s.caption}</figcaption> : null}
              </figure>
            );
          case 'divider':
            return <hr key={s.id} className="page-section-divider" />;
          default:
            return null;
        }
      })}
    </div>
  );
}

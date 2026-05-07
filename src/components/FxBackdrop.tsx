/**
 * Full-screen FX layers (fixed z-index). Visibility is driven by `html[data-fx-*]` set in
 * `siteFx.ts` from Site Settings — see `index.css` and `GlobalHtmlFxSync`.
 */
export function FxBackdrop() {
  return (
    <>
      <div className="fx-scanlines" aria-hidden />
      <div className="fx-noise" aria-hidden />
      <div className="fx-vignette" aria-hidden />
    </>
  );
}

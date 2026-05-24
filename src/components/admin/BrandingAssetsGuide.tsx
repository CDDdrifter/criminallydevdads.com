/**
 * Quick reference for every branding asset slot on the site.
 */
export function BrandingAssetsGuide() {
  return (
    <div className="admin-panel" style={{ marginTop: 0 }}>
      <h3 style={{ marginTop: 0 }}>Where each image goes</h3>
      <table className="admin-table" style={{ width: '100%', fontSize: '0.88rem' }}>
        <thead>
          <tr>
            <th>What</th>
            <th>Admin tab</th>
            <th>Used for</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>
              <strong>Browser tab icon</strong>
            </td>
            <td>SEO + Head → Favicon</td>
            <td>Every page (unless a game overrides)</td>
          </tr>
          <tr>
            <td>
              <strong>Home-screen icon</strong>
            </td>
            <td>SEO + Head → Apple touch icon</td>
            <td>iOS / Android “Add to Home Screen”</td>
          </tr>
          <tr>
            <td>
              <strong>Header logo</strong>
            </td>
            <td>Brand + Hero</td>
            <td>Nav bar; fallback favicon if none set</td>
          </tr>
          <tr>
            <td>
              <strong>Social preview</strong>
            </td>
            <td>SEO + Head → OpenGraph image</td>
            <td>Discord, Twitter, link unfurls</td>
          </tr>
          <tr>
            <td>
              <strong>Game cover</strong>
            </td>
            <td>Games → Thumbnail</td>
            <td>Hub cards, game page hero</td>
          </tr>
          <tr>
            <td>
              <strong>Game tab icon</strong>
            </td>
            <td>Games → Browser tab icon</td>
            <td>Tab icon on that game&apos;s detail + play pages only</td>
          </tr>
          <tr>
            <td>
              <strong>Bundled default</strong>
            </td>
            <td>
              <code>public/favicon.svg</code>
            </td>
            <td>Ships with the repo until you upload overrides</td>
          </tr>
        </tbody>
      </table>
      <p className="admin-muted" style={{ marginBottom: 0, marginTop: 12 }}>
        Square PNG or SVG, 32–64px for favicons; 180×180 for home-screen. Uploads go to Supabase Storage
        and save as URLs in site settings or game rows.
      </p>
    </div>
  );
}

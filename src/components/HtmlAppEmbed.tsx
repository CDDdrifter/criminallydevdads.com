import type { SitePage } from '../types';

const SANDBOX_STRICT =
  'allow-scripts allow-forms allow-modals allow-popups allow-downloads allow-pointer-lock';
const SANDBOX_COMPAT = `${SANDBOX_STRICT} allow-same-origin`;

export function htmlAppSandbox(compat: boolean): string {
  return compat ? SANDBOX_COMPAT : SANDBOX_STRICT;
}

/**
 * Runs pasted / exported HTML (Gemini, Claude, etc.) inside an iframe so
 * scripts cannot touch the parent hub shell. Admin trust model — only
 * editors can set `raw_html`.
 */
export function HtmlAppEmbed({ page }: { page: SitePage }) {
  const sandbox = htmlAppSandbox(Boolean(page.html_iframe_compat));
  const html = page.raw_html?.trim() ?? '';
  if (!html) {
    return (
      <div className="empty-state" style={{ marginTop: 16 }}>
        No HTML saved for this app yet. Edit the page in Admin and paste your export.
      </div>
    );
  }
  return (
    <iframe
      title={page.title}
      className="html-app-embed"
      srcDoc={html}
      sandbox={sandbox}
      referrerPolicy="no-referrer"
    />
  );
}

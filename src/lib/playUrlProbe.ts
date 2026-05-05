/**
 * Preflight the exact URL we put in the game iframe. Supabase often returns JSON errors or
 * wrong Content-Types; loading those in an iframe looks like "random script/code" to players.
 */

export type PlayUrlProbeResult =
  | { ok: true; url: string }
  | { ok: false; summary: string; detail: string };

export async function probeGamePlayUrl(url: string): Promise<PlayUrlProbeResult> {
  try {
    const r = await fetch(url, { cache: 'no-store' });
    if (!r.ok) {
      return {
        ok: false,
        summary: `Server returned HTTP ${r.status}`,
        detail:
          r.status === 404
            ? 'Usually: wrong path, file not uploaded, or `storage_entry_in_zip` does not match the folders inside your ZIP. Re-upload the game from Admin or fix the entry path.'
            : 'Open the Play URL in a new tab to see the raw response. Check Supabase → Storage → game-builds → your game folder.',
      };
    }

    const ct = (r.headers.get('content-type') ?? '').split(';')[0]?.trim() ?? '';

    if (/application\/json/i.test(ct)) {
      const t = await r.text();
      return {
        ok: false,
        summary: 'Storage returned JSON instead of a web page',
        detail:
          `This almost always means the object path is wrong (or the bucket is not public).\n\n` +
          `Response snippet:\n${t.slice(0, 600)}${t.length > 600 ? '…' : ''}`,
      };
    }

    const body = await r.text();
    const start = body.slice(0, 800).trimStart().toLowerCase();
    const looksHtml =
      start.startsWith('<!doctype') || start.startsWith('<html') || start.startsWith('<!--');

    if (looksHtml && /text\/plain/i.test(ct)) {
      return {
        ok: false,
        summary: 'HTML is being served as plain text',
        detail:
          'The browser will show source "code" instead of running the game. Re-upload the Web export ZIP from Admin (uploads set Content-Type to text/html).',
      };
    }

    if (/\.supabase\.co\/storage\//i.test(url) && /index\.html/i.test(url)) {
      const ctOk = /text\/html/i.test(ct) || /application\/xhtml\+xml/i.test(ct);
      if (!ctOk && !looksHtml) {
        return {
          ok: false,
          summary: 'This URL is not an HTML page',
          detail: `Content-Type was "${ct || 'unknown'}" and the body did not look like HTML. Re-upload the ZIP or fix which index.html is selected in Admin.`,
        };
      }
    }

    return { ok: true, url };
  } catch (e) {
    return {
      ok: false,
      summary: 'Network error',
      detail: e instanceof Error ? e.message : String(e),
    };
  }
}

/**
 * Preflight the Play iframe URL. Supabase Storage sometimes tags index.html as text/plain;
 * browsers then show source instead of running the game. We can recover by serving HTML from a
 * blob URL with <base href> pointing at the real Storage folder so JS/WASM still load correctly.
 */

export type PlayUrlProbeResult =
  | { ok: true; iframeSrc: string }
  | { ok: false; summary: string; detail: string };

function escapeAttr(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

/** Directory URL ending in / so relative assets (index.js, .wasm) resolve to Storage. */
function storageFolderUrl(fileUrl: string): string {
  return new URL('.', fileUrl).href;
}

export function wrapHtmlWithBaseBlob(html: string, originalIndexUrl: string): string {
  const baseHref = storageFolderUrl(originalIndexUrl);
  let out = html;
  if (/<head[^>]*>/i.test(out)) {
    out = out.replace(/<head([^>]*)>/i, `<head$1><base href="${escapeAttr(baseHref)}">`);
  } else if (/<html[^>]*>/i.test(out)) {
    out = out.replace(/<html([^>]*)>/i, `<html$1><head><base href="${escapeAttr(baseHref)}"></head>`);
  } else {
    out = `<!DOCTYPE html><html><head><base href="${escapeAttr(baseHref)}"></head><body>${out}</body></html>`;
  }
  const blob = new Blob([out], { type: 'text/html;charset=utf-8' });
  return URL.createObjectURL(blob);
}

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

    const ctFull = r.headers.get('content-type') ?? '';
    const ct = ctFull.split(';')[0]?.trim() ?? '';

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

    const htmlMimeOk =
      /text\/html/i.test(ct) || /application\/xhtml\+xml/i.test(ct);

    /**
     * Storage often serves HTML as text/plain or octet-stream. Iframe won’t run it; blob + base fixes Play.
     */
    if (looksHtml && !htmlMimeOk) {
      const iframeSrc = wrapHtmlWithBaseBlob(body, url);
      return { ok: true, iframeSrc };
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

    if (!looksHtml) {
      if (/\.supabase\.co\/storage\//i.test(url) && /index\.html/i.test(url)) {
        return {
          ok: false,
          summary: 'This URL is not an HTML page',
          detail: `Expected HTML at this Storage path. Re-upload the Web export ZIP or check storage_entry_in_zip.`,
        };
      }
      return { ok: true, iframeSrc: url };
    }

    return { ok: true, iframeSrc: url };
  } catch (e) {
    return {
      ok: false,
      summary: 'Network error',
      detail: e instanceof Error ? e.message : String(e),
    };
  }
}

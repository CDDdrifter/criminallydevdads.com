/**
 * Syncs CMS content snapshots to GitHub via Contents API.
 *
 * Request body: { scope?: 'games' | 'content' | 'all' } (default: 'games')
 *
 * - games: writes root games.json
 * - content: writes cms/site-*.json files
 * - all: writes both
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function utf8ToBase64(text: string): string {
  const bytes = new TextEncoder().encode(text);
  let bin = '';
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i]!);
  }
  return btoa(bin);
}

/** Strip accidental `/project/...` paste so Storage URLs match the real API host (same as Vite `normalizeSupabaseProjectUrl`). */
function normalizeSupabaseApiOrigin(raw: string): string {
  const t = raw.trim().replace(/\/$/, '');
  try {
    const u = new URL(t);
    if (u.protocol === 'https:' && u.hostname.endsWith('.supabase.co')) {
      return `https://${u.hostname}`;
    }
  } catch {
    return t;
  }
  return t;
}

/** Same path rules as `publicGameEntryUrl` in the app — must match how games are hosted on Storage. */
function publicGameEntryUrl(baseNoSlash: string, storageSlug: string, entryPath: string): string {
  const slug = encodeURIComponent(storageSlug.trim());
  const entry = entryPath
    .split('/')
    .filter(Boolean)
    .map((seg) => encodeURIComponent(seg))
    .join('/');
  if (!entry) {
    return '';
  }
  return `${baseNoSlash}/storage/v1/object/public/game-builds/${slug}/${entry}`;
}

type Scope = 'games' | 'content' | 'all';

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Use POST' }, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Missing Authorization bearer token' }, 401);
    }
    const requestBody = (await req.json().catch(() => ({}))) as { scope?: Scope };
    const scope: Scope = requestBody.scope === 'content' || requestBody.scope === 'all'
      ? requestBody.scope
      : 'games';

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    if (!supabaseUrl || !supabaseAnonKey) {
      return jsonResponse({ error: 'Missing Supabase env' }, 500);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: isAdmin, error: adminErr } = await userClient.rpc('is_site_admin');
    if (adminErr) {
      return jsonResponse({ error: adminErr.message }, 403);
    }
    if (!isAdmin) {
      return jsonResponse({ error: 'Forbidden — not a site admin' }, 403);
    }

    const token = Deno.env.get('GITHUB_TOKEN');
    const owner = Deno.env.get('GITHUB_OWNER');
    const repo = Deno.env.get('GITHUB_REPO');
    const branch = Deno.env.get('GITHUB_BRANCH') || 'main';

    if (!token || !owner || !repo) {
      return jsonResponse({
        error:
          'Server missing GITHUB_TOKEN, GITHUB_OWNER, or GITHUB_REPO. Set them with: supabase secrets set ...',
      }, 500);
    }

    const ghHeaders = {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
    };

    async function writeFile(path: string, jsonData: unknown, commitMessage: string): Promise<string | null> {
      const json = `${JSON.stringify(jsonData, null, 2)}\n`;
      const content = utf8ToBase64(json);
      const getUrl =
        `https://api.github.com/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}?ref=${encodeURIComponent(branch)}`;
      const getRes = await fetch(getUrl, { headers: ghHeaders });

      let sha: string | undefined;
      if (getRes.ok) {
        const meta = (await getRes.json()) as { sha?: string };
        sha = meta.sha;
      } else if (getRes.status !== 404) {
        const t = await getRes.text();
        throw new Error(`GitHub read ${path}: ${getRes.status} ${t}`);
      }

      const putRes = await fetch(
        `https://api.github.com/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}`,
        {
          method: 'PUT',
          headers: { ...ghHeaders, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: commitMessage,
            content,
            branch,
            ...(sha ? { sha } : {}),
          }),
        },
      );
      if (!putRes.ok) {
        const t = await putRes.text();
        throw new Error(`GitHub write ${path}: ${putRes.status} ${t}`);
      }
      const putData = (await putRes.json()) as { commit?: { html_url?: string } };
      return putData.commit?.html_url ?? null;
    }

    const commits: string[] = [];
    const touchedFiles: string[] = [];
    let gamesSynced: number | undefined;

    if (scope === 'games' || scope === 'all') {
      const { data: rows, error: gamesErr } = await userClient
        .from('site_games')
        .select('*')
        .eq('published', true)
        .order('sort_order', { ascending: true });
      if (gamesErr) {
        return jsonResponse({ error: gamesErr.message }, 500);
      }

      const base = normalizeSupabaseApiOrigin(supabaseUrl);
      const legacyGames = (rows ?? []).map((row) => {
        const slug = String(row.slug ?? '').trim();
        const ext = String(row.external_url ?? '').trim();
        const storageSlug = String(row.storage_slug ?? '').trim();
        const entryInZip = String(row.storage_entry_in_zip ?? '').trim();
        const entryPath = entryInZip || 'index.html';
        let playUrl = '';
        if (storageSlug) {
          playUrl = publicGameEntryUrl(base, storageSlug, entryPath);
        }
        if (!playUrl && ext) {
          playUrl = ext;
        }
        const entry: Record<string, unknown> = {
          id: slug,
          title: row.title,
          type: row.type ?? 'game',
          description: row.description ?? '',
          details: row.details ?? '',
          thumbnail: row.thumbnail_url ?? '',
          filename: `${slug}.zip`,
        };
        const pricingModel = String(row.pricing_model ?? 'free').trim();
        if (pricingModel && pricingModel !== 'free') {
          entry.pricing_model = pricingModel;
        }
        const pc = row.price_cents;
        if (pc != null && Number(pc) > 0) {
          entry.price_cents = Number(pc);
        }
        const pu = String(row.purchase_url ?? '').trim();
        if (pu) {
          entry.purchase_url = pu;
        }
        const priceId = String(row.stripe_price_id ?? '').trim();
        if (priceId) {
          entry.stripe_price_id = priceId;
        }
        const pwywMin = row.pwyw_min_cents;
        if (pwywMin != null && Number(pwywMin) > 0) {
          entry.pwyw_min_cents = Number(pwywMin);
        }
        const pwywSug = row.pwyw_suggested_cents;
        if (pwywSug != null && Number(pwywSug) > 0) {
          entry.pwyw_suggested_cents = Number(pwywSug);
        }
        const presets = row.donation_presets_cents;
        if (Array.isArray(presets) && presets.length > 0) {
          entry.donation_presets_cents = presets;
        }
        const pv = String(row.preview_video_url ?? '').trim();
        if (pv) {
          entry.preview_video = pv;
        }
        if (playUrl) {
          entry.url = playUrl;
          entry.external_url = playUrl;
        }
        return entry;
      });

      gamesSynced = legacyGames.length;
      const commitUrl = await writeFile(
        'games.json',
        legacyGames,
        'chore(cms): sync games.json from Supabase',
      );
      touchedFiles.push('games.json');
      if (commitUrl) commits.push(commitUrl);
    }

    if (scope === 'content' || scope === 'all') {
      const [settingsRes, pagesRes, navRes, devlogsRes] = await Promise.all([
        userClient.from('site_settings').select('*').eq('id', 1).maybeSingle(),
        userClient.from('site_pages').select('*').order('sort_order', { ascending: true }),
        userClient.from('site_nav_items').select('*').order('sort_order', { ascending: true }),
        userClient.from('site_dev_logs').select('*').order('published_at', { ascending: false }),
      ]);
      if (settingsRes.error || pagesRes.error || navRes.error || devlogsRes.error) {
        return jsonResponse({
          error: settingsRes.error?.message ||
            pagesRes.error?.message ||
            navRes.error?.message ||
            devlogsRes.error?.message ||
            'Failed to read CMS content',
        }, 500);
      }

      const snapshot = {
        generated_at: new Date().toISOString(),
        settings: settingsRes.data ?? null,
        pages: pagesRes.data ?? [],
        nav: navRes.data ?? [],
        devlogs: devlogsRes.data ?? [],
      };
      const writes = [
        {
          path: 'cms/site-settings.json',
          data: settingsRes.data ?? {},
          msg: 'chore(cms): sync site settings from Supabase',
        },
        {
          path: 'cms/site-pages.json',
          data: pagesRes.data ?? [],
          msg: 'chore(cms): sync site pages from Supabase',
        },
        {
          path: 'cms/site-nav.json',
          data: navRes.data ?? [],
          msg: 'chore(cms): sync nav from Supabase',
        },
        {
          path: 'cms/site-devlogs.json',
          data: devlogsRes.data ?? [],
          msg: 'chore(cms): sync devlogs from Supabase',
        },
        {
          path: 'cms/site-content.snapshot.json',
          data: snapshot,
          msg: 'chore(cms): sync site content snapshot from Supabase',
        },
      ] as const;
      for (const w of writes) {
        const commitUrl = await writeFile(w.path, w.data, w.msg);
        touchedFiles.push(w.path);
        if (commitUrl) commits.push(commitUrl);
      }
    }

    return jsonResponse({
      ok: true,
      scope,
      games: gamesSynced,
      files: touchedFiles,
      commit_url: commits[commits.length - 1] ?? null,
      commit_urls: commits,
    });
  } catch (e) {
    return jsonResponse({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});

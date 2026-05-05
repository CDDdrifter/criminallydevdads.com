/**
 * Pushes published `site_games` rows to repo root `games.json` via GitHub Contents API.
 *
 * Secrets (set with `supabase secrets set ...`):
 *   GITHUB_TOKEN — classic PAT or fine-grained token with Contents: Read/Write on the repo
 *   GITHUB_OWNER — org or user (e.g. CDDdrifter)
 *   GITHUB_REPO  — repo name (e.g. criminallydevdads.com)
 * Optional: GITHUB_BRANCH (default main)
 *
 * Built-in: SUPABASE_URL, SUPABASE_ANON_KEY (verify caller via is_site_admin RPC).
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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Use POST' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing Authorization bearer token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    if (!supabaseUrl || !supabaseAnonKey) {
      return new Response(JSON.stringify({ error: 'Missing Supabase env' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: isAdmin, error: adminErr } = await userClient.rpc('is_site_admin');
    if (adminErr) {
      return new Response(JSON.stringify({ error: adminErr.message }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (!isAdmin) {
      return new Response(JSON.stringify({ error: 'Forbidden — not a site admin' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: rows, error: gamesErr } = await userClient
      .from('site_games')
      .select('*')
      .eq('published', true)
      .order('sort_order', { ascending: true });

    if (gamesErr) {
      return new Response(JSON.stringify({ error: gamesErr.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const base = supabaseUrl.replace(/\/$/, '');
    const legacyGames = (rows ?? []).map((row) => {
      const slug = String(row.slug ?? '').trim();
      const ext = String(row.external_url ?? '').trim();
      const storageSlug = String(row.storage_slug ?? '').trim();
      const entryInZip = String(row.storage_entry_in_zip ?? '').trim();
      const entryPath = entryInZip || 'index.html';
      /** Match hub precedence: a hosted ZIP build wins over a stale external link. */
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
      const pv = String(row.preview_video_url ?? '').trim();
      if (pv) {
        entry.preview_video = pv;
      }
      /** `url` and `external_url` are both read by the static catalog — set both so tools and humans stay aligned. */
      if (playUrl) {
        entry.url = playUrl;
        entry.external_url = playUrl;
      }
      return entry;
    });

    const json = `${JSON.stringify(legacyGames, null, 2)}\n`;
    const content = utf8ToBase64(json);

    const token = Deno.env.get('GITHUB_TOKEN');
    const owner = Deno.env.get('GITHUB_OWNER');
    const repo = Deno.env.get('GITHUB_REPO');
    const branch = Deno.env.get('GITHUB_BRANCH') || 'main';

    if (!token || !owner || !repo) {
      return new Response(
        JSON.stringify({
          error:
            'Server missing GITHUB_TOKEN, GITHUB_OWNER, or GITHUB_REPO. Set them with: supabase secrets set ...',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const path = 'games.json';
    const ghHeaders = {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
    };

    const getUrl = `https://api.github.com/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}?ref=${encodeURIComponent(branch)}`;
    const getRes = await fetch(getUrl, { headers: ghHeaders });

    let sha: string | undefined;
    if (getRes.ok) {
      const meta = (await getRes.json()) as { sha?: string };
      sha = meta.sha;
    } else if (getRes.status !== 404) {
      const t = await getRes.text();
      return new Response(JSON.stringify({ error: `GitHub read ${path}: ${getRes.status} ${t}` }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const putRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}`, {
      method: 'PUT',
      headers: { ...ghHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'chore(cms): sync games.json from Supabase',
        content,
        branch,
        ...(sha ? { sha } : {}),
      }),
    });

    if (!putRes.ok) {
      const t = await putRes.text();
      return new Response(JSON.stringify({ error: `GitHub write ${path}: ${putRes.status} ${t}` }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const putData = (await putRes.json()) as { commit?: { html_url?: string } };
    return new Response(
      JSON.stringify({
        ok: true,
        games: legacyGames.length,
        commit_url: putData.commit?.html_url ?? null,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

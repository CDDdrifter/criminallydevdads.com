import type { DevLogPost, GameRecord, GameView, NavItem, SitePage, SiteSettings, SupportButton } from '../types';
import { defaultSiteSettings } from '../types';
import { donationPresetsFromUnknown, gamePricingModelFromRecord } from './gamePricing';
import { supabase, supabaseConfigured } from './supabase';
import { normalizePageSections } from './pageSections';
import { publicGameEntryUrl, publicGameIndexUrl } from './gameStorageUpload';
import { fetchStaticJson } from './staticCms';
import { normalizeVisualPresetInput } from './visualPresets';

function normalizeSitePage(row: Record<string, unknown>): SitePage {
  return {
    id: String(row.id),
    slug: String(row.slug),
    title: String(row.title),
    body: String(row.body ?? ''),
    sections: normalizePageSections(row.sections),
    show_in_nav: Boolean(row.show_in_nav ?? true),
    sort_order: Number(row.sort_order ?? 0),
  };
}

function siteSettingsBool(row: Record<string, unknown>, key: string, fallback: boolean): boolean {
  const v = row[key];
  if (typeof v === 'boolean') {
    return v;
  }
  return fallback;
}

function siteSettingsFromRow(row: Record<string, unknown> | null | undefined): SiteSettings | null {
  if (!row || typeof row !== 'object' || Object.keys(row).length === 0) {
    return null;
  }
  const r = row as SiteSettings & { id?: number };
  const raw = row as Record<string, unknown>;
  return {
    hero_title: r.hero_title ?? defaultSiteSettings.hero_title,
    hero_subtitle: r.hero_subtitle ?? defaultSiteSettings.hero_subtitle,
    support_title: r.support_title ?? defaultSiteSettings.support_title,
    support_body: r.support_body ?? defaultSiteSettings.support_body,
    support_page_href: String(raw.support_page_href ?? defaultSiteSettings.support_page_href),
    stripe_donation_url: String(raw.stripe_donation_url ?? ''),
    support_buttons: normalizeSupportButtons(raw.support_buttons),
    footer_text: r.footer_text ?? defaultSiteSettings.footer_text,
    site_visual_preset: normalizeVisualPresetInput(String(raw.site_visual_preset ?? '')),
    fx_scanlines: siteSettingsBool(raw, 'fx_scanlines', defaultSiteSettings.fx_scanlines),
    fx_noise: siteSettingsBool(raw, 'fx_noise', defaultSiteSettings.fx_noise),
    fx_vignette: siteSettingsBool(raw, 'fx_vignette', defaultSiteSettings.fx_vignette),
    fx_hue_shift: siteSettingsBool(raw, 'fx_hue_shift', defaultSiteSettings.fx_hue_shift),
    fx_cursor_spotlight: siteSettingsBool(raw, 'fx_cursor_spotlight', defaultSiteSettings.fx_cursor_spotlight),
  };
}

function normalizeSupportButtons(raw: unknown): SupportButton[] {
  if (!Array.isArray(raw)) {
    return defaultSiteSettings.support_buttons;
  }
  const out: SupportButton[] = [];
  for (let i = 0; i < raw.length; i++) {
    const item = raw[i];
    if (!item || typeof item !== 'object') continue;
    const rec = item as Record<string, unknown>;
    /**
     * Keep user edits even when fields are partially filled.
     * Older behavior dropped incomplete buttons, which looked like “Save didn’t work”.
     */
    const id = String(rec.id ?? '').trim() || `btn-${i + 1}`;
    const label = String(rec.label ?? '').trim();
    const href = String(rec.href ?? '').trim();
    out.push({
      id,
      label,
      href,
      external: Boolean(rec.external),
      variant: rec.variant === 'primary' ? 'primary' : 'secondary',
    });
  }
  return out;
}

/** Maps DB row → hub `GameView` (play URL resolution + commerce fields for GamePurchaseBlock). */
function recordToView(g: GameRecord): GameView {
  const folder = g.local_folder ?? g.slug;
  const localPath = `games/${folder}/index.html`;
  const ext = g.external_url?.trim();
  const storageSlug = g.storage_slug?.trim();
  const entryInZip = g.storage_entry_in_zip?.trim();
  const storageUrl = storageSlug
    ? publicGameEntryUrl(storageSlug, entryInZip || 'index.html') || publicGameIndexUrl(storageSlug)
    : '';

  /**
   * If this row is a cloud ZIP game (`storage_slug`), never fall back to `games/<slug>/index.html` unless
   * we truly have no Storage URL (misbuilt site) — that fallback often 404s into the SPA shell and looks like “code”.
   * Storage URL must use the same normalized origin as the Supabase client (see `publicGameEntryUrl`).
   */
  let launchPath = localPath;
  if (storageSlug) {
    if (storageUrl) {
      launchPath = storageUrl;
    } else if (ext) {
      launchPath = ext;
    }
  } else if (ext) {
    launchPath = ext;
  }

  const priceCents = Math.max(0, Number(g.price_cents ?? 0));
  return {
    id: g.id,
    slug: g.slug,
    title: g.title,
    type: g.type,
    description: g.description ?? '',
    details: g.details ?? '',
    thumbnail: g.thumbnail_url ?? '',
    preview_video: g.preview_video_url ?? '',
    external_url: g.external_url ?? '',
    local_folder: folder,
    launchPath,
    isPlayable: Boolean(ext) || Boolean(storageUrl) || Boolean(folder),
    sections: normalizePageSections(g.sections as unknown),
    visual_preset: normalizeVisualPresetInput(g.visual_preset),
    pricing_model: gamePricingModelFromRecord(g.pricing_model, priceCents),
    price_cents: priceCents,
    purchase_url: String(g.purchase_url ?? '').trim(),
    stripe_price_id: String(g.stripe_price_id ?? '').trim(),
    pwyw_min_cents: Math.max(0, Number(g.pwyw_min_cents ?? 0)),
    pwyw_suggested_cents: Math.max(0, Number(g.pwyw_suggested_cents ?? 0)),
    donation_presets_cents: donationPresetsFromUnknown(g.donation_presets_cents),
  };
}

export async function fetchPublishedGames(): Promise<GameView[]> {
  if (!supabaseConfigured || !supabase) {
    return [];
  }
  const { data, error } = await supabase
    .from('site_games')
    .select('*')
    .eq('published', true)
    .order('sort_order', { ascending: true });
  if (error) {
    console.error(error);
    return [];
  }
  const rows = data ?? [];
  return rows.map(recordToView);
}

export async function fetchAllGamesAdmin(): Promise<GameRecord[]> {
  if (!supabase) {
    return [];
  }
  const { data, error } = await supabase.from('site_games').select('*').order('sort_order');
  if (error) {
    console.error(error);
    return [];
  }
  return data ?? [];
}

export async function upsertGame(row: Partial<GameRecord> & { slug: string; title: string }) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const payload: Record<string, unknown> = { ...row };
  // Backward-compatible writes: if DB schema lags behind frontend fields, retry without unknown columns.
  for (let attempt = 0; attempt < 4; attempt++) {
    const { error } = await supabase.from('site_games').upsert(payload, { onConflict: 'slug' });
    if (!error) {
      return;
    }
    const msg = error.message ?? '';
    const unknown = msg.match(/column\s+"?([a-zA-Z0-9_]+)"?\s+of relation/i)?.[1];
    if (!unknown || !(unknown in payload)) {
      throw error;
    }
    delete payload[unknown];
  }
  throw new Error('Could not save game row due to schema mismatch in site_games.');
}

export async function deleteGameBySlug(slug: string) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const { error } = await supabase.from('site_games').delete().eq('slug', slug);
  if (error) {
    throw error;
  }
}

export async function fetchPageBySlug(slug: string): Promise<SitePage | null> {
  const staticPages = await fetchStaticJson<unknown[]>('cms/site-pages.json');
  if (Array.isArray(staticPages)) {
    const row = staticPages.find((p) => typeof p === 'object' && p && String((p as Record<string, unknown>).slug) === slug);
    if (row && typeof row === 'object') {
      return normalizeSitePage(row as Record<string, unknown>);
    }
  }
  if (!supabaseConfigured || !supabase) {
    return null;
  }
  const { data, error } = await supabase
    .from('site_pages')
    .select('*')
    .eq('slug', slug)
    .maybeSingle();
  if (error) {
    console.error(error);
    return null;
  }
  return data ? normalizeSitePage(data as Record<string, unknown>) : null;
}

export async function fetchSitePages(): Promise<SitePage[]> {
  const staticPages = await fetchStaticJson<unknown[]>('cms/site-pages.json');
  if (Array.isArray(staticPages) && staticPages.length > 0) {
    return staticPages
      .filter((p): p is Record<string, unknown> => Boolean(p && typeof p === 'object'))
      .map(normalizeSitePage);
  }
  if (!supabaseConfigured || !supabase) {
    return [];
  }
  const { data, error } = await supabase
    .from('site_pages')
    .select('*')
    .order('sort_order', { ascending: true });
  if (error) {
    console.error(error);
    return [];
  }
  const rows = data ?? [];
  return rows.map(normalizeSitePage);
}

export async function fetchNavItems(): Promise<NavItem[]> {
  const staticNav = await fetchStaticJson<NavItem[]>('cms/site-nav.json');
  if (Array.isArray(staticNav) && staticNav.length > 0) {
    return staticNav;
  }
  if (!supabaseConfigured || !supabase) {
    return [];
  }
  const { data, error } = await supabase
    .from('site_nav_items')
    .select('*')
    .order('sort_order', { ascending: true });
  if (error) {
    console.error(error);
    return [];
  }
  return data ?? [];
}

export async function fetchDevLogBySlug(slug: string): Promise<DevLogPost | null> {
  const staticLogs = await fetchStaticJson<DevLogPost[]>('cms/site-devlogs.json');
  if (Array.isArray(staticLogs)) {
    const hit = staticLogs.find((p) => p.slug === slug);
    if (hit) {
      return hit;
    }
  }
  if (!supabaseConfigured || !supabase) {
    return null;
  }
  const { data, error } = await supabase
    .from('site_dev_logs')
    .select('*')
    .eq('slug', slug)
    .maybeSingle();
  if (error) {
    console.error(error);
    return null;
  }
  return data as DevLogPost | null;
}

export async function fetchDevLogs(): Promise<DevLogPost[]> {
  if (!supabaseConfigured || !supabase) {
    return [];
  }
  const { data, error } = await supabase
    .from('site_dev_logs')
    .select('*')
    .order('published_at', { ascending: false });
  if (error) {
    console.error(error);
    return [];
  }
  return data ?? [];
}

export async function fetchSiteSettings(): Promise<SiteSettings> {
  const staticRow = await fetchStaticJson<Record<string, unknown>>('cms/site-settings.json');
  const fromStatic = siteSettingsFromRow(staticRow);
  if (fromStatic) {
    return fromStatic;
  }
  if (!supabaseConfigured || !supabase) {
    return defaultSiteSettings;
  }
  const { data, error } = await supabase.from('site_settings').select('*').eq('id', 1).maybeSingle();
  if (error || !data) {
    return defaultSiteSettings;
  }
  return siteSettingsFromRow(data as Record<string, unknown>) ?? defaultSiteSettings;
}

export async function saveSiteSettings(patch: Partial<SiteSettings>) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const current = await fetchSiteSettings();
  const merged = { ...current, ...patch };
  const payload: Record<string, unknown> = {
    id: 1,
    hero_title: merged.hero_title,
    hero_subtitle: merged.hero_subtitle,
    support_title: merged.support_title,
    support_body: merged.support_body,
    support_page_href: merged.support_page_href,
    stripe_donation_url: merged.stripe_donation_url,
    support_buttons: merged.support_buttons,
    footer_text: merged.footer_text,
    site_visual_preset: normalizeVisualPresetInput(merged.site_visual_preset) || null,
    fx_scanlines: merged.fx_scanlines,
    fx_noise: merged.fx_noise,
    fx_vignette: merged.fx_vignette,
    fx_hue_shift: merged.fx_hue_shift,
    fx_cursor_spotlight: merged.fx_cursor_spotlight,
  };
  for (let attempt = 0; attempt < 8; attempt++) {
    const { error } = await supabase.from('site_settings').upsert(payload);
    if (!error) {
      return;
    }
    const msg = error.message ?? '';
    const unknown = msg.match(/column\s+"?([a-zA-Z0-9_]+)"?\s+of relation/i)?.[1];
    if (!unknown || !(unknown in payload)) {
      throw error;
    }
    delete payload[unknown];
  }
  throw new Error('Could not save site_settings (schema mismatch — run latest supabase/schema.sql or migrations).');
}

export async function fetchAllPagesAdmin(): Promise<SitePage[]> {
  if (!supabase) {
    return [];
  }
  const { data, error } = await supabase.from('site_pages').select('*').order('sort_order');
  if (error) {
    console.error(error);
    return [];
  }
  return (data as Record<string, unknown>[]).map(normalizeSitePage);
}

export async function upsertPage(row: Partial<SitePage> & { slug: string; title: string }) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const { error } = await supabase.from('site_pages').upsert(row, { onConflict: 'slug' });
  if (error) {
    throw error;
  }
}

export async function deletePageSlug(slug: string) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const { error } = await supabase.from('site_pages').delete().eq('slug', slug);
  if (error) {
    throw error;
  }
}

export async function fetchAllNavAdmin(): Promise<NavItem[]> {
  if (!supabase) {
    return [];
  }
  const { data, error } = await supabase.from('site_nav_items').select('*').order('sort_order');
  if (error) {
    console.error(error);
    return [];
  }
  return data ?? [];
}

export async function upsertNav(row: Partial<NavItem> & { label: string; href: string }) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const payload = {
    id: row.id ?? crypto.randomUUID(),
    label: row.label,
    href: row.href,
    external: row.external ?? false,
    sort_order: row.sort_order ?? 0,
  };
  const { error } = await supabase.from('site_nav_items').upsert(payload, { onConflict: 'id' });
  if (error) {
    throw error;
  }
}

export async function deleteNavId(id: string) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const { error } = await supabase.from('site_nav_items').delete().eq('id', id);
  if (error) {
    throw error;
  }
}

export async function fetchAllDevLogsAdmin(): Promise<DevLogPost[]> {
  if (!supabase) {
    return [];
  }
  const { data, error } = await supabase.from('site_dev_logs').select('*').order('published_at', {
    ascending: false,
  });
  if (error) {
    console.error(error);
    return [];
  }
  return data ?? [];
}

export async function upsertDevLog(
  row: Partial<DevLogPost> & { slug: string; title: string; body: string },
) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const { error } = await supabase.from('site_dev_logs').upsert(row, { onConflict: 'slug' });
  if (error) {
    throw error;
  }
}

export async function deleteDevLogSlug(slug: string) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const { error } = await supabase.from('site_dev_logs').delete().eq('slug', slug);
  if (error) {
    throw error;
  }
}

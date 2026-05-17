import type {
  AccessibilityConfig,
  AnimationsConfig,
  AudioConfig,
  BehaviorConfig,
  BrandingConfig,
  ComponentsConfig,
  CursorConfig,
  DevLogPost,
  EffectsConfig,
  FxIntensity,
  GameCardsConfig,
  GameRecord,
  GameView,
  HeroConfig,
  LayoutConfig,
  NavItem,
  ParticlesConfig,
  PerformanceConfig,
  SeoConfig,
  SharingConfig,
  SitePage,
  SiteSettings,
  SocialConfig,
  SupportButton,
  ThemeConfig,
  ThemePreset,
  TypographyConfig,
} from '../types';
import { defaultSiteSettings } from '../types';
import {
  defaultAccessibilityConfig,
  defaultAnimationsConfig,
  defaultAudioConfig,
  defaultBehaviorConfig,
  defaultBrandingConfig,
  defaultComponentsConfig,
  defaultCursorConfig,
  defaultEffectsConfig,
  defaultGameCardsConfig,
  defaultHeroConfig,
  defaultLayoutConfig,
  defaultParticlesConfig,
  defaultPerformanceConfig,
  defaultSeoConfig,
  defaultSharingConfig,
  defaultSocialConfig,
  defaultThemeConfig,
  defaultTypographyConfig,
} from './themeDefaults';
import { donationPresetsFromUnknown, gamePricingModelFromRecord } from './gamePricing';
import { supabase, supabaseConfigured } from './supabase';
import { normalizePageSections } from './pageSections';
import { publicGameEntryUrl, publicGameIndexUrl } from './gameStorageUpload';
import { fetchStaticJson } from './staticCms';
import { normalizePromoEvents } from './promoEvents';
import { normalizeRouteFxOverride } from './routeFx';
import { normalizeVisualPresetInput } from './visualPresets';
import { unknownColumnFromPostgrestMessage } from './postgrestUnknownColumn';

// ---------------------------------------------------------------------------
// Studio config normalization helpers.
//
// Each studio config is stored as a JSONB blob in `site_settings`. When the
// CMS row was written before migration 016 (or simply omits a field), we want
// to fall back to the canonical defaults from `themeDefaults.ts` so the front
// end never crashes on a missing key.
//
// `mergeDeep` is intentionally shallow-per-key — JSONB studio configs are
// nested but never reach more than 2-3 levels deep, and we don't want to
// silently merge arrays. Top-level objects are merged; primitives + arrays
// from the source overwrite the destination.
// ---------------------------------------------------------------------------
function mergeDeep<T>(defaults: T, override: unknown): T {
  if (!override || typeof override !== 'object' || Array.isArray(override)) {
    return defaults;
  }
  if (!defaults || typeof defaults !== 'object') {
    return (override as T) ?? defaults;
  }
  const out: Record<string, unknown> = { ...(defaults as Record<string, unknown>) };
  for (const [k, v] of Object.entries(override as Record<string, unknown>)) {
    const dv = (defaults as Record<string, unknown>)[k];
    if (v && typeof v === 'object' && !Array.isArray(v) && dv && typeof dv === 'object' && !Array.isArray(dv)) {
      out[k] = mergeDeep(dv, v);
    } else if (v !== undefined && v !== null) {
      out[k] = v;
    }
  }
  return out as T;
}

function normalizeThemePresets(raw: unknown): ThemePreset[] {
  if (!Array.isArray(raw)) return [];
  const out: ThemePreset[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const r = item as Record<string, unknown>;
    const id = String(r.id ?? '').trim();
    const name = String(r.name ?? '').trim() || 'Untitled preset';
    if (!id) continue;
    const themeBlob = r.theme as Record<string, unknown> | undefined;
    if (!themeBlob || typeof themeBlob !== 'object') continue;
    const themeBase = defaultThemeConfig();
    out.push({
      id,
      name,
      description: String(r.description ?? ''),
      theme: {
        display_name: String((themeBlob as { display_name?: unknown }).display_name ?? name),
        colors: mergeDeep(themeBase.colors, (themeBlob as { colors?: unknown }).colors),
        background: mergeDeep(themeBase.background, (themeBlob as { background?: unknown }).background),
      },
    });
  }
  return out;
}

function normalizeFxIntensity(raw: unknown): FxIntensity {
  const s = String(raw ?? '').toLowerCase();
  if (s === 'subtle' || s === 'intense') {
    return s;
  }
  return 'normal';
}

function normalizeSitePage(row: Record<string, unknown>): SitePage {
  const pageMode = row.page_mode === 'html_app' ? 'html_app' : 'blocks';
  return {
    id: String(row.id),
    slug: String(row.slug),
    title: String(row.title),
    body: String(row.body ?? ''),
    sections: normalizePageSections(row.sections),
    show_in_nav: Boolean(row.show_in_nav ?? true),
    sort_order: Number(row.sort_order ?? 0),
    visual_preset: normalizeVisualPresetInput(String(row.visual_preset ?? '')) || null,
    immersive_layout: Boolean(row.immersive_layout ?? false),
    custom_mood_css: String(row.custom_mood_css ?? ''),
    page_mode: pageMode,
    raw_html: String(row.raw_html ?? ''),
    unlisted: Boolean(row.unlisted),
    show_on_apps_hub: row.show_on_apps_hub !== false,
    html_app_summary: String(row.html_app_summary ?? ''),
    html_iframe_compat: Boolean(row.html_iframe_compat),
    route_fx: normalizeRouteFxOverride(row.route_fx),
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
    fx_intensity: normalizeFxIntensity(raw.fx_intensity),
    promo_events: normalizePromoEvents(raw.promo_events),
    custom_css: String(raw.custom_css ?? defaultSiteSettings.custom_css),
    theme: mergeDeep<ThemeConfig>(defaultThemeConfig(), raw.theme),
    effects: mergeDeep<EffectsConfig>(defaultEffectsConfig(), raw.effects),
    typography: mergeDeep<TypographyConfig>(defaultTypographyConfig(), raw.typography),
    layout: mergeDeep<LayoutConfig>(defaultLayoutConfig(), raw.layout),
    components: mergeDeep<ComponentsConfig>(defaultComponentsConfig(), raw.components),
    behavior: mergeDeep<BehaviorConfig>(defaultBehaviorConfig(), raw.behavior),
    seo: mergeDeep<SeoConfig>(defaultSeoConfig(), raw.seo),
    custom_head_html: String(raw.custom_head_html ?? ''),
    theme_presets: normalizeThemePresets(raw.theme_presets),
    // Studio expansion (migration 017).
    animations: mergeDeep<AnimationsConfig>(defaultAnimationsConfig(), raw.animations),
    audio: mergeDeep<AudioConfig>(defaultAudioConfig(), raw.audio),
    cursor: mergeDeep<CursorConfig>(defaultCursorConfig(), raw.cursor),
    particles: mergeDeep<ParticlesConfig>(defaultParticlesConfig(), raw.particles),
    social: mergeDeep<SocialConfig>(defaultSocialConfig(), raw.social),
    hero: mergeDeep<HeroConfig>(defaultHeroConfig(), raw.hero),
    game_cards: mergeDeep<GameCardsConfig>(defaultGameCardsConfig(), raw.game_cards),
    branding: mergeDeep<BrandingConfig>(defaultBrandingConfig(), raw.branding),
    performance: mergeDeep<PerformanceConfig>(defaultPerformanceConfig(), raw.performance),
    accessibility: mergeDeep<AccessibilityConfig>(defaultAccessibilityConfig(), raw.accessibility),
    sharing: mergeDeep<SharingConfig>(defaultSharingConfig(), raw.sharing),
    // Admin-driven homepage (migration 018).
    homepage_sections: normalizePageSections(raw.homepage_sections),
    homepage_layout_mode:
      raw.homepage_layout_mode === 'prepend' || raw.homepage_layout_mode === 'replace'
        ? raw.homepage_layout_mode
        : 'append',
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
    gumroad_url: String(g.gumroad_url ?? '').trim(),
    stripe_price_id: String(g.stripe_price_id ?? '').trim(),
    pwyw_min_cents: Math.max(0, Number(g.pwyw_min_cents ?? 0)),
    pwyw_suggested_cents: Math.max(0, Number(g.pwyw_suggested_cents ?? 0)),
    donation_presets_cents: donationPresetsFromUnknown(g.donation_presets_cents),
    in_vault: Boolean(g.in_vault ?? false),
    immersive_layout: Boolean(g.immersive_layout ?? false),
    custom_mood_css: String(g.custom_mood_css ?? '').trim(),
    route_fx: normalizeRouteFxOverride(g.route_fx),
    // ---- Game-page enrichment (migration 018) -----------------------------
    tags: Array.isArray(g.tags) ? (g.tags as unknown[]).map(String).filter(Boolean) : [],
    release_date: String(g.release_date ?? '').trim(),
    platforms: Array.isArray(g.platforms)
      ? (g.platforms as unknown[]).map(String).filter(Boolean)
      : [],
    screenshots: Array.isArray(g.screenshots)
      ? (g.screenshots as unknown[]).map(String).filter(Boolean)
      : [],
    features: Array.isArray(g.features)
      ? (g.features as unknown[]).map(String).filter(Boolean)
      : [],
    controls: normalizeGameExtras(g.controls, ['key', 'desc']) as { id: string; key: string; desc: string }[],
    credits: normalizeGameExtras(g.credits, ['role', 'name'], ['href']) as { id: string; role: string; name: string; href?: string }[],
    changelog: normalizeGameExtras(g.changelog, ['version', 'notes'], ['date']) as { id: string; version: string; notes: string; date?: string }[],
    system_requirements: Array.isArray(g.system_requirements)
      ? (g.system_requirements as unknown[]).map(String).filter(Boolean)
      : [],
  };
}

/**
 * Tiny helper to coerce a raw JSONB list of `{key, value, …}` rows into
 * `{id, …}` entries used by the controls / credits / changelog editors.
 * Drops entries missing required fields rather than crashing the page.
 */
function normalizeGameExtras(
  raw: unknown,
  required: string[],
  optional: string[] = [],
): Record<string, string>[] {
  if (!Array.isArray(raw)) return [];
  const out: Record<string, string>[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const rec = item as Record<string, unknown>;
    const ok = required.every((k) => typeof rec[k] === 'string' && (rec[k] as string).length > 0);
    if (!ok) continue;
    const entry: Record<string, string> = {
      id: typeof rec.id === 'string' && rec.id ? rec.id : crypto.randomUUID(),
    };
    for (const k of required) entry[k] = String(rec[k]);
    for (const k of optional) {
      if (typeof rec[k] === 'string') entry[k] = String(rec[k]);
    }
    out.push(entry);
  }
  return out;
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

/** Games flagged for the vault library (<code>/#/vault</code>). */
export async function fetchVaultGames(): Promise<GameView[]> {
  if (!supabaseConfigured || !supabase) {
    return [];
  }
  const { data, error } = await supabase
    .from('site_games')
    .select('*')
    .eq('in_vault', true)
    .order('sort_order', { ascending: true });
  if (error) {
    console.error(error);
    return [];
  }
  const rows = data ?? [];
  return rows.map(recordToView);
}

/** Single game for detail/play routes (hub, vault, or admin-visible draft). */
export async function fetchGameViewBySlug(slug: string): Promise<GameView | null> {
  if (!slug.trim() || !supabaseConfigured || !supabase) {
    return null;
  }
  const { data, error } = await supabase.from('site_games').select('*').eq('slug', slug.trim()).maybeSingle();
  if (error) {
    console.error(error);
    return null;
  }
  if (!data) {
    return null;
  }
  return recordToView(data as GameRecord);
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
  return (data ?? []).map((row) => {
    const r = row as Record<string, unknown>;
    return {
      ...(row as GameRecord),
      route_fx: normalizeRouteFxOverride(r.route_fx),
    };
  });
}

export async function upsertGame(row: Partial<GameRecord> & { slug: string; title: string }) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const payload: Record<string, unknown> = { ...row };
  // Backward-compatible writes: if DB schema lags behind frontend fields, retry without unknown columns.
  for (let attempt = 0; attempt < 16; attempt++) {
    const { error } = await supabase.from('site_games').upsert(payload, { onConflict: 'slug' });
    if (!error) {
      return;
    }
    const msg = error.message ?? '';
    const unknown = unknownColumnFromPostgrestMessage(msg);
    if (!unknown || !(unknown in payload)) {
      throw error;
    }
    delete payload[unknown];
  }
  throw new Error('Could not save game row after column retries (run 014_ensure_admin_write_schema.sql).');
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
  if (supabaseConfigured && supabase) {
    const { data, error } = await supabase
      .from('site_pages')
      .select('*')
      .eq('slug', slug)
      .maybeSingle();
    if (!error && data) {
      return normalizeSitePage(data as Record<string, unknown>);
    }
    if (error) {
      console.error(error);
    }
  }
  const staticPages = await fetchStaticJson<unknown[]>('cms/site-pages.json');
  if (Array.isArray(staticPages)) {
    const row = staticPages.find((p) => typeof p === 'object' && p && String((p as Record<string, unknown>).slug) === slug);
    if (row && typeof row === 'object') {
      return normalizeSitePage(row as Record<string, unknown>);
    }
  }
  return null;
}

export async function fetchSitePages(): Promise<SitePage[]> {
  if (supabaseConfigured && supabase) {
    const { data, error } = await supabase
      .from('site_pages')
      .select('*')
      .order('sort_order', { ascending: true });
    if (!error) {
      const rows = data ?? [];
      return rows.map(normalizeSitePage);
    }
    console.error(error);
  }
  const staticPages = await fetchStaticJson<unknown[]>('cms/site-pages.json');
  if (Array.isArray(staticPages) && staticPages.length > 0) {
    return staticPages
      .filter((p): p is Record<string, unknown> => Boolean(p && typeof p === 'object'))
      .map(normalizeSitePage);
  }
  return [];
}

export async function fetchNavItems(): Promise<NavItem[]> {
  if (supabaseConfigured && supabase) {
    const { data, error } = await supabase
      .from('site_nav_items')
      .select('*')
      .order('sort_order', { ascending: true });
    if (!error) {
      return data ?? [];
    }
    console.error(error);
  }
  const staticNav = await fetchStaticJson<NavItem[]>('cms/site-nav.json');
  if (Array.isArray(staticNav) && staticNav.length > 0) {
    return staticNav;
  }
  return [];
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
  if (supabaseConfigured && supabase) {
    const { data, error } = await supabase.from('site_settings').select('*').eq('id', 1).maybeSingle();
    if (!error && data) {
      return siteSettingsFromRow(data as Record<string, unknown>) ?? defaultSiteSettings;
    }
    if (error) {
      console.error(error);
    }
  }
  const staticRow = await fetchStaticJson<Record<string, unknown>>('cms/site-settings.json');
  const fromStatic = siteSettingsFromRow(staticRow);
  if (fromStatic) {
    return fromStatic;
  }
  return defaultSiteSettings;
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
    fx_intensity: normalizeFxIntensity(merged.fx_intensity),
    promo_events: merged.promo_events,
    custom_css: merged.custom_css,
    // Studio columns (migration 016). The retry loop below silently drops
    // any of these if the DB hasn't been migrated yet, so this is forward-
    // compatible without forcing the user to run the SQL immediately.
    theme: merged.theme,
    effects: merged.effects,
    typography: merged.typography,
    layout: merged.layout,
    components: merged.components,
    behavior: merged.behavior,
    seo: merged.seo,
    custom_head_html: merged.custom_head_html,
    theme_presets: merged.theme_presets,
    // Studio expansion (migration 017). Unknown columns drop on retry.
    animations: merged.animations,
    audio: merged.audio,
    cursor: merged.cursor,
    particles: merged.particles,
    social: merged.social,
    hero: merged.hero,
    game_cards: merged.game_cards,
    branding: merged.branding,
    performance: merged.performance,
    accessibility: merged.accessibility,
    sharing: merged.sharing,
    homepage_sections: merged.homepage_sections,
    homepage_layout_mode: merged.homepage_layout_mode,
  };
  for (let attempt = 0; attempt < 16; attempt++) {
    const { error } = await supabase.from('site_settings').upsert(payload);
    if (!error) {
      return;
    }
    const msg = error.message ?? '';
    const unknown = unknownColumnFromPostgrestMessage(msg);
    if (!unknown || !(unknown in payload)) {
      throw error;
    }
    delete payload[unknown];
  }
  throw new Error('Could not save site_settings after column retries (run 014_ensure_admin_write_schema.sql).');
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
  const payload: Record<string, unknown> = {
    slug: row.slug.trim(),
    title: row.title.trim(),
    body: row.body ?? '',
    sections: row.sections ?? [],
    show_in_nav: row.show_in_nav ?? true,
    sort_order: Number(row.sort_order ?? 0),
    visual_preset: normalizeVisualPresetInput(String(row.visual_preset ?? '')) || null,
    immersive_layout: Boolean(row.immersive_layout ?? false),
    custom_mood_css: String(row.custom_mood_css ?? ''),
    page_mode: row.page_mode === 'html_app' ? 'html_app' : 'blocks',
    raw_html: String(row.raw_html ?? ''),
    unlisted: Boolean(row.unlisted),
    show_on_apps_hub: row.show_on_apps_hub !== false,
    html_app_summary: String(row.html_app_summary ?? ''),
    html_iframe_compat: Boolean(row.html_iframe_compat),
    route_fx: row.route_fx ?? normalizeRouteFxOverride(null),
  };
  for (let attempt = 0; attempt < 48; attempt++) {
    const { error } = await supabase.from('site_pages').upsert(payload, { onConflict: 'slug' });
    if (!error) {
      return;
    }
    const msg = error.message ?? '';
    const unknown = unknownColumnFromPostgrestMessage(msg);
    if (!unknown || !(unknown in payload)) {
      throw error;
    }
    delete payload[unknown];
  }
  throw new Error('Could not save site_pages row after column retries (run 014_ensure_admin_write_schema.sql).');
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
  const publishedAt =
    typeof row.published_at === 'string' && row.published_at.trim()
      ? row.published_at.trim()
      : new Date().toISOString();
  const payload: Record<string, unknown> = {
    slug: row.slug.trim(),
    title: row.title.trim(),
    body: row.body ?? '',
    published_at: publishedAt,
  };
  const { error } = await supabase.from('site_dev_logs').upsert(payload, { onConflict: 'slug' });
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

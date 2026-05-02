import type { DevLogPost, GameRecord, GameView, NavItem, SitePage, SiteSettings } from '../types';
import { defaultSiteSettings } from '../types';
import { supabase, supabaseConfigured } from './supabase';
import { normalizePageSections } from './pageSections';

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

function recordToView(g: GameRecord): GameView {
  const folder = g.local_folder ?? g.slug;
  const localPath = `games/${folder}/index.html`;
  const hasExternal = Boolean(g.external_url?.trim());
  return {
    id: g.id,
    slug: g.slug,
    title: g.title,
    type: g.type,
    description: g.description ?? '',
    details: g.details ?? '',
    thumbnail: g.thumbnail_url ?? '',
    external_url: g.external_url ?? '',
    local_folder: folder,
    launchPath: hasExternal ? (g.external_url as string) : localPath,
    isPlayable: hasExternal || Boolean(folder),
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
  return (data as GameRecord[]).map(recordToView);
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
  return data as GameRecord[];
}

export async function upsertGame(row: Partial<GameRecord> & { slug: string; title: string }) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const { error } = await supabase.from('site_games').upsert(row, { onConflict: 'slug' });
  if (error) {
    throw error;
  }
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
  return (data as Record<string, unknown>[]).map(normalizeSitePage);
}

export async function fetchNavItems(): Promise<NavItem[]> {
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
  return data as NavItem[];
}

export async function fetchDevLogBySlug(slug: string): Promise<DevLogPost | null> {
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
  return data as DevLogPost[];
}

export async function fetchSiteSettings(): Promise<SiteSettings> {
  if (!supabaseConfigured || !supabase) {
    return defaultSiteSettings;
  }
  const { data, error } = await supabase.from('site_settings').select('*').eq('id', 1).maybeSingle();
  if (error || !data) {
    return defaultSiteSettings;
  }
  const row = data as SiteSettings & { id: number };
  return {
    hero_title: row.hero_title ?? defaultSiteSettings.hero_title,
    hero_subtitle: row.hero_subtitle ?? defaultSiteSettings.hero_subtitle,
    support_title: row.support_title ?? defaultSiteSettings.support_title,
    support_body: row.support_body ?? defaultSiteSettings.support_body,
    footer_text: row.footer_text ?? defaultSiteSettings.footer_text,
  };
}

export async function saveSiteSettings(patch: Partial<SiteSettings>) {
  if (!supabase) {
    throw new Error('Supabase not configured');
  }
  const current = await fetchSiteSettings();
  const merged = { ...current, ...patch };
  const { error } = await supabase.from('site_settings').upsert({
    id: 1,
    hero_title: merged.hero_title,
    hero_subtitle: merged.hero_subtitle,
    support_title: merged.support_title,
    support_body: merged.support_body,
    footer_text: merged.footer_text,
  });
  if (error) {
    throw error;
  }
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
  return data as NavItem[];
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
  return data as DevLogPost[];
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

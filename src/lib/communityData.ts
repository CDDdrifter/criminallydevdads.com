/**
 * Public community layer: profiles, comments, cloud game saves, analytics summary.
 */
import { supabase } from './supabase';

export type CommentTargetType = 'game' | 'page' | 'devlog';

export type SiteProfile = {
  id: string;
  display_name: string;
  avatar_url: string;
  created_at: string;
  updated_at: string;
};

export type SiteComment = {
  id: string;
  user_id: string;
  target_type: CommentTargetType;
  target_key: string;
  body: string;
  created_at: string;
  updated_at: string;
  profile?: Pick<SiteProfile, 'display_name' | 'avatar_url'>;
};

export type SiteGameSave = {
  user_id: string;
  game_slug: string;
  save_data: Record<string, unknown>;
  updated_at: string;
};

export type AnalyticsSummary = {
  since: string;
  days_back: number;
  total_events: number;
  page_views: number;
  game_plays: number;
  sign_ins: number;
  unique_sessions: number;
  signed_in_users: number;
  comments_posted: number;
  registered_profiles: number;
  top_paths: { path: string; views: number }[];
  top_games: { game_slug: string; plays: number }[];
};

export async function ensureProfile(userId: string, meta?: { name?: string; avatar?: string }) {
  if (!supabase) return null;
  const display_name = meta?.name?.trim() || 'Player';
  const avatar_url = meta?.avatar?.trim() || '';
  const { data, error } = await supabase
    .from('site_profiles')
    .upsert(
      { id: userId, display_name, avatar_url, updated_at: new Date().toISOString() },
      { onConflict: 'id' },
    )
    .select()
    .single();
  if (error) {
    console.warn('[profile] upsert failed', error.message);
    return null;
  }
  return data as SiteProfile;
}

export async function fetchProfile(userId: string): Promise<SiteProfile | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.from('site_profiles').select('*').eq('id', userId).maybeSingle();
  if (error || !data) return null;
  return data as SiteProfile;
}

export async function fetchComments(
  targetType: CommentTargetType,
  targetKey: string,
): Promise<SiteComment[]> {
  if (!supabase) return [];
  const { data: rows, error } = await supabase
    .from('site_comments')
    .select('*')
    .eq('target_type', targetType)
    .eq('target_key', targetKey)
    .order('created_at', { ascending: true });
  if (error || !rows?.length) return [];

  const userIds = [...new Set(rows.map((r) => r.user_id as string))];
  const { data: profiles } = await supabase
    .from('site_profiles')
    .select('id, display_name, avatar_url')
    .in('id', userIds);

  const byId = new Map((profiles ?? []).map((p) => [p.id as string, p]));

  return (rows as SiteComment[]).map((c) => ({
    ...c,
    profile: byId.get(c.user_id)
      ? {
          display_name: String(byId.get(c.user_id)!.display_name),
          avatar_url: String(byId.get(c.user_id)!.avatar_url ?? ''),
        }
      : { display_name: 'Player', avatar_url: '' },
  }));
}

export async function postComment(
  userId: string,
  targetType: CommentTargetType,
  targetKey: string,
  body: string,
): Promise<{ ok: true; comment: SiteComment } | { ok: false; error: string }> {
  if (!supabase) return { ok: false, error: 'Supabase not configured' };
  const trimmed = body.trim();
  if (!trimmed) return { ok: false, error: 'Comment cannot be empty.' };
  if (trimmed.length > 4000) return { ok: false, error: 'Comment is too long (max 4000 characters).' };

  const { data, error } = await supabase
    .from('site_comments')
    .insert({
      user_id: userId,
      target_type: targetType,
      target_key: targetKey,
      body: trimmed,
    })
    .select()
    .single();

  if (error) return { ok: false, error: error.message };
  return { ok: true, comment: data as SiteComment };
}

export async function deleteComment(commentId: string): Promise<boolean> {
  if (!supabase) return false;
  const { error } = await supabase.from('site_comments').delete().eq('id', commentId);
  return !error;
}

export async function loadGameSave(userId: string, gameSlug: string): Promise<Record<string, unknown> | null> {
  if (!supabase) return null;
  const { data, error } = await supabase
    .from('site_game_saves')
    .select('save_data')
    .eq('user_id', userId)
    .eq('game_slug', gameSlug)
    .maybeSingle();
  if (error || !data) return null;
  return (data.save_data as Record<string, unknown>) ?? {};
}

export async function saveGameSave(
  userId: string,
  gameSlug: string,
  saveData: Record<string, unknown>,
): Promise<boolean> {
  if (!supabase) return false;
  const { error } = await supabase.from('site_game_saves').upsert(
    {
      user_id: userId,
      game_slug: gameSlug,
      save_data: saveData,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,game_slug' },
  );
  return !error;
}

export async function listUserGameSaves(userId: string): Promise<SiteGameSave[]> {
  if (!supabase) return [];
  const { data, error } = await supabase
    .from('site_game_saves')
    .select('*')
    .eq('user_id', userId)
    .order('updated_at', { ascending: false });
  if (error || !data) return [];
  return data as SiteGameSave[];
}

export async function fetchAnalyticsSummary(daysBack = 30): Promise<AnalyticsSummary | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('get_site_analytics_summary', { days_back: daysBack });
  if (error) {
    console.error('[analytics] summary RPC failed', error);
    return null;
  }
  return data as AnalyticsSummary;
}

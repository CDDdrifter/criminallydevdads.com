/**
 * Public community layer: profiles, comments, cloud game saves, analytics summary.
 */
import { supabase } from './supabase';

export type CommentTargetType = 'game' | 'page' | 'devlog';

export type SiteProfile = {
  id: string;
  display_name: string;
  avatar_url: string;
  /** Unique public handle (lowercase, 3–32 chars). */
  username: string;
  mailing_list_opt_in: boolean;
  mailing_list_opted_in_at: string | null;
  created_at: string;
  updated_at: string;
};

export type MailingListPreviewRow = {
  email: string;
  display_name: string;
  username: string;
  opted_in_at: string | null;
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
  /** Raw counts per `event_type` in the window (page_view, game_play, …). */
  events_by_type: Record<string, number>;
  top_paths: { path: string; views: number }[];
  top_games: { game_slug: string; plays: number }[];
  /** HTML mini-apps / sandbox pages tracked as `app_open`. */
  top_app_opens: { app_key: string; opens: number }[];
};

export async function ensureProfile(userId: string, meta?: { name?: string; avatar?: string }) {
  if (!supabase) return null;
  const display_name = meta?.name?.trim() || 'Player';
  const avatar_url = meta?.avatar?.trim() || '';
  const existing = await fetchProfile(userId);
  if (existing) {
    const { data, error } = await supabase
      .from('site_profiles')
      .update({ display_name, avatar_url, updated_at: new Date().toISOString() })
      .eq('id', userId)
      .select()
      .single();
    if (error) {
      console.warn('[profile] update failed', error.message);
      return existing;
    }
    return data as SiteProfile;
  }

  const { data: bootUname, error: rpcErr } = await supabase.rpc('bootstrap_my_username');
  if (rpcErr) {
    console.warn('[profile] bootstrap_my_username', rpcErr.message);
  }
  let username =
    typeof bootUname === 'string' && bootUname.length >= 3 ? bootUname : `u_${userId.replace(/-/g, '').slice(0, 12)}`;
  username = username.slice(0, 32);

  const { data, error } = await supabase
    .from('site_profiles')
    .insert({
      id: userId,
      display_name,
      avatar_url,
      username,
      mailing_list_opt_in: false,
      updated_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (error) {
    if (error.code === '23505') {
      const { data: merged } = await supabase
        .from('site_profiles')
        .update({ display_name, avatar_url, updated_at: new Date().toISOString() })
        .eq('id', userId)
        .select()
        .single();
      return (merged as SiteProfile) ?? null;
    }
    console.warn('[profile] insert failed', error.message);
    return null;
  }
  return data as SiteProfile;
}

const USERNAME_RE = /^[a-z][a-z0-9_]{2,31}$/;

export async function isUsernameAvailable(
  candidate: string,
  forUserId: string | null,
): Promise<boolean | null> {
  if (!supabase) return null;
  const u = candidate.trim().toLowerCase();
  if (!USERNAME_RE.test(u)) return false;
  const { data, error } = await supabase.rpc('is_username_available', {
    p_username: u,
    p_for_user_id: forUserId,
  });
  if (error) {
    console.warn('[profile] is_username_available', error.message);
    return null;
  }
  return data === true;
}

export async function updateMyProfile(
  userId: string,
  patch: {
    display_name?: string;
    username?: string;
    mailing_list_opt_in?: boolean;
  },
): Promise<{ ok: true; profile: SiteProfile } | { ok: false; error: string }> {
  if (!supabase) return { ok: false, error: 'Supabase not configured' };

  const updates: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };

  if (patch.display_name !== undefined) {
    const n = patch.display_name.trim();
    if (!n) return { ok: false, error: 'Display name cannot be empty.' };
    updates.display_name = n;
  }

  if (patch.username !== undefined) {
    const u = patch.username.trim().toLowerCase();
    if (!USERNAME_RE.test(u)) {
      return {
        ok: false,
        error: 'Username must be 3–32 characters, start with a letter, then letters, numbers, or underscores only.',
      };
    }
    const { data: avail, error: aErr } = await supabase.rpc('is_username_available', {
      p_username: u,
      p_for_user_id: userId,
    });
    if (aErr) return { ok: false, error: aErr.message };
    if (avail !== true) return { ok: false, error: 'That username is already taken.' };
    updates.username = u;
  }

  if (patch.mailing_list_opt_in !== undefined) {
    updates.mailing_list_opt_in = patch.mailing_list_opt_in;
    updates.mailing_list_opted_in_at = patch.mailing_list_opt_in ? new Date().toISOString() : null;
  }

  if (Object.keys(updates).length <= 1) {
    const cur = await fetchProfile(userId);
    if (!cur) return { ok: false, error: 'No profile.' };
    return { ok: true, profile: cur };
  }

  const { data, error } = await supabase
    .from('site_profiles')
    .update(updates)
    .eq('id', userId)
    .select()
    .single();

  if (error || !data) {
    return { ok: false, error: error?.message ?? 'Update failed' };
  }
  return { ok: true, profile: data as SiteProfile };
}

export async function adminMailingListCount(): Promise<number | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc('admin_mailing_list_count');
  if (error || typeof data !== 'number') {
    console.warn('[mailing] count', error?.message);
    return null;
  }
  return data;
}

export async function adminMailingListPreview(limit = 80): Promise<MailingListPreviewRow[]> {
  if (!supabase) return [];
  const { data, error } = await supabase.rpc('admin_mailing_list_preview', { p_limit: limit });
  if (error || !Array.isArray(data)) {
    console.warn('[mailing] preview', error?.message);
    return [];
  }
  return data as MailingListPreviewRow[];
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
  const raw = data as Record<string, unknown>;
  const byType = raw.events_by_type;
  const opens = raw.top_app_opens;
  return {
    ...(data as AnalyticsSummary),
    events_by_type: byType && typeof byType === 'object' && !Array.isArray(byType) ? (byType as Record<string, number>) : {},
    top_app_opens: Array.isArray(opens) ? (opens as AnalyticsSummary['top_app_opens']) : [],
  };
}

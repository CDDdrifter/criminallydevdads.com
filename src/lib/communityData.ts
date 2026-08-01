/**
 * Public community layer: profiles, comments, cloud game saves, analytics summary.
 * Backed by Firebase Firestore (replaces Supabase).
 */
import { auth, isFirebaseReady } from './firebase';
import {
  bootstrapUsername,
  ensureFirestore,
  firestoreAddComment,
  firestoreAdminListComments,
  firestoreAdminListServiceRequests,
  firestoreAnalyticsSummary,
  firestoreDeleteComment,
  firestoreGetProfile,
  firestoreIsUsernameAvailable,
  firestoreListComments,
  firestoreListProfiles,
  firestoreListUserGameSaves,
  firestoreLoadGameSave,
  firestoreMailingListCount,
  firestoreMailingListPreview,
  firestoreSaveGameSave,
  firestoreSubmitServiceRequest,
  firestoreUpsertProfile,
} from './firestoreData';

export type CommentTargetType = 'game' | 'page' | 'devlog';

export type SiteProfile = {
  id: string;
  display_name: string;
  avatar_url: string;
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

export type GameAnalyticsRow = {
  game_slug: string;
  game_title: string;
  plays: number;
  page_views: number;
  comments: number;
  unique_sessions: number;
};

export type AdminCommentRow = {
  id: string;
  user_id: string;
  target_type: string;
  target_key: string;
  body: string;
  created_at: string;
  display_name: string;
  username: string;
  author_email: string;
};

export type AdminProfileRow = {
  id: string;
  email: string;
  display_name: string;
  username: string;
  mailing_list_opt_in: boolean;
  mailing_list_opted_in_at: string | null;
  created_at: string;
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
  events_by_type: Record<string, number>;
  top_paths: { path: string; views: number }[];
  top_games: { game_slug: string; plays: number }[];
  top_app_opens: { app_key: string; opens: number }[];
  game_analytics: GameAnalyticsRow[];
};

function asProfile(row: Record<string, unknown>): SiteProfile {
  return {
    id: String(row.id ?? ''),
    display_name: String(row.display_name ?? 'Player'),
    avatar_url: String(row.avatar_url ?? ''),
    username: String(row.username ?? ''),
    mailing_list_opt_in: Boolean(row.mailing_list_opt_in ?? false),
    mailing_list_opted_in_at: row.mailing_list_opted_in_at ? String(row.mailing_list_opted_in_at) : null,
    created_at: String(row.created_at ?? new Date().toISOString()),
    updated_at: String(row.updated_at ?? new Date().toISOString()),
  };
}

export async function ensureProfile(userId: string, meta?: { name?: string; avatar?: string; email?: string }) {
  if (!(await ensureFirestore())) return null;
  const display_name = meta?.name?.trim() || 'Player';
  const avatar_url = meta?.avatar?.trim() || '';
  const email = meta?.email?.trim() || auth?.currentUser?.email || '';
  const existing = await fetchProfile(userId);
  if (existing) {
    return asProfile(
      await firestoreUpsertProfile(userId, { display_name, avatar_url, email: email || existing.id }),
    );
  }

  let username = bootstrapUsername(userId);
  const available = await firestoreIsUsernameAvailable(username, userId);
  if (!available) {
    username = `${bootstrapUsername(userId)}_${Math.random().toString(36).slice(2, 6)}`;
  }

  return asProfile(
    await firestoreUpsertProfile(userId, {
      display_name,
      avatar_url,
      username,
      email,
      mailing_list_opt_in: false,
    }),
  );
}

const USERNAME_RE = /^[a-z][a-z0-9_]{2,31}$/;

export async function isUsernameAvailable(
  candidate: string,
  forUserId: string | null,
): Promise<boolean | null> {
  if (!(await ensureFirestore())) return null;
  const u = candidate.trim().toLowerCase();
  if (!USERNAME_RE.test(u)) return false;
  return firestoreIsUsernameAvailable(u, forUserId);
}

export async function updateMyProfile(
  userId: string,
  patch: {
    display_name?: string;
    username?: string;
    mailing_list_opt_in?: boolean;
  },
): Promise<{ ok: true; profile: SiteProfile } | { ok: false; error: string }> {
  if (!(await ensureFirestore())) return { ok: false, error: 'Firebase not configured' };

  const updates: Record<string, unknown> = {};

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
    const avail = await firestoreIsUsernameAvailable(u, userId);
    if (!avail) return { ok: false, error: 'That username is already taken.' };
    updates.username = u;
  }

  if (patch.mailing_list_opt_in !== undefined) {
    updates.mailing_list_opt_in = patch.mailing_list_opt_in;
    updates.mailing_list_opted_in_at = patch.mailing_list_opt_in ? new Date().toISOString() : null;
  }

  if (Object.keys(updates).length === 0) {
    const cur = await fetchProfile(userId);
    if (!cur) return { ok: false, error: 'No profile.' };
    return { ok: true, profile: cur };
  }

  const data = await firestoreUpsertProfile(userId, updates);
  return { ok: true, profile: asProfile(data) };
}

export async function adminMailingListCount(): Promise<number | null> {
  if (!(await ensureFirestore())) return null;
  return firestoreMailingListCount();
}

export async function adminMailingListPreview(limit = 80): Promise<MailingListPreviewRow[]> {
  if (!(await ensureFirestore())) return [];
  const rows = await firestoreMailingListPreview(limit);
  return rows as MailingListPreviewRow[];
}

export async function fetchProfile(userId: string): Promise<SiteProfile | null> {
  if (!(await ensureFirestore())) return null;
  const row = await firestoreGetProfile(userId);
  if (!row) return null;
  return asProfile(row);
}

export async function fetchComments(
  targetType: CommentTargetType,
  targetKey: string,
): Promise<SiteComment[]> {
  if (!(await ensureFirestore())) return [];
  const rows = await firestoreListComments(targetType, targetKey);
  if (!rows.length) return [];

  const userIds = [...new Set(rows.map((r) => String(r.user_id)))];
  const profiles = await Promise.all(userIds.map((id) => firestoreGetProfile(id)));
  const byId = new Map(
    profiles.filter(Boolean).map((p) => [String(p!.id), p!]),
  );

  return rows.map((c) => ({
    id: String(c.id),
    user_id: String(c.user_id),
    target_type: c.target_type as CommentTargetType,
    target_key: String(c.target_key),
    body: String(c.body),
    created_at: String(c.created_at),
    updated_at: String(c.updated_at ?? c.created_at),
    profile: byId.get(String(c.user_id))
      ? {
          display_name: String(byId.get(String(c.user_id))!.display_name),
          avatar_url: String(byId.get(String(c.user_id))!.avatar_url ?? ''),
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
  if (!(await ensureFirestore())) return { ok: false, error: 'Firebase not configured' };
  const trimmed = body.trim();
  if (!trimmed) return { ok: false, error: 'Comment cannot be empty.' };
  if (trimmed.length > 4000) return { ok: false, error: 'Comment is too long (max 4000 characters).' };

  const data = await firestoreAddComment({
    user_id: userId,
    target_type: targetType,
    target_key: targetKey,
    body: trimmed,
  });
  return {
    ok: true,
    comment: {
      id: String(data.id),
      user_id: userId,
      target_type: targetType,
      target_key: targetKey,
      body: trimmed,
      created_at: String(data.created_at),
      updated_at: String(data.updated_at),
    },
  };
}

export async function deleteComment(commentId: string): Promise<boolean> {
  if (!(await ensureFirestore())) return false;
  try {
    await firestoreDeleteComment(commentId);
    return true;
  } catch {
    return false;
  }
}

export async function loadGameSave(userId: string, gameSlug: string): Promise<Record<string, unknown> | null> {
  if (await ensureFirestore()) {
    const data = await firestoreLoadGameSave(userId, gameSlug);
    if (data) return data;
  }
  try {
    const raw = localStorage.getItem(`cdd_save_${userId}_${gameSlug}`);
    return raw ? (JSON.parse(raw) as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

export async function saveGameSave(
  userId: string,
  gameSlug: string,
  saveData: Record<string, unknown>,
): Promise<boolean> {
  if (await ensureFirestore()) {
    try {
      await firestoreSaveGameSave(userId, gameSlug, saveData);
      return true;
    } catch {
      // fall through to localStorage
    }
  }
  try {
    localStorage.setItem(`cdd_save_${userId}_${gameSlug}`, JSON.stringify(saveData));
    return true;
  } catch {
    return false;
  }
}

export async function listUserGameSaves(userId: string): Promise<SiteGameSave[]> {
  if (!(await ensureFirestore())) return [];
  const rows = await firestoreListUserGameSaves(userId);
  return rows.map((r) => ({
    user_id: String(r.user_id),
    game_slug: String(r.game_slug),
    save_data: (r.save_data as Record<string, unknown>) ?? {},
    updated_at: String(r.updated_at ?? ''),
  }));
}

export async function fetchAnalyticsSummary(daysBack = 30): Promise<AnalyticsSummary | null> {
  if (!(await ensureFirestore())) return null;
  const raw = await firestoreAnalyticsSummary(daysBack);
  if (!raw) return null;
  return {
    ...(raw as AnalyticsSummary),
    events_by_type:
      raw.events_by_type && typeof raw.events_by_type === 'object' && !Array.isArray(raw.events_by_type)
        ? (raw.events_by_type as Record<string, number>)
        : {},
    top_app_opens: Array.isArray(raw.top_app_opens) ? (raw.top_app_opens as AnalyticsSummary['top_app_opens']) : [],
    game_analytics: Array.isArray(raw.game_analytics) ? (raw.game_analytics as GameAnalyticsRow[]) : [],
  };
}

export async function adminListComments(
  limit = 200,
  daysBack = 365,
): Promise<AdminCommentRow[]> {
  if (!(await ensureFirestore())) return [];
  const rows = await firestoreAdminListComments(limit, daysBack);
  const enriched: AdminCommentRow[] = [];
  for (const c of rows) {
    const profile = await firestoreGetProfile(String(c.user_id));
    enriched.push({
      id: String(c.id),
      user_id: String(c.user_id),
      target_type: String(c.target_type),
      target_key: String(c.target_key),
      body: String(c.body),
      created_at: String(c.created_at),
      display_name: String(profile?.display_name ?? 'Player'),
      username: String(profile?.username ?? ''),
      author_email: String(profile?.email ?? ''),
    });
  }
  return enriched;
}

export type ServiceRequestRow = {
  id: string;
  service_slug: string | null;
  service_title: string;
  contact_name: string;
  contact_email: string;
  message: string;
  budget_note: string;
  status: string;
  created_at: string;
};

export async function submitServiceRequest(args: {
  serviceSlug?: string;
  contactName: string;
  contactEmail: string;
  message: string;
  budgetNote?: string;
  userId?: string | null;
}): Promise<{ ok: true } | { ok: false; error: string }> {
  if (!(await ensureFirestore())) return { ok: false, error: 'Firebase not configured' };
  const email = args.contactEmail.trim();
  const message = args.message.trim();
  if (!email.includes('@')) return { ok: false, error: 'Enter a valid email.' };
  if (message.length < 10) return { ok: false, error: 'Tell us a bit more (at least 10 characters).' };

  try {
    await firestoreSubmitServiceRequest({
      service_slug: args.serviceSlug?.trim() || null,
      contact_name: args.contactName.trim(),
      contact_email: email,
      message,
      budget_note: (args.budgetNote ?? '').trim(),
      user_id: args.userId ?? null,
    });
    return { ok: true };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : 'Submit failed' };
  }
}

export async function adminListServiceRequests(limit = 100): Promise<ServiceRequestRow[]> {
  if (!(await ensureFirestore())) return [];
  const rows = await firestoreAdminListServiceRequests(limit);
  return rows.map((r) => ({
    id: String(r.id),
    service_slug: r.service_slug ? String(r.service_slug) : null,
    service_title: String(r.service_title ?? r.service_slug ?? ''),
    contact_name: String(r.contact_name ?? ''),
    contact_email: String(r.contact_email ?? ''),
    message: String(r.message ?? ''),
    budget_note: String(r.budget_note ?? ''),
    status: String(r.status ?? 'new'),
    created_at: String(r.created_at ?? ''),
  }));
}

export async function adminListRecentProfiles(limit = 200): Promise<AdminProfileRow[]> {
  if (!(await ensureFirestore())) return [];
  const rows = await firestoreListProfiles(limit);
  return rows.map((r) => ({
    id: String(r.id),
    email: String(r.email ?? ''),
    display_name: String(r.display_name ?? ''),
    username: String(r.username ?? ''),
    mailing_list_opt_in: Boolean(r.mailing_list_opt_in ?? false),
    mailing_list_opted_in_at: r.mailing_list_opted_in_at ? String(r.mailing_list_opted_in_at) : null,
    created_at: String(r.created_at ?? ''),
  }));
}

/** Whether community/backend features are available. */
export function communityBackendReady(): boolean {
  return isFirebaseReady();
}

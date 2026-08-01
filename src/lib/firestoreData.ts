/**
 * Firestore data layer — replaces Supabase Postgres for website CMS + community features.
 * Games stay in games.json / games/ folder (not Firestore).
 */
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  where,
  type DocumentData,
  type QueryConstraint,
} from 'firebase/firestore';
import { db, initFirebase, isFirebaseReady } from './firebase';

export const COL = {
  siteSettings: 'site_settings',
  sitePages: 'site_pages',
  siteNav: 'site_nav_items',
  siteDevLogs: 'site_dev_logs',
  siteServices: 'site_services',
  profiles: 'profiles',
  comments: 'comments',
  gameSaves: 'game_saves',
  analyticsEvents: 'analytics_events',
  serviceRequests: 'service_requests',
} as const;

const SETTINGS_DOC = 'main';

export async function ensureFirestore(): Promise<boolean> {
  if (isFirebaseReady() && db) {
    return true;
  }
  return initFirebase();
}

function firestore() {
  if (!db) {
    throw new Error('Firestore not initialized');
  }
  return db;
}

function ts(): string {
  return new Date().toISOString();
}

function saveDocId(userId: string, gameSlug: string): string {
  return `${userId}__${gameSlug}`;
}

// ---------------------------------------------------------------------------
// Site settings (single document)
// ---------------------------------------------------------------------------

export async function firestoreGetSiteSettings(): Promise<Record<string, unknown> | null> {
  if (!(await ensureFirestore())) return null;
  const snap = await getDoc(doc(firestore(), COL.siteSettings, SETTINGS_DOC));
  if (!snap.exists()) return null;
  return snap.data() as Record<string, unknown>;
}

export async function firestoreSaveSiteSettings(data: Record<string, unknown>): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await setDoc(
    doc(firestore(), COL.siteSettings, SETTINGS_DOC),
    { ...data, id: 1, updated_at: ts() },
    { merge: true },
  );
}

// ---------------------------------------------------------------------------
// Site pages
// ---------------------------------------------------------------------------

export async function firestoreListPages(): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const q = query(collection(firestore(), COL.sitePages), orderBy('sort_order', 'asc'));
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

export async function firestoreGetPageBySlug(slug: string): Promise<Record<string, unknown> | null> {
  if (!(await ensureFirestore())) return null;
  const snap = await getDoc(doc(firestore(), COL.sitePages, slug));
  if (!snap.exists()) return null;
  return { id: snap.id, ...snap.data() };
}

export async function firestoreUpsertPage(slug: string, data: Record<string, unknown>): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await setDoc(doc(firestore(), COL.sitePages, slug), { ...data, slug, updated_at: ts() }, { merge: true });
}

export async function firestoreDeletePage(slug: string): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await deleteDoc(doc(firestore(), COL.sitePages, slug));
}

// ---------------------------------------------------------------------------
// Nav items
// ---------------------------------------------------------------------------

export async function firestoreListNav(): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const q = query(collection(firestore(), COL.siteNav), orderBy('sort_order', 'asc'));
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

export async function firestoreUpsertNav(id: string, data: Record<string, unknown>): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await setDoc(doc(firestore(), COL.siteNav, id), { ...data, id, updated_at: ts() }, { merge: true });
}

export async function firestoreDeleteNav(id: string): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await deleteDoc(doc(firestore(), COL.siteNav, id));
}

// ---------------------------------------------------------------------------
// Dev logs
// ---------------------------------------------------------------------------

export async function firestoreListDevLogs(): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const q = query(collection(firestore(), COL.siteDevLogs), orderBy('published_at', 'desc'));
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ slug: d.id, ...d.data() }));
}

export async function firestoreGetDevLogBySlug(slug: string): Promise<Record<string, unknown> | null> {
  if (!(await ensureFirestore())) return null;
  const snap = await getDoc(doc(firestore(), COL.siteDevLogs, slug));
  if (!snap.exists()) return null;
  return { slug: snap.id, ...snap.data() };
}

export async function firestoreUpsertDevLog(slug: string, data: Record<string, unknown>): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await setDoc(doc(firestore(), COL.siteDevLogs, slug), { ...data, slug, updated_at: ts() }, { merge: true });
}

export async function firestoreDeleteDevLog(slug: string): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await deleteDoc(doc(firestore(), COL.siteDevLogs, slug));
}

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

export async function firestoreListServices(publishedOnly = false): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const constraints: QueryConstraint[] = [orderBy('sort_order', 'asc')];
  if (publishedOnly) {
    constraints.unshift(where('published', '==', true));
  }
  const q = query(collection(firestore(), COL.siteServices), ...constraints);
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ slug: d.id, ...d.data() }));
}

export async function firestoreGetServiceBySlug(slug: string): Promise<Record<string, unknown> | null> {
  if (!(await ensureFirestore())) return null;
  const snap = await getDoc(doc(firestore(), COL.siteServices, slug));
  if (!snap.exists()) return null;
  return { slug: snap.id, ...snap.data() };
}

export async function firestoreUpsertService(slug: string, data: Record<string, unknown>): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await setDoc(doc(firestore(), COL.siteServices, slug), { ...data, slug, updated_at: ts() }, { merge: true });
}

export async function firestoreDeleteService(slug: string): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await deleteDoc(doc(firestore(), COL.siteServices, slug));
}

// ---------------------------------------------------------------------------
// Profiles
// ---------------------------------------------------------------------------

export async function firestoreGetProfile(userId: string): Promise<Record<string, unknown> | null> {
  if (!(await ensureFirestore())) return null;
  const snap = await getDoc(doc(firestore(), COL.profiles, userId));
  if (!snap.exists()) return null;
  return { id: snap.id, ...snap.data() };
}

export async function firestoreUpsertProfile(userId: string, data: Record<string, unknown>): Promise<Record<string, unknown>> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  const ref = doc(firestore(), COL.profiles, userId);
  const existing = await getDoc(ref);
  const now = ts();
  const payload = {
    ...data,
    id: userId,
    updated_at: now,
    created_at: existing.exists() ? (existing.data().created_at as string) ?? now : now,
  };
  await setDoc(ref, payload, { merge: true });
  return payload;
}

export async function firestoreIsUsernameAvailable(candidate: string, forUserId: string | null): Promise<boolean> {
  if (!(await ensureFirestore())) return false;
  const q = query(collection(firestore(), COL.profiles), where('username', '==', candidate), limit(1));
  const snap = await getDocs(q);
  if (snap.empty) return true;
  if (forUserId && snap.docs[0]!.id === forUserId) return true;
  return false;
}

export async function firestoreListProfiles(limitN = 200): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const q = query(collection(firestore(), COL.profiles), orderBy('created_at', 'desc'), limit(limitN));
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

export async function firestoreMailingListCount(): Promise<number> {
  if (!(await ensureFirestore())) return 0;
  const q = query(collection(firestore(), COL.profiles), where('mailing_list_opt_in', '==', true));
  const snap = await getDocs(q);
  return snap.size;
}

export async function firestoreMailingListPreview(limitN = 80): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const q = query(
    collection(firestore(), COL.profiles),
    where('mailing_list_opt_in', '==', true),
    orderBy('mailing_list_opted_in_at', 'desc'),
    limit(limitN),
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => {
    const data = d.data();
    return {
      email: String(data.email ?? ''),
      display_name: String(data.display_name ?? ''),
      username: String(data.username ?? ''),
      opted_in_at: data.mailing_list_opted_in_at ?? null,
    };
  });
}

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

export async function firestoreListComments(
  targetType: string,
  targetKey: string,
): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const q = query(
    collection(firestore(), COL.comments),
    where('target_type', '==', targetType),
    where('target_key', '==', targetKey),
    orderBy('created_at', 'asc'),
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

export async function firestoreAddComment(data: Record<string, unknown>): Promise<Record<string, unknown>> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  const now = ts();
  const ref = await addDoc(collection(firestore(), COL.comments), {
    ...data,
    created_at: now,
    updated_at: now,
  });
  return { id: ref.id, ...data, created_at: now, updated_at: now };
}

export async function firestoreDeleteComment(commentId: string): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await deleteDoc(doc(firestore(), COL.comments, commentId));
}

export async function firestoreAdminListComments(limitN = 200, daysBack = 365): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const since = new Date(Date.now() - daysBack * 86400000).toISOString();
  const q = query(
    collection(firestore(), COL.comments),
    where('created_at', '>=', since),
    orderBy('created_at', 'desc'),
    limit(limitN),
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

// ---------------------------------------------------------------------------
// Game saves
// ---------------------------------------------------------------------------

export async function firestoreLoadGameSave(
  userId: string,
  gameSlug: string,
): Promise<Record<string, unknown> | null> {
  if (!(await ensureFirestore())) return null;
  const snap = await getDoc(doc(firestore(), COL.gameSaves, saveDocId(userId, gameSlug)));
  if (!snap.exists()) return null;
  const data = snap.data();
  return (data.save_data as Record<string, unknown>) ?? {};
}

export async function firestoreSaveGameSave(
  userId: string,
  gameSlug: string,
  saveData: Record<string, unknown>,
): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await setDoc(doc(firestore(), COL.gameSaves, saveDocId(userId, gameSlug)), {
    user_id: userId,
    game_slug: gameSlug,
    save_data: saveData,
    updated_at: ts(),
  });
}

export async function firestoreListUserGameSaves(userId: string): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const q = query(
    collection(firestore(), COL.gameSaves),
    where('user_id', '==', userId),
    orderBy('updated_at', 'desc'),
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => d.data());
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

export async function firestoreTrackEvent(payload: Record<string, unknown>): Promise<void> {
  if (!(await ensureFirestore())) return;
  await addDoc(collection(firestore(), COL.analyticsEvents), {
    ...payload,
    created_at: ts(),
  });
}

export async function firestoreAnalyticsSummary(daysBack = 30): Promise<Record<string, unknown> | null> {
  if (!(await ensureFirestore())) return null;
  const since = new Date(Date.now() - daysBack * 86400000).toISOString();
  const q = query(
    collection(firestore(), COL.analyticsEvents),
    where('created_at', '>=', since),
    orderBy('created_at', 'desc'),
    limit(10000),
  );
  const snap = await getDocs(q);
  const events = snap.docs.map((d) => d.data());

  const eventsByType: Record<string, number> = {};
  const pathCounts = new Map<string, number>();
  const gamePlays = new Map<string, number>();
  const appOpens = new Map<string, number>();
  const sessions = new Set<string>();
  const signedInUsers = new Set<string>();
  let pageViews = 0;
  let gamePlayCount = 0;
  let signIns = 0;
  let commentsPosted = 0;

  for (const e of events) {
    const type = String(e.event_type ?? '');
    eventsByType[type] = (eventsByType[type] ?? 0) + 1;
    const sid = String(e.session_id ?? '');
    if (sid) sessions.add(sid);
    const uid = e.user_id ? String(e.user_id) : '';
    if (uid) signedInUsers.add(uid);

    if (type === 'page_view') {
      pageViews++;
      const path = String(e.path ?? '');
      pathCounts.set(path, (pathCounts.get(path) ?? 0) + 1);
    } else if (type === 'game_play') {
      gamePlayCount++;
      const slug = String(e.target_key ?? '');
      gamePlays.set(slug, (gamePlays.get(slug) ?? 0) + 1);
    } else if (type === 'sign_in') {
      signIns++;
    } else if (type === 'comment_post') {
      commentsPosted++;
    } else if (type === 'app_open') {
      const key = String(e.target_key ?? '');
      appOpens.set(key, (appOpens.get(key) ?? 0) + 1);
    }
  }

  const topPaths = [...pathCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .map(([path, views]) => ({ path, views }));

  const topGames = [...gamePlays.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .map(([game_slug, plays]) => ({ game_slug, plays }));

  const topAppOpens = [...appOpens.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .map(([app_key, opens]) => ({ app_key, opens }));

  let registeredProfiles = 0;
  try {
    const profilesSnap = await getDocs(collection(firestore(), COL.profiles));
    registeredProfiles = profilesSnap.size;
  } catch {
    registeredProfiles = 0;
  }

  return {
    since,
    days_back: daysBack,
    total_events: events.length,
    page_views: pageViews,
    game_plays: gamePlayCount,
    sign_ins: signIns,
    unique_sessions: sessions.size,
    signed_in_users: signedInUsers.size,
    comments_posted: commentsPosted,
    registered_profiles: registeredProfiles,
    events_by_type: eventsByType,
    top_paths: topPaths,
    top_games: topGames,
    top_app_opens: topAppOpens,
    game_analytics: topGames.map((g) => ({
      game_slug: g.game_slug,
      game_title: g.game_slug,
      plays: g.plays,
      page_views: 0,
      comments: 0,
      unique_sessions: 0,
    })),
  };
}

// ---------------------------------------------------------------------------
// Service requests
// ---------------------------------------------------------------------------

export async function firestoreSubmitServiceRequest(data: Record<string, unknown>): Promise<void> {
  if (!(await ensureFirestore())) throw new Error('Firebase not configured');
  await addDoc(collection(firestore(), COL.serviceRequests), {
    ...data,
    status: 'new',
    created_at: ts(),
  });
}

export async function firestoreAdminListServiceRequests(limitN = 100): Promise<Record<string, unknown>[]> {
  if (!(await ensureFirestore())) return [];
  const q = query(
    collection(firestore(), COL.serviceRequests),
    orderBy('created_at', 'desc'),
    limit(limitN),
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/** Bootstrap username generator (replaces Supabase RPC). */
export function bootstrapUsername(userId: string): string {
  return `u_${userId.replace(/[^a-zA-Z0-9]/g, '').slice(0, 12)}`.toLowerCase();
}

export function stripUndefined(obj: DocumentData): DocumentData {
  const out: DocumentData = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined) out[k] = v;
  }
  return out;
}

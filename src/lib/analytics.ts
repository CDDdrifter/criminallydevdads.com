/**
 * First-party analytics — inserts into Firestore `analytics_events`.
 * Respects `behavior.first_party_analytics_enabled` from site settings.
 */
import { auth, isFirebaseReady } from './firebase';
import { ensureFirestore, firestoreTrackEvent } from './firestoreData';

const SESSION_KEY = 'cdd_analytics_session';

export type AnalyticsEventType = 'page_view' | 'game_play' | 'sign_in' | 'comment_post' | 'app_open';

function getSessionId(): string {
  try {
    let id = sessionStorage.getItem(SESSION_KEY);
    if (!id) {
      id = crypto.randomUUID();
      sessionStorage.setItem(SESSION_KEY, id);
    }
    return id;
  } catch {
    return 'anon';
  }
}

let analyticsEnabled = true;

/** Called from SiteThemeApply / settings hook when behavior loads. */
export function setFirstPartyAnalyticsEnabled(enabled: boolean) {
  analyticsEnabled = enabled;
}

export async function trackEvent(
  eventType: AnalyticsEventType,
  opts: {
    path?: string;
    targetKey?: string;
    metadata?: Record<string, unknown>;
    userId?: string | null;
  } = {},
): Promise<void> {
  if (!isFirebaseReady() || !analyticsEnabled) {
    return;
  }
  if (!(await ensureFirestore())) {
    return;
  }
  const path = (opts.path ?? '').slice(0, 500);
  const targetKey = (opts.targetKey ?? '').slice(0, 200);
  const userId = opts.userId ?? auth?.currentUser?.uid ?? null;
  try {
    await firestoreTrackEvent({
      event_type: eventType,
      path,
      target_key: targetKey,
      session_id: getSessionId(),
      user_id: userId,
      metadata: opts.metadata ?? {},
    });
  } catch (err) {
    console.warn('[analytics] insert failed', err instanceof Error ? err.message : err);
  }
}

export function trackPageView(path: string, userId?: string | null) {
  void trackEvent('page_view', { path, userId });
}

export function trackGamePlay(gameSlug: string, userId?: string | null) {
  void trackEvent('game_play', { path: `/play/${gameSlug}`, targetKey: gameSlug, userId });
}

export function trackSignIn(userId: string) {
  void trackEvent('sign_in', { path: '/auth', userId });
}

/** HTML mini-app page (`page_mode: html_app`) — counted separately from generic page views. */
export function trackAppOpen(pageSlug: string, userId?: string | null) {
  const key = pageSlug.trim();
  if (!key) return;
  void trackEvent('app_open', { path: `/p/${key}`, targetKey: key, userId });
}

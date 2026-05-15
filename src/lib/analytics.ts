/**
 * First-party analytics — inserts into `site_analytics_events` (migration 020).
 * Respects `behavior.first_party_analytics_enabled` from site settings.
 */
import { supabase, supabaseConfigured } from './supabase';

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
  if (!supabaseConfigured || !supabase || !analyticsEnabled) {
    return;
  }
  const path = (opts.path ?? '').slice(0, 500);
  const targetKey = (opts.targetKey ?? '').slice(0, 200);
  let userId = opts.userId ?? null;
  if (!userId) {
    const { data } = await supabase.auth.getSession();
    userId = data.session?.user?.id ?? null;
  }
  const payload = {
    event_type: eventType,
    path,
    target_key: targetKey,
    session_id: getSessionId(),
    user_id: userId,
    metadata: opts.metadata ?? {},
  };
  const { error } = await supabase.from('site_analytics_events').insert(payload);
  if (error) {
    console.warn('[analytics] insert failed', error.message);
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

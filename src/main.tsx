/**
 * Entry: run hash-route bootstrap BEFORE any module that imports Supabase.
 *
 * Hoisted imports meant `createClient` ran while the URL was still `/?code=…`,
 * started PKCE exchange (consumes the verifier), then `location.replace` to
 * `/#/auth/callback?…` forced a full reload — second load had no verifier →
 * "PKCE code verifier not found". Dynamic import delays Supabase until after
 * bootstrap (replaceState, no reload).
 */
import { bootstrapSpaAuthPaths } from './lib/authBootstrap';

bootstrapSpaAuthPaths();

void import('./main-app').then(({ mountApp }) => {
  mountApp();
});

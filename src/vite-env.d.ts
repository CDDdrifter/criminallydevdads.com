/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Firebase Auth — see docs/NO_SUPABASE_SETUP.md */
  readonly VITE_FIREBASE_API_KEY: string;
  readonly VITE_FIREBASE_AUTH_DOMAIN: string;
  readonly VITE_FIREBASE_PROJECT_ID: string;
  readonly VITE_FIREBASE_APP_ID?: string;
  /** Legacy Supabase — optional, no longer required */
  readonly VITE_SUPABASE_URL?: string;
  readonly VITE_SUPABASE_ANON_KEY?: string;
  readonly VITE_AUTH_REDIRECT_URL?: string;
  /** legacy (default) | auto | cms — see docs/NO_SUPABASE_SETUP.md */
  readonly VITE_GAME_CATALOG?: string;
  /** Show "Team login" in header — default off; bookmark /admin */
  readonly VITE_SHOW_ADMIN_NAV?: string;
  readonly VITE_GITHUB_REPO_OWNER: string;
  readonly VITE_GITHUB_REPO_NAME: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

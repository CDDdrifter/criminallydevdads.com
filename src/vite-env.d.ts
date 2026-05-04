/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_ANON_KEY: string;
  /** Optional: canonical public URL for auth redirects (e.g. https://yoursite.com/) if auto-detect is wrong */
  readonly VITE_AUTH_REDIRECT_URL?: string;
  /** auto (default) | legacy | cms — see docs/WEBSITE_WORKFLOW.md */
  readonly VITE_GAME_CATALOG?: string;
  /** Show "Team login" in header — default off; bookmark /#/admin */
  readonly VITE_SHOW_ADMIN_NAV?: string;
  readonly VITE_GITHUB_REPO_OWNER: string;
  readonly VITE_GITHUB_REPO_NAME: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

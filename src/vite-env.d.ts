/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_ANON_KEY: string;
  /** auto (default) | legacy | cms — see docs/WEBSITE_WORKFLOW.md */
  readonly VITE_GAME_CATALOG?: string;
  readonly VITE_GITHUB_REPO_OWNER: string;
  readonly VITE_GITHUB_REPO_NAME: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

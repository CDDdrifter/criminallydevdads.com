export type GameRecord = {
  id: string;
  slug: string;
  title: string;
  type: string;
  description: string | null;
  details: string | null;
  thumbnail_url: string | null;
  /** Optional preview clip (Storage URL or any https URL). */
  preview_video_url?: string | null;
  external_url: string | null;
  /** Folder under /games/<folder>/index.html when hosted with static files */
  local_folder: string | null;
  /** Supabase Storage folder under bucket game-builds/ — itch-style uploaded HTML5 build */
  storage_slug?: string | null;
  sort_order: number;
  published: boolean;
};

export type GameView = {
  id: string;
  slug: string;
  title: string;
  type: string;
  description: string;
  details: string;
  thumbnail: string;
  preview_video: string;
  external_url: string;
  local_folder: string;
  launchPath: string;
  isPlayable: boolean;
};

export type PageSection =
  | { id: string; kind: 'heading'; title: string; subtitle?: string }
  | { id: string; kind: 'text'; body: string }
  | { id: string; kind: 'panel'; title: string; body: string; variant?: 'default' | 'accent' | 'muted' }
  | { id: string; kind: 'image'; url: string; alt?: string; caption?: string }
  | { id: string; kind: 'video'; url: string; caption?: string }
  | { id: string; kind: 'divider' };

export type SitePage = {
  id: string;
  slug: string;
  title: string;
  /** Legacy single block; still shown if sections is empty */
  body: string;
  /** Ordered blocks: headings, text, panels, images, dividers */
  sections: PageSection[];
  show_in_nav: boolean;
  sort_order: number;
};

export type NavItem = {
  id: string;
  label: string;
  href: string;
  external: boolean;
  sort_order: number;
};

export type DevLogPost = {
  id: string;
  slug: string;
  title: string;
  body: string;
  published_at: string;
};

export type SiteSettings = {
  hero_title: string;
  hero_subtitle: string;
  support_title: string;
  support_body: string;
  footer_text: string;
};

export const defaultSiteSettings: SiteSettings = {
  hero_title: '⚔️ CRIMINALLY DEV DADS',
  hero_subtitle: 'EST. 2026 // GAME HUB // INDIE COLLECTIVE',
  support_title: 'Support the Devs',
  support_body:
    'Love our games? Help us keep creating by supporting our work. COMING SOON',
  footer_text: '© 2026 CRIMINALLY DEV DADS  // ALL RIGHTS RESERVED // STAY CRIMINAL',
};

export type PageSection =
  | { id: string; kind: 'heading'; title: string; subtitle?: string }
  | { id: string; kind: 'text'; body: string }
  | { id: string; kind: 'panel'; title: string; body: string; variant?: 'default' | 'accent' | 'muted' }
  | { id: string; kind: 'image'; url: string; alt?: string; caption?: string }
  | { id: string; kind: 'video'; url: string; caption?: string }
  | { id: string; kind: 'divider' };

export type SupportButton = {
  id: string;
  label: string;
  href: string;
  external?: boolean;
  variant?: 'primary' | 'secondary';
};

/**
 * Mirrors `site_games.pricing_model` when CMS is used.
 * - free: no Buy / no Edge checkout
 * - fixed: Edge session from price_cents or stripe_price_id
 * - pwyw | donation: Edge session with customer amount_cents (server validates floor)
 */
export type GamePricingModel = 'free' | 'fixed' | 'pwyw' | 'donation';

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
  /** Path inside the uploaded ZIP to the real index.html when auto-detect is wrong (e.g. `Release/index.html`). */
  storage_entry_in_zip?: string | null;
  /** Blocks shown on the game detail page below the embed (CMS only). */
  sections?: PageSection[] | null;
  /** Site-wide FX accent preset when viewing this game’s page (optional). */
  visual_preset?: string | null;
  /** Asset sale price in cents (optional). */
  price_cents?: number | null;
  /** Public checkout URL (Stripe payment link or your own checkout page). */
  purchase_url?: string | null;
  /** Optional Stripe Price ID for future direct Checkout API flow. */
  stripe_price_id?: string | null;
  /** How this title is sold when using built-in checkout (see docs/STRIPE_CHECKOUT.md). */
  pricing_model?: GamePricingModel | string | null;
  /** Minimum customer amount in USD cents (PWYW / donation). */
  pwyw_min_cents?: number | null;
  /** Suggested PWYW amount in USD cents (hint only). */
  pwyw_suggested_cents?: number | null;
  /** Donation quick-pick amounts in USD cents. */
  donation_presets_cents?: number[] | null;
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
  sections: PageSection[];
  visual_preset: string;
  /** Normalized for UI + checkout (legacy rows may infer `fixed` from price_cents). */
  pricing_model: GamePricingModel;
  price_cents: number;
  /** If non-empty, GamePurchaseBlock links here and skips built-in Stripe (itch, Payment Link, etc.). */
  purchase_url: string;
  stripe_price_id: string;
  /** USD cents; Stripe minimum still enforced server-side (50). */
  pwyw_min_cents: number;
  /** USD cents; default amount hint for PWYW UI only. */
  pwyw_suggested_cents: number;
  /** USD cents; donation preset chip amounts. */
  donation_presets_cents: number[];
};

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
  /** Optional internal page URL for support/contact, e.g. `/p/support`. */
  support_page_href: string;
  /** Optional Stripe donation link (payment link or hosted checkout URL). */
  stripe_donation_url: string;
  /** Buttons shown in the support block at the bottom of the homepage. */
  support_buttons: SupportButton[];
  footer_text: string;
  /**
   * Hub / inner pages mood — same keys as `site_games.visual_preset` (ember, aurora, …).
   * Game detail + fullscreen play pages override from the game row.
   */
  site_visual_preset: string;
  /** CRT-style lines — `.fx-scanlines` in index.css */
  fx_scanlines: boolean;
  /** Animated grain — `.fx-noise` */
  fx_noise: boolean;
  /** Edge darkening — `.fx-vignette` */
  fx_vignette: boolean;
  /** Animated color wash — `body::before` */
  fx_hue_shift: boolean;
  /** Mouse-following radial — `body::after` (uses --cursor-x/y from SiteChrome) */
  fx_cursor_spotlight: boolean;
};

export const defaultSiteSettings: SiteSettings = {
  hero_title: '⚔️ CRIMINALLY DEV DADS',
  hero_subtitle: 'EST. 2026 // GAME HUB // INDIE COLLECTIVE',
  support_title: 'Support the Devs',
  support_body:
    'Love our games? Help us keep creating by supporting our work. COMING SOON',
  support_page_href: '/p/support',
  stripe_donation_url: '',
  support_buttons: [
    { id: 'donate', label: 'Donate', href: '', external: true, variant: 'primary' },
    { id: 'merch', label: 'Merch Shop', href: '', external: true, variant: 'secondary' },
    { id: 'contact', label: 'Contact / Support', href: '/p/support', external: false, variant: 'secondary' },
  ],
  footer_text: '© 2026 CRIMINALLY DEV DADS  // ALL RIGHTS RESERVED // STAY CRIMINAL',
  site_visual_preset: '',
  fx_scanlines: true,
  fx_noise: true,
  fx_vignette: true,
  fx_hue_shift: true,
  fx_cursor_spotlight: true,
};

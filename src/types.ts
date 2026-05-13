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

/** Scheduled homepage promo / event strip (admin-editable). */
export type SiteEvent = {
  id: string;
  title: string;
  body: string;
  href: string;
  external: boolean;
  starts_at: string | null;
  ends_at: string | null;
  active: boolean;
};

export type FxIntensity = 'subtle' | 'normal' | 'intense';

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
  /** Public checkout URL (Stripe payment link, itch.io, etc.). Gumroad should use `gumroad_url` for the ★ badge. */
  purchase_url?: string | null;
  /** Gumroad product or profile link — shows a star on hub thumbnails; takes precedence over `purchase_url` for the buy button. */
  gumroad_url?: string | null;
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
  /** Listed on <code>/#/vault</code> (can be true while <code>published</code> is false). */
  in_vault?: boolean | null;
  /** Wider layout + lighter chrome; pair with custom CSS for a non-hub feel. */
  immersive_layout?: boolean | null;
  /** Extra CSS for this game’s detail + play routes (admin trust model). */
  custom_mood_css?: string | null;
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
  /** If non-empty (and no `gumroad_url`), GamePurchaseBlock links here and skips built-in Stripe. */
  purchase_url: string;
  /** Gumroad listing — ★ on cards; buy button prefers this URL when set. */
  gumroad_url: string;
  stripe_price_id: string;
  /** USD cents; Stripe minimum still enforced server-side (50). */
  pwyw_min_cents: number;
  /** USD cents; default amount hint for PWYW UI only. */
  pwyw_suggested_cents: number;
  /** USD cents; donation preset chip amounts. */
  donation_presets_cents: number[];
  in_vault: boolean;
  immersive_layout: boolean;
  custom_mood_css: string;
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
  /** Page-only mood; same keys as hub / game presets (Admin + index.css). */
  visual_preset?: string | null;
  immersive_layout?: boolean | null;
  custom_mood_css?: string | null;
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

// ---------------------------------------------------------------------------
// Admin Studio — Theme system
// ---------------------------------------------------------------------------
//
// The "Studio" admin tabs (Theme, Effects, Typography, Layout, Components,
// Behavior, SEO) drive these nested configs. They are persisted as JSONB on
// `site_settings` (migration 016) and applied to the live document by
// `lib/themeApply.ts` via the `<SiteThemeApply />` component.
//
// IMPORTANT: every field is optional in the *Partial variants. The frontend
// uses `mergeThemeConfig()` / `themeDefaults` to fill missing fields so that
// older settings rows (or rows written before migration 016) keep working.
// ---------------------------------------------------------------------------

/** Single colour stop inside a gradient (position 0..100). */
export type GradientStop = {
  id: string;
  color: string;
  /** 0..100 along the gradient axis (linear) or radius (radial/conic). */
  position: number;
};

/** Gradient definition the studio can build / render to CSS. */
export type Gradient = {
  type: 'linear' | 'radial' | 'conic';
  /** Degrees for `linear` / `conic` (ignored for `radial`). */
  angle: number;
  /** Sized as `<radius_x> <radius_y>` for `radial`. e.g. `'1100px 700px'`. */
  size: string;
  /** Position for `radial` / `conic`. e.g. `'85% 10%'`. */
  position: string;
  /** Ordered colour stops (sorted by `position` when rendered). */
  stops: GradientStop[];
};

/** Theme tokens — every named colour the site can paint. */
export type ThemeColors = {
  bg_0: string;
  bg_1: string;
  panel: string;
  panel_strong: string;
  text: string;
  text_strong: string;
  muted: string;
  accent: string;
  accent_2: string;
  danger: string;
  success: string;
  warning: string;
  border: string;
  /** Hyperlinks and inline `<a>` elements. */
  link: string;
  link_hover: string;
  /** Game card / panel chrome. */
  card_bg_a: string;
  card_bg_b: string;
  card_border: string;
  card_hover_border: string;
  /** Header (hero block) chrome. */
  header_bg: string;
  header_border: string;
  header_title_color: string;
  header_subtitle_color: string;
  /** Footer text colour. */
  footer_text_color: string;
  /** Top nav button colours. */
  nav_button_bg: string;
  nav_button_text: string;
  nav_button_border: string;
  nav_button_hover_bg_a: string;
  nav_button_hover_bg_b: string;
  nav_button_hover_text: string;
  /** Generic button colours (filter / form buttons). */
  button_bg: string;
  button_text: string;
  button_border: string;
  button_hover_bg_a: string;
  button_hover_bg_b: string;
  /** Game type pill on cards. */
  tag_bg_a: string;
  tag_bg_b: string;
  tag_text: string;
  /** Play / download buttons on game cards. */
  play_btn_a: string;
  play_btn_b: string;
  play_btn_text: string;
  download_btn_a: string;
  download_btn_b: string;
  download_btn_text: string;
  /** Big homepage "support" call-to-action button. */
  support_btn_a: string;
  support_btn_b: string;
  support_btn_text: string;
};

/** Body background: a base gradient plus optional radial accent overlay and image. */
export type ThemeBackgrounds = {
  body_gradient: Gradient;
  body_radial_accent: {
    enabled: boolean;
    color: string;
    opacity: number;
    size: string;
    position: string;
    falloff: number;
  };
  /** Optional background image URL (rendered behind FX layers). */
  body_image_url: string;
  body_image_size: 'cover' | 'contain' | 'auto' | 'repeat';
  body_image_blend:
    | 'normal'
    | 'screen'
    | 'overlay'
    | 'multiply'
    | 'difference'
    | 'soft-light'
    | 'hard-light';
  body_image_opacity: number;
  body_image_fixed: boolean;
  /** Tertiary radial flare in the header. */
  header_glow: {
    enabled: boolean;
    color: string;
    opacity: number;
    size: string;
    position: string;
  };
};

export type ThemeConfig = {
  /** Master toggle: when off, the studio theme is ignored and the legacy preset CSS applies. */
  enabled: boolean;
  colors: ThemeColors;
  background: ThemeBackgrounds;
  /** A short label admin sees in the Theme tab heading. */
  display_name: string;
};

/** Fine-grained per-effect controls. The legacy `fx_*` booleans gate visibility; these tune look. */
export type EffectsConfig = {
  scanlines: {
    enabled: boolean;
    opacity: number;
    line_color: string;
    gap_color: string;
    spacing_px: number;
  };
  noise: {
    enabled: boolean;
    opacity: number;
    size_px: number;
    speed_s: number;
    color: string;
  };
  vignette: {
    enabled: boolean;
    opacity: number;
    inner_stop: number;
    color: string;
  };
  hue_shift: {
    enabled: boolean;
    opacity: number;
    speed_s: number;
    color_a: string;
    color_b: string;
    color_c: string;
    blend: 'screen' | 'overlay' | 'multiply' | 'soft-light' | 'hard-light' | 'normal';
  };
  cursor_spotlight: {
    enabled: boolean;
    color: string;
    opacity: number;
    radius_x_px: number;
    radius_y_px: number;
  };
  title_glitch: { enabled: boolean; intensity_px: number; period_s: number };
  card_in_animation: { enabled: boolean; duration_ms: number; stagger_ms: number };
  card_hover: {
    enabled: boolean;
    lift_px: number;
    skew_deg: number;
    glow_color: string;
    glow_strength: number;
    shine: boolean;
  };
  scroll_jitter: { enabled: boolean };
  edge_sweep: { enabled: boolean; color: string; period_s: number };
  reduce_motion: { honor_prefers: boolean };
  /** Optional extra CSS appended after all generated theme rules (advanced). */
  custom_css: string;
};

export type TypographyConfig = {
  /** Imported with `<link href=…>` before any other stylesheet. Leave empty to disable. */
  google_fonts_url: string;
  font_family_base: string;
  font_family_heading: string;
  font_family_mono: string;
  base_font_size_px: number;
  base_line_height: number;
  letter_spacing_em: number;
  heading_letter_spacing_em: number;
  heading_text_transform: 'uppercase' | 'none' | 'lowercase' | 'capitalize';
  heading_weight: number;
  body_weight: number;
  hero_title_size_rem: number;
  hero_subtitle_size_rem: number;
  card_title_size_rem: number;
  link_underline: 'always' | 'hover' | 'never';
  /** CSS `text-shadow` value applied to the hero title. */
  heading_text_shadow: string;
};

export type LayoutConfig = {
  container_max_width_px: number;
  container_padding_px: number;
  base_padding_px: number;
  border_radius_panel_px: number;
  border_radius_card_px: number;
  border_radius_button_px: number;
  card_min_width_px: number;
  card_gap_px: number;
  /** Card image height in pixels (rendered with `object-fit: cover`). */
  card_thumbnail_height_px: number;
  /** Forced grid columns (0 = auto-fill from `card_min_width_px`). */
  card_force_columns: number;
  header_padding_v_px: number;
  header_padding_h_px: number;
  header_margin_bottom_px: number;
  header_text_align: 'left' | 'center' | 'right';
  nav_alignment: 'flex-start' | 'center' | 'flex-end' | 'space-between';
  nav_gap_px: number;
  nav_position: 'top' | 'sticky';
  footer_text_align: 'left' | 'center' | 'right';
  footer_padding_px: number;
};

export type ComponentsConfig = {
  card: {
    shadow: string;
    hover_shadow: string;
    border_width_px: number;
    padding_px: number;
    title_letter_spacing_em: number;
  };
  button: {
    padding_v_px: number;
    padding_h_px: number;
    font_size_rem: number;
    text_transform: 'uppercase' | 'none' | 'lowercase';
    /** Y-translation in px on `:hover` (mirrors `.btn-play:hover`). */
    hover_translate_y_px: number;
    border_width_px: number;
    letter_spacing_em: number;
  };
  panel: {
    blur_px: number;
    border_width_px: number;
    shadow: string;
  };
  modal: {
    backdrop_blur_px: number;
    backdrop_color: string;
    width_max_px: number;
  };
  promo_card: {
    accent_border: boolean;
    title_uppercase: boolean;
  };
};

export type BehaviorConfig = {
  show_vault_link: boolean;
  show_devlog_link: boolean;
  show_filter_buttons: boolean;
  show_support_section: boolean;
  show_footer: boolean;
  show_admin_link_in_nav: boolean;
  /** Default tab in homepage filter. */
  default_game_filter: 'all' | 'game' | 'asset';
  /** When true, all hub routes show the maintenance page below. */
  maintenance_mode: { enabled: boolean; title: string; message: string; allow_admin_bypass: boolean };
  /** Optional HTML banner shown above the hero (trusted content). */
  homepage_intro: { enabled: boolean; html: string };
  /** Picks one of several CSS hover effects for game cards. */
  game_card_hover_effect: 'lift' | 'shine' | 'glow' | 'tilt' | 'pulse' | 'none';
  /** Auto-play preview videos on the homepage cards. */
  homepage_autoplay_previews: boolean;
  /** Sound that plays when nav / play buttons are clicked (URL). Leave empty to disable. */
  click_sound_url: string;
  click_sound_volume: number;
};

export type SeoConfig = {
  /** `%s` is replaced with the page title; e.g. `"%s — Criminally Dev Dads"`. */
  title_template: string;
  default_meta_description: string;
  og_image_url: string;
  twitter_handle: string;
  favicon_url: string;
  analytics_provider: 'none' | 'umami' | 'plausible' | 'ga4' | 'custom';
  analytics_id: string;
  analytics_script_src: string;
  theme_color: string;
};

// ---------------------------------------------------------------------------
// Studio expansion (migration 017). All optional / merge-on-load so older
// settings rows keep working. Defaults live in `lib/themeDefaults.ts`.
// ---------------------------------------------------------------------------

/** Reusable animation that can be assigned to entrance / hover / idle. */
export type AnimationKey =
  | 'none'
  | 'fade-in'
  | 'slide-up'
  | 'slide-down'
  | 'slide-left'
  | 'slide-right'
  | 'zoom-in'
  | 'zoom-out'
  | 'flip-in'
  | 'wobble'
  | 'pulse'
  | 'shake'
  | 'glitch'
  | 'shimmer';

export type AnimationsConfig = {
  /** Master kill-switch (forces every studio animation to none). */
  enabled: boolean;
  /** Page-load animations for top-level blocks. */
  page_entrance: AnimationKey;
  page_entrance_duration_ms: number;
  /** Routing fade (set 0 to disable). */
  route_fade_ms: number;
  /** Game cards entrance (overrides effects.card_in_animation when not 'none'). */
  card_entrance: AnimationKey;
  card_entrance_stagger_ms: number;
  /** Hero title idle / loop animation. */
  hero_idle: AnimationKey;
  /** Idle animation period in seconds. */
  hero_idle_period_s: number;
  /** Button hover animation. */
  button_hover: AnimationKey;
  /** Promo card entrance (homepage announcements). */
  promo_entrance: AnimationKey;
};

export type AudioConfig = {
  /** Master gain for every studio audio clip (0..1). */
  master_volume: number;
  /** When true, all studio audio is muted regardless of per-clip volume. */
  muted: boolean;
  /** Looping background music. URL of an .mp3/.ogg/.wav. */
  background_music_url: string;
  background_music_volume: number;
  /** Try to autoplay on user gesture (many browsers will block until then). */
  background_music_autoplay: boolean;
  /** Loops back to start automatically. */
  background_music_loop: boolean;
  /** Short clip played when hovering nav buttons / cards. Leave empty to disable. */
  hover_sound_url: string;
  hover_sound_volume: number;
  /** Ambient pad / loop that mixes underneath music (e.g. wind, rain). */
  ambient_loop_url: string;
  ambient_loop_volume: number;
  /** Show a floating mute toggle. */
  show_mute_toggle: boolean;
};

export type CursorConfig = {
  enabled: boolean;
  /** What appears under the actual mouse. `default` = no override. */
  style: 'default' | 'emoji' | 'image' | 'reticle' | 'crosshair' | 'pointer' | 'none';
  /** Emoji string (only used when style==='emoji'). */
  emoji: string;
  /** Image URL (only used when style==='image'). 32x32 recommended. */
  image_url: string;
  /** Cursor visual size in px. */
  size_px: number;
  /** Coloured pulsing trail behind the cursor. */
  trail: { enabled: boolean; color: string; length: number; size_px: number };
  /** Click-ripple effect. */
  click_ripple: { enabled: boolean; color: string; size_px: number };
  /** Hide the OS cursor when a studio cursor is active. */
  hide_os_cursor: boolean;
};

export type ParticlesConfig = {
  enabled: boolean;
  /** Particle kind — picks a renderer + default colours. */
  kind:
    | 'stars'
    | 'snow'
    | 'sparks'
    | 'ash'
    | 'matrix'
    | 'dots'
    | 'fireflies'
    | 'bubbles'
    | 'rain'
    | 'leaves';
  count: number;
  color: string;
  /** Min / max pixel speed per frame. */
  speed_min: number;
  speed_max: number;
  size_min_px: number;
  size_max_px: number;
  /** Flow direction. */
  direction: 'up' | 'down' | 'left' | 'right' | 'random';
  /** Where to paint relative to content (behind / above main scroll). */
  z_index: 'behind' | 'above';
  /** Overall opacity (multiplied with kind-default). */
  opacity: number;
  /** Honour OS reduce-motion when on. */
  respect_reduce_motion: boolean;
};

export type SocialLink = {
  id: string;
  platform:
    | 'discord'
    | 'twitter'
    | 'bluesky'
    | 'mastodon'
    | 'youtube'
    | 'twitch'
    | 'tiktok'
    | 'itch'
    | 'github'
    | 'patreon'
    | 'kofi'
    | 'instagram'
    | 'email'
    | 'rss'
    | 'custom';
  url: string;
  /** Visible label override; falls back to platform name. */
  label: string;
};

export type SocialConfig = {
  show_in_header: boolean;
  show_in_footer: boolean;
  style: 'monochrome' | 'colour' | 'text';
  size_px: number;
  links: SocialLink[];
};

/** Hero call-to-action button (separate from `support_buttons`). */
export type HeroButton = {
  id: string;
  label: string;
  href: string;
  external: boolean;
  variant: 'primary' | 'secondary' | 'ghost';
};

export type HeroConfig = {
  /** Optional logo image painted above the title. */
  logo_image_url: string;
  logo_max_height_px: number;
  /** Toggle the textual title / subtitle on or off independently of layout. */
  show_title: boolean;
  show_subtitle: boolean;
  /** Optional tagline shown under the subtitle. */
  tagline: string;
  /** Small badge / ribbon over the hero (e.g. "Open beta", "v2.0"). */
  badge: { enabled: boolean; text: string; color: string; bg: string };
  /** "Scroll" arrow at the bottom of the hero. */
  scroll_indicator: { enabled: boolean; emoji: string; color: string };
  /** CTA buttons under the hero subtitle. */
  buttons: HeroButton[];
};

export type GameCardsConfig = {
  show_thumbnail: boolean;
  show_type_tag: boolean;
  show_description: boolean;
  show_price: boolean;
  /** Title transform on cards. */
  title_case: 'upper' | 'lower' | 'capitalize' | 'none';
  /** Highlight new games with a ribbon. */
  new_ribbon: { enabled: boolean; text: string; color: string; bg: string; days: number };
  /** Optional star/symbol painted on bottom-right of cover. */
  badge: { enabled: boolean; symbol: string; color: string };
  /** Card layout style. `standard` = current grid; `compact` shrinks padding; `media` puts a big cover. */
  layout: 'standard' | 'compact' | 'media' | 'minimal';
};

export type BrandingConfig = {
  /** Display name used in title template + footer auto-copyright. */
  site_name: string;
  /** Image URL used in the top nav (next to the link list). */
  header_logo_url: string;
  header_logo_height_px: number;
  /** A short tagline rendered under the logo in the top nav. */
  header_tagline: string;
  /** Footer copyright template — supports `{year}` and `{name}` placeholders. */
  footer_copyright_template: string;
  footer_show_auto_copyright: boolean;
  /** Tiny watermark on every page (bottom-right). Leave empty for none. */
  watermark_text: string;
  watermark_url: string;
  /** Show "Made with ❤" on footer (community / open source signal). */
  show_made_with: boolean;
};

export type PerformanceConfig = {
  /** Master kill-switch — every studio animation goes off. */
  disable_all_animations: boolean;
  /** Drops `backdrop-filter: blur(*)` site-wide. */
  disable_backdrop_filter: boolean;
  /** Drops `filter: blur(*)` on FX layers. */
  disable_blur_effects: boolean;
  /** Adds `loading="lazy"` to game thumbnails. */
  image_lazy_load: boolean;
  /** Prefetches nav routes when admin is online (uses `<link rel="prefetch">`). */
  prefetch_nav: boolean;
  /** Caps the hero glow / hue-shift on low-end devices. */
  battery_saver: boolean;
};

export type AccessibilityConfig = {
  /** Visible focus ring (keyboard a11y). */
  focus_ring_color: string;
  focus_ring_width_px: number;
  focus_ring_style: 'solid' | 'dashed' | 'double';
  /** Multiplies the base font size (1 = default). */
  font_size_scale: number;
  /** Swap body font for OpenDyslexic when on (Google Fonts URL). */
  dyslexia_friendly_font: boolean;
  /** Force all links underlined for clarity (overrides typography setting). */
  always_underline_links: boolean;
  /** High contrast pass: forces stronger text + thicker borders. */
  high_contrast_mode: boolean;
  /** Skip-to-content link visible to screen readers / keyboard. */
  skip_link_enabled: boolean;
};

export type SharingConfig = {
  /** Shows a strip on game detail pages. */
  show_on_games: boolean;
  show_on_pages: boolean;
  /** Which platform buttons to render. */
  twitter: boolean;
  reddit: boolean;
  bluesky: boolean;
  facebook: boolean;
  hacker_news: boolean;
  copy_link: boolean;
  email: boolean;
  /** Template — `{title}` / `{url}` / `{site}` substituted at render. */
  text_template: string;
};

/** User-saved or built-in theme preset. */
export type ThemePreset = {
  id: string;
  name: string;
  description: string;
  /** Snapshot of the theme tokens; merged into ThemeConfig when applied. */
  theme: Pick<ThemeConfig, 'colors' | 'background' | 'display_name'>;
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
  /** Scales scanlines, grain, hue wash, spotlight in `index.css`. */
  fx_intensity: FxIntensity;
  /** Homepage announcement cards (optional start/end). */
  promo_events: SiteEvent[];
  /** Injected globally — powerful; admin trust model. */
  custom_css: string;
  // ----- Admin Studio (migration 016) ------------------------------------
  /** Full theme tokens — driven by Theme + Backgrounds studio tabs. */
  theme: ThemeConfig;
  /** Per-effect fine controls — driven by Effects studio tab. */
  effects: EffectsConfig;
  /** Typography — driven by Typography studio tab. */
  typography: TypographyConfig;
  /** Layout dimensions — driven by Layout studio tab. */
  layout: LayoutConfig;
  /** Component look — driven by Components studio tab. */
  components: ComponentsConfig;
  /** Feature flags + maintenance mode + on-page behavior. */
  behavior: BehaviorConfig;
  /** SEO meta + analytics provider config. */
  seo: SeoConfig;
  /** Raw HTML injected into <head>. Trusted admin content. */
  custom_head_html: string;
  /** Saved palettes admins can swap into. */
  theme_presets: ThemePreset[];
  // ----- Studio expansion (migration 017) --------------------------------
  /** Page / card / hero animation library + assignments. */
  animations: AnimationsConfig;
  /** Background music + hover sound + ambient loop + master volume. */
  audio: AudioConfig;
  /** Custom cursor, trail, click ripple. */
  cursor: CursorConfig;
  /** Floating particle layer (stars / snow / sparks / matrix / …). */
  particles: ParticlesConfig;
  /** Social media links bar in header + footer. */
  social: SocialConfig;
  /** Hero section — logo, badge, scroll arrow, CTA buttons. */
  hero: HeroConfig;
  /** Game card display flags (description / type / ribbons / layout). */
  game_cards: GameCardsConfig;
  /** Branding — site name, header logo, footer auto-copyright, watermark. */
  branding: BrandingConfig;
  /** Performance + battery saver toggles. */
  performance: PerformanceConfig;
  /** Accessibility — focus ring, font scaling, dyslexia font, high contrast. */
  accessibility: AccessibilityConfig;
  /** Share-button strip on game detail pages. */
  sharing: SharingConfig;
};

// ---------------------------------------------------------------------------
// Defaults live in `lib/themeDefaults.ts` for tree-shake friendliness — but
// `defaultSiteSettings` needs to be constructible from this file alone (the
// SiteSettingsProvider imports it as a fallback when Supabase is offline).
// Keep `themeDefaults.ts` as the source of truth and re-export the *Default
// helpers here.
// ---------------------------------------------------------------------------
import {
  defaultAccessibilityConfig,
  defaultAnimationsConfig,
  defaultAudioConfig,
  defaultBehaviorConfig,
  defaultBrandingConfig,
  defaultComponentsConfig,
  defaultCursorConfig,
  defaultEffectsConfig,
  defaultGameCardsConfig,
  defaultHeroConfig,
  defaultLayoutConfig,
  defaultParticlesConfig,
  defaultPerformanceConfig,
  defaultSeoConfig,
  defaultSharingConfig,
  defaultSocialConfig,
  defaultThemeConfig,
  defaultTypographyConfig,
} from './lib/themeDefaults';

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
  fx_intensity: 'normal',
  promo_events: [],
  custom_css: '',
  theme: defaultThemeConfig(),
  effects: defaultEffectsConfig(),
  typography: defaultTypographyConfig(),
  layout: defaultLayoutConfig(),
  components: defaultComponentsConfig(),
  behavior: defaultBehaviorConfig(),
  seo: defaultSeoConfig(),
  custom_head_html: '',
  theme_presets: [],
  animations: defaultAnimationsConfig(),
  audio: defaultAudioConfig(),
  cursor: defaultCursorConfig(),
  particles: defaultParticlesConfig(),
  social: defaultSocialConfig(),
  hero: defaultHeroConfig(),
  game_cards: defaultGameCardsConfig(),
  branding: defaultBrandingConfig(),
  performance: defaultPerformanceConfig(),
  accessibility: defaultAccessibilityConfig(),
  sharing: defaultSharingConfig(),
};

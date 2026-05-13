/**
 * themeDefaults.ts
 *
 * Single source of truth for the Admin Studio configuration defaults.
 *
 * These values match the hand-tuned look of `src/index.css` (the legacy
 * stylesheet still ships and provides the visual baseline). Every Admin
 * Studio tab edits one of these objects and `lib/themeApply.ts` then
 * converts them into runtime CSS custom properties + generated rules.
 *
 * IMPORTANT
 * ---------
 * - Always return *fresh* objects from the `default*Config()` factories so
 *   callers (React state, form drafts) can mutate them without polluting a
 *   shared reference.
 * - When you add a new tunable in the Studio, edit ONLY this file, the
 *   matching type in `src/types.ts`, and the applier in
 *   `lib/themeApply.ts`. The studio UIs auto-pick up new fields via their
 *   form helpers, but a TypeScript field must exist first.
 */

import type {
  AccessibilityConfig,
  AnimationsConfig,
  AudioConfig,
  BehaviorConfig,
  BrandingConfig,
  ComponentsConfig,
  CursorConfig,
  EffectsConfig,
  GameCardsConfig,
  Gradient,
  HeroConfig,
  LayoutConfig,
  ParticlesConfig,
  PerformanceConfig,
  SeoConfig,
  SharingConfig,
  SocialConfig,
  ThemeBackgrounds,
  ThemeColors,
  ThemeConfig,
  TypographyConfig,
} from '../types';

// ---------------------------------------------------------------------------
// Theme colors — these are the exact tokens currently baked into index.css.
// Changing one here will be picked up live as soon as the studio applies the
// theme to <html style="--token: …">.
// ---------------------------------------------------------------------------
export function defaultThemeColors(): ThemeColors {
  return {
    bg_0: '#05070d',
    bg_1: '#0d111a',
    panel: 'rgba(18, 24, 36, 0.82)',
    panel_strong: 'rgba(16, 21, 33, 0.92)',
    text: '#d6deff',
    text_strong: '#eaf0ff',
    muted: '#7f8ba7',
    accent: '#73f8ff',
    accent_2: '#a673ff',
    danger: '#ff5fbf',
    success: '#3ecf8e',
    warning: '#f8d36b',
    border: 'rgba(115, 248, 255, 0.3)',
    link: '#73f8ff',
    link_hover: '#ffffff',
    card_bg_a: 'rgba(18, 24, 36, 0.82)',
    card_bg_b: 'rgba(16, 21, 33, 0.92)',
    card_border: 'rgba(115, 248, 255, 0.3)',
    card_hover_border: 'rgba(166, 115, 255, 0.7)',
    header_bg: 'rgba(18, 24, 36, 0.82)',
    header_border: 'rgba(115, 248, 255, 0.3)',
    header_title_color: '#eaf0ff',
    header_subtitle_color: '#7f8ba7',
    footer_text_color: '#66708a',
    nav_button_bg: 'rgba(11, 16, 25, 0.85)',
    nav_button_text: '#73f8ff',
    nav_button_border: 'rgba(115, 248, 255, 0.3)',
    nav_button_hover_bg_a: 'rgba(115, 248, 255, 0.25)',
    nav_button_hover_bg_b: 'rgba(166, 115, 255, 0.25)',
    nav_button_hover_text: '#ffffff',
    button_bg: 'rgba(11, 16, 25, 0.85)',
    button_text: '#73f8ff',
    button_border: 'rgba(115, 248, 255, 0.3)',
    button_hover_bg_a: 'rgba(115, 248, 255, 0.25)',
    button_hover_bg_b: 'rgba(166, 115, 255, 0.25)',
    tag_bg_a: 'rgba(115, 248, 255, 0.9)',
    tag_bg_b: 'rgba(166, 115, 255, 0.9)',
    tag_text: '#070b12',
    play_btn_a: 'rgba(115, 248, 255, 0.82)',
    play_btn_b: 'rgba(166, 115, 255, 0.82)',
    play_btn_text: '#061019',
    download_btn_a: 'rgba(255, 95, 191, 0.86)',
    download_btn_b: 'rgba(166, 115, 255, 0.82)',
    download_btn_text: '#f6f8ff',
    support_btn_a: 'rgba(115, 248, 255, 0.85)',
    support_btn_b: 'rgba(166, 115, 255, 0.85)',
    support_btn_text: '#08101a',
  };
}

// ---------------------------------------------------------------------------
// Body background — mirrors the layered radial + linear gradient in
// `body { background: ... }`.
// ---------------------------------------------------------------------------
function defaultBodyGradient(): Gradient {
  return {
    type: 'linear',
    angle: 130,
    size: '100% 100%',
    position: 'center',
    stops: [
      { id: 'g1', color: '#05070d', position: 0 },
      { id: 'g2', color: '#0d111a', position: 100 },
    ],
  };
}

export function defaultThemeBackgrounds(): ThemeBackgrounds {
  return {
    body_gradient: defaultBodyGradient(),
    body_radial_accent: {
      enabled: true,
      color: 'rgba(166, 115, 255, 0.10)',
      opacity: 1,
      size: '800px 600px',
      position: '85% 10%',
      falloff: 60,
    },
    body_image_url: '',
    body_image_size: 'cover',
    body_image_blend: 'overlay',
    body_image_opacity: 0.35,
    body_image_fixed: true,
    header_glow: {
      enabled: false,
      color: 'rgba(115, 248, 255, 0.18)',
      opacity: 1,
      size: '600px 240px',
      position: 'center top',
    },
  };
}

export function defaultThemeConfig(): ThemeConfig {
  return {
    enabled: false,
    display_name: 'Default — Cyber Violet',
    colors: defaultThemeColors(),
    background: defaultThemeBackgrounds(),
  };
}

// ---------------------------------------------------------------------------
// Effects.
// ---------------------------------------------------------------------------
export function defaultEffectsConfig(): EffectsConfig {
  return {
    scanlines: {
      enabled: true,
      opacity: 0.22,
      line_color: 'rgba(255, 255, 255, 0.03)',
      gap_color: 'rgba(0, 0, 0, 0.08)',
      spacing_px: 3,
    },
    noise: {
      enabled: true,
      opacity: 0.06,
      size_px: 3,
      speed_s: 0.18,
      color: 'rgba(255, 255, 255, 0.09)',
    },
    vignette: {
      enabled: true,
      opacity: 1,
      inner_stop: 45,
      color: 'rgba(0, 0, 0, 0.45)',
    },
    hue_shift: {
      enabled: true,
      opacity: 0.72,
      speed_s: 8,
      color_a: 'rgba(255, 95, 191, 0.03)',
      color_b: 'rgba(115, 248, 255, 0.02)',
      color_c: 'rgba(166, 115, 255, 0.03)',
      blend: 'screen',
    },
    cursor_spotlight: {
      enabled: true,
      color: 'rgba(115, 248, 255, 0.09)',
      opacity: 1,
      radius_x_px: 1100,
      radius_y_px: 700,
    },
    title_glitch: { enabled: true, intensity_px: 1, period_s: 5 },
    card_in_animation: { enabled: true, duration_ms: 450, stagger_ms: 35 },
    card_hover: {
      enabled: true,
      lift_px: 6,
      skew_deg: 0.5,
      glow_color: 'rgba(115, 248, 255, 0.24)',
      glow_strength: 28,
      shine: true,
    },
    scroll_jitter: { enabled: true },
    edge_sweep: { enabled: true, color: 'var(--accent)', period_s: 4 },
    reduce_motion: { honor_prefers: true },
    custom_css: '',
  };
}

// ---------------------------------------------------------------------------
// Typography.
// ---------------------------------------------------------------------------
export function defaultTypographyConfig(): TypographyConfig {
  return {
    google_fonts_url: '',
    font_family_base: "'Consolas', 'Space Mono', 'Courier New', monospace",
    font_family_heading: "'Consolas', 'Space Mono', 'Courier New', monospace",
    font_family_mono: "'Courier New', monospace",
    base_font_size_px: 16,
    base_line_height: 1.5,
    letter_spacing_em: 0.0125, // ~0.2px on 16px base
    heading_letter_spacing_em: 0.1875, // 3px on 16px base
    heading_text_transform: 'uppercase',
    heading_weight: 700,
    body_weight: 400,
    hero_title_size_rem: 3.5,
    hero_subtitle_size_rem: 0.9,
    card_title_size_rem: 1.3,
    link_underline: 'hover',
    heading_text_shadow:
      '0 0 12px rgba(115, 248, 255, 0.35), 0 0 26px rgba(166, 115, 255, 0.22)',
  };
}

// ---------------------------------------------------------------------------
// Layout.
// ---------------------------------------------------------------------------
export function defaultLayoutConfig(): LayoutConfig {
  return {
    container_max_width_px: 1400,
    container_padding_px: 20,
    base_padding_px: 20,
    border_radius_panel_px: 12,
    border_radius_card_px: 12,
    border_radius_button_px: 4,
    card_min_width_px: 280,
    card_gap_px: 25,
    card_thumbnail_height_px: 200,
    card_force_columns: 0,
    header_padding_v_px: 40,
    header_padding_h_px: 20,
    header_margin_bottom_px: 60,
    header_text_align: 'center',
    nav_alignment: 'center',
    nav_gap_px: 10,
    nav_position: 'top',
    footer_text_align: 'center',
    footer_padding_px: 30,
  };
}

// ---------------------------------------------------------------------------
// Components.
// ---------------------------------------------------------------------------
export function defaultComponentsConfig(): ComponentsConfig {
  return {
    card: {
      shadow: '0 20px 30px rgba(2, 4, 10, 0.35)',
      hover_shadow:
        '0 0 0 1px rgba(166, 115, 255, 0.4), 0 18px 38px rgba(0, 0, 0, 0.55), 0 0 28px rgba(115, 248, 255, 0.24)',
      border_width_px: 1,
      padding_px: 20,
      title_letter_spacing_em: 0,
    },
    button: {
      padding_v_px: 10,
      padding_h_px: 25,
      font_size_rem: 0.9,
      text_transform: 'uppercase',
      hover_translate_y_px: -1,
      border_width_px: 1,
      letter_spacing_em: 0,
    },
    panel: {
      blur_px: 6,
      border_width_px: 1,
      shadow: '0 8px 28px rgba(0, 0, 0, 0.25)',
    },
    modal: {
      backdrop_blur_px: 3,
      backdrop_color: 'rgba(2, 4, 10, 0.82)',
      width_max_px: 800,
    },
    promo_card: {
      accent_border: false,
      title_uppercase: true,
    },
  };
}

// ---------------------------------------------------------------------------
// Behavior.
// ---------------------------------------------------------------------------
export function defaultBehaviorConfig(): BehaviorConfig {
  return {
    show_vault_link: true,
    show_devlog_link: true,
    show_filter_buttons: true,
    show_support_section: true,
    show_footer: true,
    show_admin_link_in_nav: true,
    default_game_filter: 'all',
    maintenance_mode: {
      enabled: false,
      title: 'We’ll be right back',
      message: 'The hub is in maintenance. Check back soon.',
      allow_admin_bypass: true,
    },
    homepage_intro: { enabled: false, html: '' },
    game_card_hover_effect: 'lift',
    homepage_autoplay_previews: false,
    click_sound_url: '',
    click_sound_volume: 0.4,
  };
}

// ---------------------------------------------------------------------------
// SEO.
// ---------------------------------------------------------------------------
export function defaultSeoConfig(): SeoConfig {
  return {
    title_template: '%s — Criminally Dev Dads',
    default_meta_description:
      'Criminally Dev Dads is a small indie collective making fast, weird browser games and tools.',
    og_image_url: '',
    twitter_handle: '',
    favicon_url: '',
    analytics_provider: 'none',
    analytics_id: '',
    analytics_script_src: '',
    theme_color: '#0d111a',
  };
}

// ===========================================================================
// Studio expansion (migration 017). One default-factory per JSONB column.
// Every option is opt-in: defaults are conservative so flipping the column
// on doesn't suddenly change the live site until the admin picks values.
// ===========================================================================

// Animations -----------------------------------------------------------------
export function defaultAnimationsConfig(): AnimationsConfig {
  return {
    enabled: true,
    page_entrance: 'fade-in',
    page_entrance_duration_ms: 320,
    route_fade_ms: 200,
    card_entrance: 'none', // legacy `effects.card_in_animation` already handles this; opt-in here.
    card_entrance_stagger_ms: 35,
    hero_idle: 'none',
    hero_idle_period_s: 6,
    button_hover: 'none',
    promo_entrance: 'slide-down',
  };
}

// Audio ----------------------------------------------------------------------
export function defaultAudioConfig(): AudioConfig {
  return {
    master_volume: 0.5,
    muted: false,
    background_music_url: '',
    background_music_volume: 0.3,
    background_music_autoplay: false,
    background_music_loop: true,
    hover_sound_url: '',
    hover_sound_volume: 0.4,
    ambient_loop_url: '',
    ambient_loop_volume: 0.2,
    show_mute_toggle: false,
  };
}

// Cursor ---------------------------------------------------------------------
export function defaultCursorConfig(): CursorConfig {
  return {
    enabled: false,
    style: 'default',
    emoji: '👑',
    image_url: '',
    size_px: 28,
    trail: { enabled: false, color: 'rgba(115, 248, 255, 0.5)', length: 6, size_px: 10 },
    click_ripple: { enabled: false, color: 'rgba(166, 115, 255, 0.45)', size_px: 80 },
    hide_os_cursor: false,
  };
}

// Particles ------------------------------------------------------------------
export function defaultParticlesConfig(): ParticlesConfig {
  return {
    enabled: false,
    kind: 'stars',
    count: 60,
    color: 'rgba(255, 255, 255, 0.65)',
    speed_min: 0.1,
    speed_max: 0.6,
    size_min_px: 1,
    size_max_px: 3,
    direction: 'down',
    z_index: 'behind',
    opacity: 0.8,
    respect_reduce_motion: true,
  };
}

// Social ---------------------------------------------------------------------
export function defaultSocialConfig(): SocialConfig {
  return {
    show_in_header: false,
    show_in_footer: true,
    style: 'monochrome',
    size_px: 20,
    links: [],
  };
}

// Hero -----------------------------------------------------------------------
export function defaultHeroConfig(): HeroConfig {
  return {
    logo_image_url: '',
    logo_max_height_px: 96,
    show_title: true,
    show_subtitle: true,
    tagline: '',
    badge: { enabled: false, text: 'OPEN BETA', color: '#06070d', bg: '#fcc419' },
    scroll_indicator: { enabled: false, emoji: '↓', color: 'var(--accent)' },
    buttons: [],
  };
}

// Game cards -----------------------------------------------------------------
export function defaultGameCardsConfig(): GameCardsConfig {
  return {
    show_thumbnail: true,
    show_type_tag: true,
    show_description: true,
    show_price: true,
    title_case: 'none',
    new_ribbon: { enabled: false, text: 'NEW', color: '#06070d', bg: '#3ecf8e', days: 7 },
    badge: { enabled: false, symbol: '★', color: '#ffd166' },
    layout: 'standard',
  };
}

// Branding -------------------------------------------------------------------
export function defaultBrandingConfig(): BrandingConfig {
  return {
    site_name: 'Criminally Dev Dads',
    header_logo_url: '',
    header_logo_height_px: 32,
    header_tagline: '',
    footer_copyright_template: '© {year} {name} — All rights reserved.',
    footer_show_auto_copyright: false,
    watermark_text: '',
    watermark_url: '',
    show_made_with: false,
  };
}

// Performance ----------------------------------------------------------------
export function defaultPerformanceConfig(): PerformanceConfig {
  return {
    disable_all_animations: false,
    disable_backdrop_filter: false,
    disable_blur_effects: false,
    image_lazy_load: true,
    prefetch_nav: false,
    battery_saver: false,
  };
}

// Accessibility --------------------------------------------------------------
export function defaultAccessibilityConfig(): AccessibilityConfig {
  return {
    focus_ring_color: '#73f8ff',
    focus_ring_width_px: 2,
    focus_ring_style: 'solid',
    font_size_scale: 1,
    dyslexia_friendly_font: false,
    always_underline_links: false,
    high_contrast_mode: false,
    skip_link_enabled: false,
  };
}

// Sharing --------------------------------------------------------------------
export function defaultSharingConfig(): SharingConfig {
  return {
    show_on_games: false,
    show_on_pages: false,
    twitter: true,
    reddit: true,
    bluesky: false,
    facebook: false,
    hacker_news: false,
    copy_link: true,
    email: false,
    text_template: 'Check out {title} on {site}',
  };
}

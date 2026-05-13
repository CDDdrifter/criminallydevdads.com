/**
 * themeApply.ts
 *
 * Renders an Admin Studio `SiteSettings` payload into live CSS.
 *
 * Two outputs:
 *   1. CSS custom properties on <html style="..."> — keys exactly match the
 *      tokens used in `src/index.css` so existing rules continue to work
 *      (e.g. `var(--accent)` instantly picks up the new colour).
 *   2. A generated <style id="site-studio-css"> block appended to <head>
 *      that emits more invasive overrides (gradient backgrounds, FX
 *      opacities, layout sizes, component shadows). Reading-only rules go
 *      through CSS variables instead, which is much cheaper.
 *
 * Idempotent: call repeatedly. Replaces the previous generated rules.
 */

import type {
  EffectsConfig,
  Gradient,
  GradientStop,
  LayoutConfig,
  SiteSettings,
  ThemeBackgrounds,
  ThemeColors,
  ThemeConfig,
  TypographyConfig,
} from '../types';

// ---------------------------------------------------------------------------
// DOM ids — keep stable so consecutive calls just rewrite the same nodes.
// ---------------------------------------------------------------------------
const STUDIO_STYLE_ID = 'site-studio-css';
const FONTS_LINK_ID = 'site-studio-fonts';
const HEAD_HTML_ID = 'site-studio-head-html';
const ANALYTICS_ID = 'site-studio-analytics';

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/** Renders a `Gradient` to a CSS `background-image` value. */
function gradientToCss(g: Gradient): string {
  const stops = [...(g.stops ?? [])]
    .filter((s): s is GradientStop => Boolean(s))
    .sort((a, b) => a.position - b.position)
    .map((s) => `${s.color} ${Number(s.position).toFixed(2)}%`)
    .join(', ');
  if (!stops) return 'transparent';
  if (g.type === 'radial') {
    const pos = g.position?.trim() || 'center';
    const size = g.size?.trim() || '600px 400px';
    return `radial-gradient(${size} at ${pos}, ${stops})`;
  }
  if (g.type === 'conic') {
    const pos = g.position?.trim() || 'center';
    return `conic-gradient(from ${g.angle ?? 0}deg at ${pos}, ${stops})`;
  }
  return `linear-gradient(${g.angle ?? 130}deg, ${stops})`;
}

/** Convert ThemeColors into a CSS-variable string ready for `style="…"`. */
function colorsToVars(c: ThemeColors): Record<string, string> {
  const v: Record<string, string> = {
    '--bg-0': c.bg_0,
    '--bg-1': c.bg_1,
    '--panel': c.panel,
    '--panel-strong': c.panel_strong,
    '--text': c.text,
    '--text-strong': c.text_strong,
    '--muted': c.muted,
    '--accent': c.accent,
    '--accent-2': c.accent_2,
    '--danger': c.danger,
    '--success': c.success,
    '--warning': c.warning,
    '--border': c.border,
    '--link': c.link,
    '--link-hover': c.link_hover,
    '--card-bg-a': c.card_bg_a,
    '--card-bg-b': c.card_bg_b,
    '--card-border': c.card_border,
    '--card-hover-border': c.card_hover_border,
    '--header-bg': c.header_bg,
    '--header-border': c.header_border,
    '--header-title-color': c.header_title_color,
    '--header-subtitle-color': c.header_subtitle_color,
    '--footer-text-color': c.footer_text_color,
    '--nav-button-bg': c.nav_button_bg,
    '--nav-button-text': c.nav_button_text,
    '--nav-button-border': c.nav_button_border,
    '--nav-button-hover-bg-a': c.nav_button_hover_bg_a,
    '--nav-button-hover-bg-b': c.nav_button_hover_bg_b,
    '--nav-button-hover-text': c.nav_button_hover_text,
    '--button-bg': c.button_bg,
    '--button-text': c.button_text,
    '--button-border': c.button_border,
    '--button-hover-bg-a': c.button_hover_bg_a,
    '--button-hover-bg-b': c.button_hover_bg_b,
    '--tag-bg-a': c.tag_bg_a,
    '--tag-bg-b': c.tag_bg_b,
    '--tag-text': c.tag_text,
    '--play-btn-a': c.play_btn_a,
    '--play-btn-b': c.play_btn_b,
    '--play-btn-text': c.play_btn_text,
    '--download-btn-a': c.download_btn_a,
    '--download-btn-b': c.download_btn_b,
    '--download-btn-text': c.download_btn_text,
    '--support-btn-a': c.support_btn_a,
    '--support-btn_b': c.support_btn_b, // legacy typo guard for older snapshots
    '--support-btn-b': c.support_btn_b,
    '--support-btn-text': c.support_btn_text,
  };
  return v;
}

/** Apply CSS vars to <html>. Returns the previously-set keys for cleanup. */
function setCssVars(root: HTMLElement, vars: Record<string, string>) {
  Object.entries(vars).forEach(([k, v]) => {
    if (v && typeof v === 'string') {
      root.style.setProperty(k, v);
    } else {
      root.style.removeProperty(k);
    }
  });
}

// ---------------------------------------------------------------------------
// Studio CSS generation
// ---------------------------------------------------------------------------

function buildBodyBackground(bg: ThemeBackgrounds): string {
  const layers: string[] = [];
  if (bg.body_image_url?.trim()) {
    layers.push(`url("${bg.body_image_url.replace(/"/g, '\\"')}")`);
  }
  if (bg.body_radial_accent?.enabled) {
    const a = bg.body_radial_accent;
    const size = a.size?.trim() || '800px 600px';
    const pos = a.position?.trim() || '85% 10%';
    const falloff = Math.max(0, Math.min(100, a.falloff ?? 60));
    layers.push(
      `radial-gradient(${size} at ${pos}, ${a.color}, transparent ${falloff}%)`,
    );
  }
  layers.push(gradientToCss(bg.body_gradient));
  return layers.filter(Boolean).join(', ');
}

function buildEffectsCss(fx: EffectsConfig): string {
  const out: string[] = [];

  // --- Scanlines layer ------------------------------------------------------
  out.push(`
.fx-scanlines {
  background: repeating-linear-gradient(
    to bottom,
    ${fx.scanlines.line_color} 0px,
    ${fx.scanlines.line_color} 1px,
    ${fx.scanlines.gap_color} ${fx.scanlines.spacing_px - 1}px,
    ${fx.scanlines.gap_color} ${fx.scanlines.spacing_px}px
  );
  opacity: ${fx.scanlines.opacity};
}`);

  // --- Noise layer ----------------------------------------------------------
  out.push(`
.fx-noise {
  background-image: radial-gradient(${fx.noise.color} 0.5px, transparent 0.5px);
  background-size: ${fx.noise.size_px}px ${fx.noise.size_px}px;
  opacity: ${fx.noise.opacity};
  animation: noiseShift ${fx.noise.speed_s}s infinite steps(2);
}`);

  // --- Vignette layer -------------------------------------------------------
  out.push(`
.fx-vignette {
  background: radial-gradient(circle at center, transparent ${fx.vignette.inner_stop}%, ${fx.vignette.color} 100%);
  opacity: ${fx.vignette.opacity};
}`);

  // --- Hue shift wash (body::before) ---------------------------------------
  out.push(`
body::before {
  background: linear-gradient(
    90deg,
    ${fx.hue_shift.color_a},
    ${fx.hue_shift.color_b} 25%,
    ${fx.hue_shift.color_c} 60%,
    ${fx.hue_shift.color_a}
  );
  mix-blend-mode: ${fx.hue_shift.blend};
  animation: hueShift ${fx.hue_shift.speed_s}s infinite linear;
  opacity: ${fx.hue_shift.opacity};
}`);

  // --- Cursor spotlight (body::after) --------------------------------------
  out.push(`
body::after {
  background: radial-gradient(
    ${fx.cursor_spotlight.radius_x_px}px ${fx.cursor_spotlight.radius_y_px}px
    at var(--cursor-x) var(--cursor-y),
    ${fx.cursor_spotlight.color},
    transparent 55%
  );
  opacity: ${fx.cursor_spotlight.opacity};
}`);

  // --- Card-in animation ---------------------------------------------------
  if (fx.card_in_animation.enabled) {
    out.push(`
.game-card {
  animation: cardIn ${fx.card_in_animation.duration_ms}ms ease both;
  animation-delay: calc(var(--i, 0) * ${fx.card_in_animation.stagger_ms}ms);
}`);
  } else {
    out.push(`.game-card { animation: none !important; }`);
  }

  // --- Card hover ----------------------------------------------------------
  if (fx.card_hover.enabled) {
    out.push(`
.game-card:hover {
  transform: translateY(-${fx.card_hover.lift_px}px) skewX(-${fx.card_hover.skew_deg}deg);
  box-shadow:
    0 0 0 1px var(--card-hover-border),
    0 18px 38px rgba(0, 0, 0, 0.55),
    0 0 ${fx.card_hover.glow_strength}px ${fx.card_hover.glow_color};
}`);
  } else {
    out.push(`.game-card:hover { transform: none; }`);
  }
  if (!fx.card_hover.shine) {
    out.push(`.game-card::before { display: none !important; }`);
  }

  // --- Title glitch --------------------------------------------------------
  if (fx.title_glitch.enabled) {
    out.push(`
.header-title {
  animation: titleGlitch ${fx.title_glitch.period_s}s infinite steps(2);
}`);
  } else {
    out.push(`.header-title { animation: none !important; }`);
  }

  // --- Edge sweep (header underline) ---------------------------------------
  if (fx.edge_sweep.enabled) {
    out.push(`
header::after {
  background: linear-gradient(90deg, transparent, ${fx.edge_sweep.color}, transparent);
  animation: edgeSweep ${fx.edge_sweep.period_s}s linear infinite;
}`);
  } else {
    out.push(`header::after { display: none !important; }`);
  }

  // --- Scroll jitter -------------------------------------------------------
  if (!fx.scroll_jitter.enabled) {
    out.push(`body.scrolling .container { animation: none !important; }`);
  }

  // --- Reduce-motion accessibility -----------------------------------------
  if (fx.reduce_motion.honor_prefers) {
    out.push(`
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.001ms !important; animation-iteration-count: 1 !important; transition-duration: 0.001ms !important; }
}`);
  }

  // --- Optional appended CSS (last so it wins) -----------------------------
  if (fx.custom_css?.trim()) {
    out.push(`/* effects.custom_css */\n${fx.custom_css}`);
  }
  return out.join('\n');
}

function buildTypographyCss(t: TypographyConfig): string {
  const underlineRule = (() => {
    switch (t.link_underline) {
      case 'always':
        return 'a { text-decoration: underline; } a:hover { text-decoration: underline; }';
      case 'never':
        return 'a, a:hover { text-decoration: none; }';
      default:
        return 'a { text-decoration: none; } a:hover { text-decoration: underline; }';
    }
  })();
  return `
:root {
  --studio-font-base: ${t.font_family_base};
  --studio-font-heading: ${t.font_family_heading};
  --studio-font-mono: ${t.font_family_mono};
}
body {
  font-family: ${t.font_family_base};
  font-size: ${t.base_font_size_px}px;
  line-height: ${t.base_line_height};
  letter-spacing: ${t.letter_spacing_em}em;
  font-weight: ${t.body_weight};
}
.header-title {
  font-family: ${t.font_family_heading};
  font-size: ${t.hero_title_size_rem}rem;
  font-weight: ${t.heading_weight};
  letter-spacing: ${t.heading_letter_spacing_em}em;
  text-transform: ${t.heading_text_transform};
  text-shadow: ${t.heading_text_shadow};
}
.header-subtitle {
  font-size: ${t.hero_subtitle_size_rem}rem;
}
.game-title {
  font-size: ${t.card_title_size_rem}rem;
  font-family: ${t.font_family_heading};
  font-weight: ${t.heading_weight};
}
code, pre {
  font-family: ${t.font_family_mono};
}
${underlineRule}
`;
}

function buildLayoutCss(l: LayoutConfig): string {
  // Force-columns lets admin override the auto-fill grid.
  const gridTemplate =
    l.card_force_columns > 0
      ? `repeat(${l.card_force_columns}, minmax(0, 1fr))`
      : `repeat(auto-fill, minmax(${l.card_min_width_px}px, 1fr))`;

  // Sticky nav opt-in keeps the header in flow but pins the top bar.
  const stickyNav =
    l.nav_position === 'sticky'
      ? `.top-nav { position: sticky; top: 0; z-index: 10; padding-top: 8px; padding-bottom: 8px; background: rgba(5, 7, 13, 0.55); backdrop-filter: blur(8px); border-radius: 12px; }`
      : '';

  return `
.container {
  max-width: ${l.container_max_width_px}px;
}
body {
  padding: ${l.container_padding_px}px;
}
header {
  padding: ${l.header_padding_v_px}px ${l.header_padding_h_px}px;
  margin-bottom: ${l.header_margin_bottom_px}px;
  text-align: ${l.header_text_align};
  border-radius: ${l.border_radius_panel_px}px;
}
.top-nav {
  justify-content: ${l.nav_alignment};
  gap: ${l.nav_gap_px}px;
}
${stickyNav}
.game-grid {
  grid-template-columns: ${gridTemplate};
  gap: ${l.card_gap_px}px;
}
.game-card, .admin-panel, .modal-content, .page-section-panel {
  border-radius: ${l.border_radius_panel_px}px;
}
.game-card {
  border-radius: ${l.border_radius_card_px}px;
}
.game-thumbnail {
  height: ${l.card_thumbnail_height_px}px;
}
button, .btn-play, .btn-download, .btn-support {
  border-radius: ${l.border_radius_button_px}px;
}
footer {
  text-align: ${l.footer_text_align};
  padding: ${l.footer_padding_px}px;
}
`;
}

function buildComponentsCss(comp: SiteSettings['components']): string {
  return `
.game-card {
  box-shadow: ${comp.card.shadow};
  border-width: ${comp.card.border_width_px}px;
}
.game-card:hover {
  /* fx layer rebuilds the box-shadow during hover; respect that.  */
}
.game-info {
  padding: ${comp.card.padding_px}px;
}
.game-title {
  letter-spacing: ${comp.card.title_letter_spacing_em}em;
}
button, .top-nav button, .top-nav a {
  padding: ${comp.button.padding_v_px}px ${comp.button.padding_h_px}px;
  font-size: ${comp.button.font_size_rem}rem;
  text-transform: ${comp.button.text_transform};
  border-width: ${comp.button.border_width_px}px;
  letter-spacing: ${comp.button.letter_spacing_em}em;
}
button:hover, button.active {
  transform: translateY(${comp.button.hover_translate_y_px}px);
}
.admin-panel, header {
  backdrop-filter: blur(${comp.panel.blur_px}px);
  border-width: ${comp.panel.border_width_px}px;
}
.promo-card {
  box-shadow: ${comp.panel.shadow};
}
.modal {
  background: ${comp.modal.backdrop_color};
  backdrop-filter: blur(${comp.modal.backdrop_blur_px}px);
}
.modal-content {
  max-width: ${comp.modal.width_max_px}px;
}
`;
}

function buildThemeCss(theme: ThemeConfig): string {
  if (!theme.enabled) {
    // Studio not enabled: only emit hover/border tokens so legacy preset rules dominate.
    return '';
  }
  const bg = buildBodyBackground(theme.background);
  const headerGlow =
    theme.background.header_glow?.enabled
      ? `
header {
  position: relative;
}
header::before {
  content: '';
  position: absolute;
  inset: 0;
  background: radial-gradient(${theme.background.header_glow.size} at ${theme.background.header_glow.position}, ${theme.background.header_glow.color}, transparent 60%);
  opacity: ${theme.background.header_glow.opacity};
  pointer-events: none;
  border-radius: inherit;
}
`
      : '';
  // Image overlay opacity & blend (only takes effect when an image URL is set).
  const imgRules = theme.background.body_image_url?.trim()
    ? `
body {
  background-size: ${theme.background.body_image_size}, auto, auto;
  background-repeat: ${theme.background.body_image_size === 'repeat' ? 'repeat' : 'no-repeat'}, no-repeat, no-repeat;
  background-attachment: ${theme.background.body_image_fixed ? 'fixed' : 'scroll'}, scroll, scroll;
  background-blend-mode: ${theme.background.body_image_blend}, normal, normal;
}
`
    : '';
  return `
body {
  background: ${bg};
  color: var(--text);
}
header {
  background: var(--header-bg);
  border-color: var(--header-border);
}
.header-title { color: var(--header-title-color); }
.header-subtitle { color: var(--header-subtitle-color); }
.top-nav a, .top-nav button {
  background: var(--nav-button-bg);
  color: var(--nav-button-text);
  border-color: var(--nav-button-border);
}
.top-nav a:hover, .top-nav button:hover {
  background: linear-gradient(135deg, var(--nav-button-hover-bg-a), var(--nav-button-hover-bg-b));
  color: var(--nav-button-hover-text);
}
button {
  background: var(--button-bg);
  color: var(--button-text);
  border-color: var(--button-border);
}
button:hover, button.active {
  background: linear-gradient(135deg, var(--button-hover-bg-a), var(--button-hover-bg-b));
  color: var(--nav-button-hover-text);
}
.game-card {
  background: linear-gradient(165deg, var(--card-bg-a) 0%, var(--card-bg-b) 100%);
  border-color: var(--card-border);
}
.game-card:hover {
  border-color: var(--card-hover-border);
}
.game-type {
  background: linear-gradient(90deg, var(--tag-bg-a), var(--tag-bg-b));
  color: var(--tag-text);
}
.btn-play {
  background: linear-gradient(120deg, var(--play-btn-a), var(--play-btn-b));
  color: var(--play-btn-text);
}
.btn-download {
  background: linear-gradient(120deg, var(--download-btn-a), var(--download-btn-b));
  color: var(--download-btn-text);
}
.btn-support {
  background: linear-gradient(120deg, var(--support-btn-a), var(--support-btn-b));
  color: var(--support-btn-text);
}
footer { color: var(--footer-text-color); }
${imgRules}
${headerGlow}
`;
}

// ---------------------------------------------------------------------------
// Game card hover variants — picked by behavior.game_card_hover_effect.
// Each preset is rendered as a CSS string and swapped in by id.
// ---------------------------------------------------------------------------
function buildHoverEffectCss(kind: SiteSettings['behavior']['game_card_hover_effect']): string {
  switch (kind) {
    case 'tilt':
      return `.game-card:hover { transform: rotate(-1.2deg) scale(1.02); }`;
    case 'pulse':
      return `
@keyframes studioPulse {
  0%, 100% { box-shadow: 0 0 0 0 var(--card-hover-border, rgba(166,115,255,0.4)); }
  50% { box-shadow: 0 0 0 8px transparent; }
}
.game-card:hover { animation: studioPulse 1.2s ease-in-out infinite; }`;
    case 'glow':
      return `.game-card:hover { box-shadow: 0 0 40px 0 var(--accent), 0 0 80px 0 var(--accent-2); }`;
    case 'shine':
      return `.game-card:hover::before { transform: translateX(140%); }`;
    case 'none':
      return `.game-card:hover { transform: none; box-shadow: none; }`;
    case 'lift':
    default:
      return ''; // default lift handled in effects.
  }
}

// ---------------------------------------------------------------------------
// Behavior visibility — quick CSS toggles for nav-link / section hiding so the
// frontend doesn't have to read the settings everywhere. Components that
// fully unmount should still check `behavior.*` directly.
// ---------------------------------------------------------------------------
function buildBehaviorCss(b: SiteSettings['behavior']): string {
  const rules: string[] = [];
  if (!b.show_filter_buttons) rules.push(`.filter-buttons { display: none !important; }`);
  if (!b.show_support_section) rules.push(`.support-section { display: none !important; }`);
  if (!b.show_footer) rules.push(`footer { display: none !important; }`);
  return rules.join('\n');
}

// ---------------------------------------------------------------------------
// Side effects: fonts <link>, analytics <script>, free-form head HTML.
// ---------------------------------------------------------------------------

function applyGoogleFonts(url: string) {
  const id = FONTS_LINK_ID;
  let el = document.getElementById(id) as HTMLLinkElement | null;
  if (!url) {
    el?.remove();
    return;
  }
  if (!el) {
    el = document.createElement('link');
    el.id = id;
    el.rel = 'stylesheet';
    document.head.appendChild(el);
  }
  if (el.href !== url) {
    el.href = url;
  }
}

function applyAnalytics(seo: SiteSettings['seo']) {
  // Remove old analytics block before installing a new one.
  document.getElementById(ANALYTICS_ID)?.remove();
  if (seo.analytics_provider === 'none' || (!seo.analytics_id && !seo.analytics_script_src)) {
    return;
  }
  const wrap = document.createElement('div');
  wrap.id = ANALYTICS_ID;
  wrap.style.display = 'none';

  if (seo.analytics_provider === 'plausible' && seo.analytics_id) {
    const s = document.createElement('script');
    s.defer = true;
    s.dataset.domain = seo.analytics_id;
    s.src = seo.analytics_script_src?.trim() || 'https://plausible.io/js/script.js';
    wrap.appendChild(s);
  } else if (seo.analytics_provider === 'umami' && seo.analytics_id) {
    const s = document.createElement('script');
    s.defer = true;
    s.dataset.websiteId = seo.analytics_id;
    s.src = seo.analytics_script_src?.trim() || 'https://cloud.umami.is/script.js';
    wrap.appendChild(s);
  } else if (seo.analytics_provider === 'ga4' && seo.analytics_id) {
    const s = document.createElement('script');
    s.async = true;
    s.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(seo.analytics_id)}`;
    wrap.appendChild(s);
    const init = document.createElement('script');
    init.textContent = `window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);} gtag('js',new Date()); gtag('config','${seo.analytics_id.replace(/'/g, '')}');`;
    wrap.appendChild(init);
  } else if (seo.analytics_provider === 'custom' && seo.analytics_script_src) {
    const s = document.createElement('script');
    s.defer = true;
    s.src = seo.analytics_script_src;
    if (seo.analytics_id) s.dataset.id = seo.analytics_id;
    wrap.appendChild(s);
  }
  document.head.appendChild(wrap);
}

function applyHeadHtml(html: string) {
  // Lives inside a single wrapper div so we can swap atomically without
  // accidentally removing analytics, fonts, or the favicon link.
  let el = document.getElementById(HEAD_HTML_ID);
  if (!html.trim()) {
    el?.remove();
    return;
  }
  if (!el) {
    el = document.createElement('div');
    el.id = HEAD_HTML_ID;
    el.style.display = 'none';
    document.head.appendChild(el);
  }
  el.innerHTML = html;
}

function applyFavicon(url: string) {
  if (!url.trim()) return;
  let link = document.querySelector<HTMLLinkElement>('link[rel="icon"]');
  if (!link) {
    link = document.createElement('link');
    link.rel = 'icon';
    document.head.appendChild(link);
  }
  if (link.href !== url) link.href = url;
}

function applyThemeColor(color: string) {
  if (!color.trim()) return;
  let meta = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'theme-color';
    document.head.appendChild(meta);
  }
  meta.content = color;
}

function applyMetaDescription(text: string) {
  if (!text.trim()) return;
  let meta = document.querySelector<HTMLMetaElement>('meta[name="description"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'description';
    document.head.appendChild(meta);
  }
  meta.content = text;
}

function applyOgImage(url: string) {
  if (!url.trim()) return;
  let meta = document.querySelector<HTMLMetaElement>('meta[property="og:image"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.setAttribute('property', 'og:image');
    document.head.appendChild(meta);
  }
  meta.content = url;
}

// ---------------------------------------------------------------------------
// Public API.
// ---------------------------------------------------------------------------

export function applyStudioTheme(settings: SiteSettings) {
  if (typeof document === 'undefined') return;

  // 1. CSS variables from theme colours (always set, regardless of "enabled"
  //    so that effects/typography rules still get sensible colour tokens).
  setCssVars(document.documentElement, colorsToVars(settings.theme.colors));

  // 2. Generated stylesheet.
  let style = document.getElementById(STUDIO_STYLE_ID) as HTMLStyleElement | null;
  if (!style) {
    style = document.createElement('style');
    style.id = STUDIO_STYLE_ID;
    document.head.appendChild(style);
  }

  const parts: string[] = [
    buildThemeCss(settings.theme),
    buildTypographyCss(settings.typography),
    buildLayoutCss(settings.layout),
    buildComponentsCss(settings.components),
    buildEffectsCss(settings.effects),
    buildBehaviorCss(settings.behavior),
    buildHoverEffectCss(settings.behavior.game_card_hover_effect),
  ];
  style.textContent = parts.filter(Boolean).join('\n\n');

  // 3. Side effects.
  applyGoogleFonts(settings.typography.google_fonts_url.trim());
  applyAnalytics(settings.seo);
  applyHeadHtml(settings.custom_head_html);
  applyFavicon(settings.seo.favicon_url);
  applyThemeColor(settings.seo.theme_color);
  applyMetaDescription(settings.seo.default_meta_description);
  applyOgImage(settings.seo.og_image_url);
}

/** Removes everything `applyStudioTheme` set. Useful for tests / unmounts. */
export function unapplyStudioTheme() {
  if (typeof document === 'undefined') return;
  document.getElementById(STUDIO_STYLE_ID)?.remove();
  document.getElementById(FONTS_LINK_ID)?.remove();
  document.getElementById(HEAD_HTML_ID)?.remove();
  document.getElementById(ANALYTICS_ID)?.remove();
}

// ---------------------------------------------------------------------------
// Helpers exported for the admin preview UI (so we can render the gradient
// chip without reimplementing the string format).
// ---------------------------------------------------------------------------
export const __testing = { gradientToCss, buildBodyBackground };

export function previewGradientCss(g: Gradient): string {
  return gradientToCss(g);
}

export function previewBodyBackgroundCss(bg: ThemeBackgrounds): string {
  return buildBodyBackground(bg);
}

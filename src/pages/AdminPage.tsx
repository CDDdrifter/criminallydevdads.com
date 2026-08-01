import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useSiteSettings } from '../hooks/useSiteSettings';
import {
  deleteDevLogSlug,
  deleteGameBySlug,
  deleteNavId,
  deletePageSlug,
  fetchAllDevLogsAdmin,
  fetchAllGamesAdmin,
  fetchAllNavAdmin,
  fetchAllPagesAdmin,
  fetchPageBySlug,
  fetchSiteSettings,
  saveSiteSettings,
  upsertDevLog,
  upsertGame,
  upsertNav,
  upsertPage,
} from '../lib/cmsData';
import { HrefQuickPick } from '../components/admin/HrefQuickPick';
import { PageSectionsForm, ensureSectionIds } from '../components/admin/PageSectionsForm';
import {
  deleteGameBuild,
  publicGameEntryUrl,
  repairGameBuildContentTypes,
  sanitizeGameStorageSlug,
  uploadGamePreviewVideo,
  uploadGameTabIcon,
  uploadGameThumbnail,
  uploadGameZip,
} from '../lib/gameStorageUpload';
import {
  invokeSyncAllCmsToGitHub,
  invokeSyncGamesJsonToGitHub,
  invokeSyncSiteContentToGitHub,
} from '../lib/syncRepoGitHub';
import { blockingSiteSettingsIssues, softSiteSettingsLinkHints } from '../lib/adminSettingsValidate';
import { donationPresetsFromUnknown } from '../lib/gamePricing';
import { unknownColumnFromPostgrestMessage } from '../lib/postgrestUnknownColumn';
import { formatSupabaseWriteError, isRlsOrPermissionError } from '../lib/supabaseWriteError';
import { ADMIN_CMS_TABS, ADMIN_OVERVIEW_CARDS, ADMIN_STUDIO_TABS } from '../lib/adminLabels';
import { defaultRouteFxOverride, normalizeRouteFxOverride } from '../lib/routeFx';
import { normalizeVisualPresetInput } from '../lib/visualPresets';
import { AdminStudioPreview } from '../components/admin/AdminStudioPreview';
import { RouteAppearancePanel } from '../components/admin/RouteAppearancePanel';
import { AnalyticsStudio } from '../components/admin/tabs/AnalyticsStudio';
import { MailingListStudio } from '../components/admin/tabs/MailingListStudio';
import { ServicesAdminTab } from '../components/admin/tabs/ServicesAdminTab';
import { PrebuiltPagesStudio } from '../components/admin/tabs/PrebuiltPagesStudio';
import { LegalStudio } from '../components/admin/tabs/LegalStudio';
import { AdminAiAssistant } from '../components/admin/AdminAiAssistant';
import { FloatingSettingsSaveBar } from '../components/admin/FloatingSettingsSaveBar';
import { ADMIN_AI_PAGE_DRAFT_KEY } from '../lib/adminAi/types';
import { fetchAllServicesAdmin } from '../lib/servicesData';
import { BehaviorStudio } from '../components/admin/tabs/BehaviorStudio';
import { BrandHeroStudio } from '../components/admin/tabs/BrandHeroStudio';
import { ComponentsStudio } from '../components/admin/tabs/ComponentsStudio';
import { EffectsStudio } from '../components/admin/tabs/EffectsStudio';
import { HomepageStudio } from '../components/admin/tabs/HomepageStudio';
import { LayoutStudio } from '../components/admin/tabs/LayoutStudio';
import { MediaStudio } from '../components/admin/tabs/MediaStudio';
import { MotionStudio } from '../components/admin/tabs/MotionStudio';
import { SeoStudio } from '../components/admin/tabs/SeoStudio';
import { SocialStudio } from '../components/admin/tabs/SocialStudio';
import { SystemStudio } from '../components/admin/tabs/SystemStudio';
import { ThemeStudio } from '../components/admin/tabs/ThemeStudio';
import { TypographyStudio } from '../components/admin/tabs/TypographyStudio';
import type {
  DevLogPost,
  GamePricingModel,
  GameRecord,
  NavItem,
  PageSection,
  SiteEvent,
  SitePage,
  SiteSettings,
  SupportButton,
  ThemePreset,
} from '../types';
import { hireUsPageDraft } from '../lib/pageTemplates';
import { defaultSiteSettings } from '../types';

/**
 * Tabs in the Admin shell.
 *
 * The first batch (`overview` → `devlogs`) is the original CMS surface.
 * The second batch (`theme` → `seo`) is the new "Studio" layer added in
 * migration 016 — every tab reads/writes one slice of `SiteSettings` and
 * `SiteThemeApply` repaints the live page from those slices.
 */
type Tab =
  | 'overview'
  | 'ai'
  | 'settings'
  | 'services'
  | 'games'
  | 'pages'
  | 'prebuilt'
  | 'nav'
  | 'devlogs'
  | 'legal'
  | 'theme'
  | 'effects'
  | 'typography'
  | 'layout'
  | 'components'
  | 'behavior'
  | 'seo'
  // Studio expansion (migration 017).
  | 'brand'
  | 'social'
  | 'motion'
  | 'media'
  | 'system'
  | 'analytics'
  | 'mailing';

function describeAdminWriteFailure(err: unknown): string {
  const core = formatSupabaseWriteError(err);
  if (isRlsOrPermissionError(err)) {
    return `${core}\n\nRow security / permission: you must be signed in as an allowed editor. In Supabase, check site_admin_domains and site_admin_emails for this project. Try Sign out, then sign in again.`;
  }
    return `${core}\n\nIf a database column is missing, run migrations 014, 019, 020, 022, 026, and 027 in supabase/migrations/ once in the Supabase SQL Editor.`;
}

function emptyPageDraft(): Partial<SitePage> & {
  slug: string;
  title: string;
  sections: PageSection[];
} {
  return {
    slug: '',
    title: '',
    body: '',
    sections: [],
    show_in_nav: true,
    sort_order: 0,
    visual_preset: '',
    immersive_layout: false,
    custom_mood_css: '',
    page_mode: 'blocks',
    raw_html: '',
    unlisted: false,
    published: true,
    comments_enabled: true,
    show_on_apps_hub: true,
    html_app_summary: '',
    html_iframe_compat: false,
    route_fx: defaultRouteFxOverride(),
  };
}

function sitePageToDraft(p: SitePage): Partial<SitePage> & {
  slug: string;
  title: string;
  sections: PageSection[];
} {
  return {
    ...emptyPageDraft(),
    slug: p.slug,
    title: p.title,
    body: p.body ?? '',
    sections: ensureSectionIds(p.sections ?? []),
    show_in_nav: p.show_in_nav ?? true,
    sort_order: Number(p.sort_order ?? 0),
    visual_preset: p.visual_preset ?? '',
    immersive_layout: Boolean(p.immersive_layout),
    custom_mood_css: String(p.custom_mood_css ?? ''),
    page_mode: p.page_mode === 'html_app' ? 'html_app' : 'blocks',
    raw_html: String(p.raw_html ?? ''),
    unlisted: Boolean(p.unlisted),
    published: p.published !== false,
    comments_enabled: p.comments_enabled === false ? false : true,
    show_on_apps_hub: p.show_on_apps_hub !== false,
    html_app_summary: String(p.html_app_summary ?? ''),
    html_iframe_compat: Boolean(p.html_iframe_compat),
    route_fx: normalizeRouteFxOverride(p.route_fx),
  };
}

const emptyGame = (): Partial<GameRecord> & { slug: string; title: string } => ({
  slug: '',
  title: '',
  type: 'game',
  description: '',
  details: '',
  thumbnail_url: '',
  tab_icon_url: '',
  preview_video_url: '',
  external_url: '',
  local_folder: '',
  storage_slug: null,
  storage_entry_in_zip: null,
  sections: [],
  visual_preset: '',
  pricing_model: 'free',
  price_cents: 0,
  gumroad_url: '',
  purchase_url: '',
  stripe_price_id: '',
  pwyw_min_cents: null,
  pwyw_suggested_cents: null,
  donation_presets_cents: [],
    sort_order: 0,
    published: true,
    in_vault: false,
    immersive_layout: false,
    custom_mood_css: '',
    route_fx: defaultRouteFxOverride(),
    // Migration 018 — game-page enrichment.
    tags: [],
    release_date: '',
    platforms: [],
    screenshots: [],
    features: [],
    controls: [],
    credits: [],
    changelog: [],
    system_requirements: [],
});

const newSupportButton = (): SupportButton => ({
  id: crypto.randomUUID(),
  label: '',
  href: '',
  external: false,
  variant: 'secondary',
});

function newPromoEvent(): SiteEvent {
  return {
    id: crypto.randomUUID(),
    title: '',
    body: '',
    href: '',
    external: false,
    starts_at: null,
    ends_at: null,
    active: true,
  };
}

function copyPublicHashUrl(route: string) {
  try {
    const u = new URL(window.location.href);
    const path = route.startsWith('/') ? route : `/${route}`;
    u.hash = `#${path}`;
    void navigator.clipboard?.writeText(u.href);
    return true;
  } catch {
    return false;
  }
}

/** URL segment from display title when slug is left blank (lowercase, hyphens). */
function slugifyFromTitle(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/['"]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

function effectiveGameSlug(draft: { slug: string; title: string }): string {
  const manual = draft.slug.trim();
  if (manual) {
    return manual;
  }
  return slugifyFromTitle(draft.title);
}

function gameUpsertPayload(draft: Partial<GameRecord> & { slug: string; title: string }) {
  return {
    slug: draft.slug.trim(),
    title: draft.title.trim(),
    type: draft.type ?? 'game',
    description: draft.description ?? '',
    details: draft.details ?? '',
    thumbnail_url: draft.thumbnail_url ?? '',
    tab_icon_url: draft.tab_icon_url?.trim() || null,
    preview_video_url: draft.preview_video_url ?? '',
    external_url: draft.external_url ?? '',
    local_folder: draft.local_folder?.trim() || draft.slug.trim(),
    storage_slug: draft.storage_slug ?? null,
    storage_entry_in_zip: draft.storage_entry_in_zip?.trim() || null,
    sections: ensureSectionIds(draft.sections ?? []),
    visual_preset: normalizeVisualPresetInput(draft.visual_preset) || null,
    price_cents: Number(draft.price_cents ?? 0),
    gumroad_url: draft.gumroad_url?.trim() || null,
    purchase_url: draft.purchase_url?.trim() || null,
    stripe_price_id: draft.stripe_price_id?.trim() || null,
    pricing_model: draft.pricing_model ?? 'free',
    pwyw_min_cents: draft.pwyw_min_cents ?? null,
    pwyw_suggested_cents: draft.pwyw_suggested_cents ?? null,
    donation_presets_cents: donationPresetsFromUnknown(draft.donation_presets_cents),
    sort_order: Number(draft.sort_order ?? 0),
    published: draft.published ?? true,
    in_vault: draft.in_vault ?? false,
    immersive_layout: draft.immersive_layout ?? false,
    custom_mood_css: String(draft.custom_mood_css ?? ''),
    route_fx: draft.route_fx ?? defaultRouteFxOverride(),
    // Migration 018 — game-page enrichment columns. All optional / additive.
    tags: Array.isArray(draft.tags) ? draft.tags : [],
    release_date: String(draft.release_date ?? ''),
    platforms: Array.isArray(draft.platforms) ? draft.platforms : [],
    screenshots: Array.isArray(draft.screenshots) ? draft.screenshots : [],
    features: Array.isArray(draft.features) ? draft.features : [],
    controls: Array.isArray(draft.controls) ? draft.controls : [],
    credits: Array.isArray(draft.credits) ? draft.credits : [],
    changelog: Array.isArray(draft.changelog) ? draft.changelog : [],
    system_requirements: Array.isArray(draft.system_requirements) ? draft.system_requirements : [],
  };
}

function summarizeGameSave(p: ReturnType<typeof gameUpsertPayload>): string {
  const mood = p.visual_preset ? `Mood: ${p.visual_preset}` : 'Mood: hub default';
  const n = Array.isArray(p.sections) ? p.sections.length : 0;
  const blocks = n ? `${n} detail block(s)` : 'No detail blocks';
  const gum = String(p.gumroad_url ?? '').trim();
  const commerce =
    gum
      ? `Gumroad: ${gum.slice(0, 48)}${gum.length > 48 ? '…' : ''}`
      : p.pricing_model && p.pricing_model !== 'free'
        ? `Commerce: ${p.pricing_model} (${p.price_cents ?? 0}¢)`
        : 'Commerce: free (no Gumroad)';
  const host = p.storage_slug ? 'Hosted: ZIP on Storage' : p.external_url?.trim() ? 'Play: external URL' : 'Play: local / repo path';
  const vis = p.published === false ? 'Hidden from main hub' : 'On main hub';
  const vault = p.in_vault ? 'Listed in Vault (/vault)' : 'Not in Vault';
  const imm = p.immersive_layout ? 'Immersive layout' : 'Standard layout';
  const css = String(p.custom_mood_css ?? '').trim() ? 'Custom CSS attached' : 'No per-game CSS';
  return `Saved “${p.title}” (${p.slug}) · ${blocks} · ${commerce} · ${mood} · ${host} · ${vis} · ${vault} · ${imm} · ${css}.`;
}

function htmlPasteStats(raw: string | undefined): { chars: number; lines: number } {
  const text = raw ?? '';
  if (!text) {
    return { chars: 0, lines: 0 };
  }
  return { chars: text.length, lines: text.split(/\r\n|\r|\n/).length };
}

function summarizePageSave(args: {
  slug: string;
  title: string;
  sectionsLen: number;
  hasBody: boolean;
  showInNav: boolean;
  mood: string;
  immersive?: boolean;
  hasCustomCss?: boolean;
  pageMode?: 'blocks' | 'html_app';
  unlisted?: boolean;
  htmlBytes?: number;
}): string {
  const mood = args.mood ? `Mood: ${args.mood}` : 'Mood: hub default';
  const mode = args.pageMode === 'html_app' ? 'HTML app' : 'Blocks page';
  const blocks =
    args.pageMode === 'html_app'
      ? args.htmlBytes
        ? `HTML paste (~${args.htmlBytes} chars)`
        : 'HTML app (empty body)'
      : args.sectionsLen > 0
        ? `${args.sectionsLen} block(s)`
        : args.hasBody
          ? 'Legacy body only'
          : 'Empty body (add blocks or body)';
  const nav = args.showInNav ? 'Shown in top nav' : 'Secret page (URL only — no auto nav link)';
  const idx = args.unlisted ? ' · noindex for crawlers' : '';
  const imm = args.immersive ? 'Immersive layout' : 'Standard layout';
  const css = args.hasCustomCss ? 'Custom CSS' : 'No page CSS';
  return `Saved page “${args.title}” (${args.slug}) · ${mode} · ${blocks} · ${mood} · ${nav}${idx} · ${imm} · ${css}.`;
}

const adminJumpBtnStyle: CSSProperties = {
  background: 'none',
  border: 'none',
  color: 'var(--accent)',
  cursor: 'pointer',
  padding: 0,
  textDecoration: 'underline',
  font: 'inherit',
};

const STUDIO_PREVIEW_TABS: Tab[] = [
  'settings',
  'theme',
  'effects',
  'typography',
  'layout',
  'components',
  'behavior',
  'seo',
  'brand',
  'social',
  'motion',
  'media',
  'system',
];

export function AdminPage() {
  const auth = useAuth();
  const { refresh: refreshSiteSettings } = useSiteSettings();
  const [tab, setTab] = useState<Tab>('overview');
  const [analyticsDaysBack, setAnalyticsDaysBack] = useState(30);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [settingsSaveStatus, setSettingsSaveStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [settingsSaveDetail, setSettingsSaveDetail] = useState<string | null>(null);
  const [settingsFieldErrors, setSettingsFieldErrors] = useState<Record<string, string>>({});
  const settingsSaveSuccessTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const gameSaveSuccessTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pageSaveSuccessTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const navSaveSuccessTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const logSaveSuccessTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const [gameFieldErrors, setGameFieldErrors] = useState<Record<string, string>>({});
  const [gameSaveStatus, setGameSaveStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [gameSaveDetail, setGameSaveDetail] = useState<string | null>(null);
  const [gameSaveSummary, setGameSaveSummary] = useState<string | null>(null);
  const [pageSaveStatus, setPageSaveStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [pageSaveDetail, setPageSaveDetail] = useState<string | null>(null);
  const [pageSaveSummary, setPageSaveSummary] = useState<string | null>(null);
  const [navSaveStatus, setNavSaveStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [navSaveDetail, setNavSaveDetail] = useState<string | null>(null);
  const [logSaveStatus, setLogSaveStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [logSaveDetail, setLogSaveDetail] = useState<string | null>(null);
  const [pageFieldErrors, setPageFieldErrors] = useState<Record<string, string>>({});

  const [settings, setSettings] = useState<SiteSettings>(defaultSiteSettings);
  const [savedSettingsSnapshot, setSavedSettingsSnapshot] = useState<string>(() =>
    JSON.stringify(defaultSiteSettings),
  );
  const [games, setGames] = useState<GameRecord[]>([]);
  const [pages, setPages] = useState<SitePage[]>([]);
  const [nav, setNav] = useState<NavItem[]>([]);
  const [logs, setLogs] = useState<DevLogPost[]>([]);
  const [servicesCount, setServicesCount] = useState(0);

  const [gameDraft, setGameDraft] = useState(emptyGame());
  const [pageDraft, setPageDraft] = useState(emptyPageDraft());
  const [googleError, setGoogleError] = useState<string | null>(null);
  const [syncRepoMessage, setSyncRepoMessage] = useState<string | null>(null);
  const [gameZipFile, setGameZipFile] = useState<File | null>(null);
  /** Live status line during ZIP upload (parse → delete → parallel file uploads). */
  const [zipUploadHint, setZipUploadHint] = useState<string | null>(null);
  /** Paths to index.html found in the last uploaded ZIP. */
  const [zipEntryCandidates, setZipEntryCandidates] = useState<string[]>([]);
  /** Selected playable entry from uploaded ZIP (persisted to site_games.storage_entry_in_zip). */
  const [zipEntryPick, setZipEntryPick] = useState('');
  const thumbFileRef = useRef<HTMLInputElement>(null);
  const tabIconFileRef = useRef<HTMLInputElement>(null);
  const previewVideoFileRef = useRef<HTMLInputElement>(null);
  const [navDraft, setNavDraft] = useState<Partial<NavItem> & { label: string; href: string }>({
    label: '',
    href: '',
    external: false,
    sort_order: 0,
  });
  const [logDraft, setLogDraft] = useState<
    Partial<DevLogPost> & { slug: string; title: string; body: string }
  >({
    slug: '',
    title: '',
    body: '',
    published_at: new Date().toISOString().slice(0, 16),
    sections: [],
  });

  const settingsLinkHints = useMemo(() => softSiteSettingsLinkHints(settings, pages), [settings, pages]);

  const settingsDirty = useMemo(
    () => JSON.stringify(settings) !== savedSettingsSnapshot,
    [settings, savedSettingsSnapshot],
  );

  const SETTINGS_EDITABLE_TABS = useMemo(
    () =>
      new Set<string>([
        'overview',
        'ai',
        'settings',
        'services',
        'prebuilt',
        'legal',
        'theme',
        'effects',
        'typography',
        'layout',
        'components',
        'behavior',
        'seo',
        'brand',
        'social',
        'motion',
        'media',
        'system',
      ]),
    [],
  );

  const showFloatingSettingsSave = SETTINGS_EDITABLE_TABS.has(tab);

  const onDiscardSettings = useCallback(() => {
    try {
      const parsed = JSON.parse(savedSettingsSnapshot) as SiteSettings;
      setSettings(parsed);
      setSettingsSaveStatus('idle');
      setSettingsSaveDetail(null);
      setSettingsFieldErrors({});
      flash('Reverted unsaved changes.');
    } catch {
      flash('Could not revert — try reloading the page.');
    }
  }, [savedSettingsSnapshot]);

  const gameSlugEffective = useMemo(() => effectiveGameSlug(gameDraft), [gameDraft.slug, gameDraft.title]);

  useEffect(() => {
    try {
      const raw = sessionStorage.getItem(ADMIN_AI_PAGE_DRAFT_KEY);
      if (!raw) return;
      sessionStorage.removeItem(ADMIN_AI_PAGE_DRAFT_KEY);
      const draft = JSON.parse(raw) as Partial<SitePage> & { slug: string; title: string };
      setPageDraft({
        ...emptyPageDraft(),
        ...draft,
        sections: ensureSectionIds(draft.sections ?? []),
      });
      setTab('pages');
      flash('AI loaded a page draft — review and Save page.');
    } catch {
      /* ignore */
    }
  }, []);

  const reload = useCallback(async () => {
    if (!auth.authConfigured || !auth.isAdmin) {
      return;
    }
    const [s, g, svc, p, n, l] = await Promise.all([
      fetchSiteSettings(),
      fetchAllGamesAdmin(),
      fetchAllServicesAdmin(),
      fetchAllPagesAdmin(),
      fetchAllNavAdmin(),
      fetchAllDevLogsAdmin(),
    ]);
    setSettings(s);
    setSavedSettingsSnapshot(JSON.stringify(s));
    setGames(g);
    setServicesCount(svc.length);
    setPages(p);
    setNav(n);
    setLogs(l);
  }, [auth.isAdmin]);

  useEffect(() => {
    reload().catch(console.error);
  }, [reload]);

  useEffect(() => {
    return () => {
      if (settingsSaveSuccessTimerRef.current) {
        clearTimeout(settingsSaveSuccessTimerRef.current);
      }
      if (gameSaveSuccessTimerRef.current) {
        clearTimeout(gameSaveSuccessTimerRef.current);
      }
      if (pageSaveSuccessTimerRef.current) {
        clearTimeout(pageSaveSuccessTimerRef.current);
      }
      if (navSaveSuccessTimerRef.current) {
        clearTimeout(navSaveSuccessTimerRef.current);
      }
      if (logSaveSuccessTimerRef.current) {
        clearTimeout(logSaveSuccessTimerRef.current);
      }
    };
  }, []);

  useEffect(() => {
    if (tab !== 'settings') {
      setSettingsSaveStatus('idle');
      setSettingsSaveDetail(null);
    }
    if (tab !== 'games') {
      setGameSaveStatus('idle');
      setGameSaveDetail(null);
      setGameSaveSummary(null);
    }
    if (tab !== 'pages') {
      setPageSaveStatus('idle');
      setPageSaveDetail(null);
      setPageSaveSummary(null);
    }
    if (tab !== 'nav') {
      setNavSaveStatus('idle');
      setNavSaveDetail(null);
    }
    if (tab !== 'devlogs') {
      setLogSaveStatus('idle');
      setLogSaveDetail(null);
    }
    if (tab !== 'games') {
      setGameFieldErrors({});
    }
    if (tab !== 'pages') {
      setPageFieldErrors({});
    }
  }, [tab]);

  const clearSettingsFieldError = useCallback((key: string) => {
    setSettingsFieldErrors((prev) => {
      if (!(key in prev)) {
        return prev;
      }
      const next = { ...prev };
      delete next[key];
      return next;
    });
  }, []);

  const clearGameFieldError = useCallback((key: string) => {
    setGameFieldErrors((prev) => {
      if (!(key in prev)) {
        return prev;
      }
      const next = { ...prev };
      delete next[key];
      return next;
    });
  }, []);

  const clearPageFieldError = useCallback((key: string) => {
    setPageFieldErrors((prev) => {
      if (!(key in prev)) {
        return prev;
      }
      const next = { ...prev };
      delete next[key];
      return next;
    });
  }, []);

  const flash = (msg: string, durationMs = 3500) => {
    setMessage(msg);
    setTimeout(() => setMessage(null), durationMs);
  };

  const onSaveSettings = async () => {
    setBusy(true);
    setSettingsSaveDetail(null);
    setSettingsFieldErrors({});

    const validationErrors = blockingSiteSettingsIssues(settings);
    if (Object.keys(validationErrors).length) {
      setSettingsFieldErrors(validationErrors);
      setSettingsSaveStatus('error');
      setSettingsSaveDetail('Fix the fields marked with ✗, then save again.');
      flash('Some links look invalid — check the red messages next to each field.');
      setBusy(false);
      return;
    }

    try {
      await saveSiteSettings(settings);
      const fresh = await fetchSiteSettings();
      setSettings(fresh);
      setSavedSettingsSnapshot(JSON.stringify(fresh));
      await refreshSiteSettings();
      setSettingsSaveStatus('success');
      flash('Site settings saved — live site updated.');
      if (settingsSaveSuccessTimerRef.current) {
        clearTimeout(settingsSaveSuccessTimerRef.current);
      }
      settingsSaveSuccessTimerRef.current = setTimeout(() => {
        setSettingsSaveStatus('idle');
        settingsSaveSuccessTimerRef.current = null;
      }, 12000);
    } catch (e) {
      console.error(e);
      setSettingsSaveStatus('error');
      setSettingsSaveDetail(describeAdminWriteFailure(e));
      const msg = formatSupabaseWriteError(e);
      const col = unknownColumnFromPostgrestMessage(msg);
      if (col) {
        setSettingsFieldErrors({
          _migration: `Missing column "${col}". Run supabase/migrations/014_ensure_admin_write_schema.sql in the Supabase SQL Editor.`,
        });
      }
      flash(formatSupabaseWriteError(e));
    } finally {
      setBusy(false);
    }
  };

  const onSaveGame = async () => {
    setGameFieldErrors({});
    setGameSaveDetail(null);
    setGameSaveSummary(null);

    const title = gameDraft.title.trim();
    if (!title) {
      setGameSaveStatus('error');
      setGameFieldErrors({ title: '✗ Title is required.' });
      setGameSaveDetail('✗ Title is required.');
      flash('Enter a game title.');
      return;
    }

    let slug = gameDraft.slug.trim();
    if (!slug) {
      slug = slugifyFromTitle(title);
    }
    if (!slug) {
      setGameSaveStatus('error');
      setGameFieldErrors({ title: '✗ Use a title with letters or numbers so we can build a URL slug.' });
      setGameSaveDetail('✗ Could not create a URL id from this title — add a slug manually.');
      flash('Title needs readable characters for the URL.');
      return;
    }

    const storageOk = Boolean(gameDraft.storage_slug?.trim());
    const extOk = Boolean(gameDraft.external_url?.trim());
    const isExisting = games.some((g) => g.slug === slug);
    if (!isExisting && !storageOk && !extOk) {
      setGameSaveStatus('error');
      setGameFieldErrors({
        play: '✗ Upload the Web export ZIP (below) or set External play URL — new games need a playable build.',
      });
      setGameSaveDetail(
        '✗ New games need a ZIP on Storage or an external play URL. Upload a ZIP first, or paste an itch.io / host URL.',
      );
      flash('Add a ZIP or external play URL before saving a new game.');
      return;
    }

    setBusy(true);
    const payload = gameUpsertPayload({ ...gameDraft, slug, title });
    try {
      await upsertGame(payload);
      setGameDraft(emptyGame());
      setZipEntryPick('');
      setZipEntryCandidates([]);
      setGameZipFile(null);
      await reload();
      setGameSaveStatus('success');
      setGameSaveSummary(summarizeGameSave(payload));
      flash('Game saved.');
      if (gameSaveSuccessTimerRef.current) {
        clearTimeout(gameSaveSuccessTimerRef.current);
      }
      gameSaveSuccessTimerRef.current = setTimeout(() => {
        setGameSaveStatus('idle');
        gameSaveSuccessTimerRef.current = null;
      }, 14000);
    } catch (e) {
      console.error(e);
      const detail = describeAdminWriteFailure(e);
      setGameSaveStatus('error');
      setGameSaveDetail(detail);
      flash(formatSupabaseWriteError(e));
    } finally {
      setBusy(false);
    }
  };

  const onUploadGameZip = async () => {
    const title = gameDraft.title.trim();
    if (!title) {
      flash('Enter a game title first (we derive the storage folder from title or slug).');
      return;
    }
    const slugRaw = gameDraft.slug.trim() || slugifyFromTitle(title);
    if (!slugRaw) {
      flash('Title must include letters or numbers for the game URL / storage folder.');
      return;
    }
    if (!gameZipFile) {
      flash('Choose a .zip file (Godot Web export folder).');
      return;
    }
    const storageKey = sanitizeGameStorageSlug(slugRaw);
    if (!storageKey) {
      flash('Slug must include letters or numbers for cloud hosting.');
      return;
    }
    const titleSaved = title;
    setBusy(true);
    setZipUploadHint('Reading ZIP…');
    try {
      const { fileCount, exportRootLabel, indexCandidates, detectedEntry } = await uploadGameZip(
        slugRaw,
        gameZipFile,
        true,
        (p) => {
          if (p.phase === 'parse') {
            setZipUploadHint('Reading ZIP…');
          } else if (p.phase === 'packaged') {
            const sizeLabel =
              p.totalBytes >= 1024 * 1024 * 1024
                ? `${(p.totalBytes / (1024 * 1024 * 1024)).toFixed(1)} GB`
                : `${Math.max(1, Math.round(p.totalBytes / (1024 * 1024)))} MB`;
            setZipUploadHint(
              `${p.fileCount} files (${sizeLabel}) from "${p.exportRootLabel}" — uploading (${p.uploadConcurrency} at a time, large files first)…`,
            );
          } else if (p.phase === 'clearing') {
            setZipUploadHint('Removing previous build from server…');
          } else {
            const tail = p.currentPath ? ` — ${p.currentPath.split('/').pop()}` : '';
            setZipUploadHint(`Uploading ${p.done}/${p.total} files…${tail}`);
          }
        },
      );
      const normalizeEntryPath = (path: string) =>
        path
          .split('/')
          .map((seg, i, arr) =>
            i === arr.length - 1 && seg.toLowerCase() === 'index.html' ? 'index.html' : seg,
          )
          .join('/');
      const normalizedCandidates = indexCandidates.map(normalizeEntryPath);
      const detectedNorm = normalizeEntryPath(detectedEntry);
      const chosenEntry = normalizedCandidates.includes(detectedNorm)
        ? detectedNorm
        : (normalizedCandidates[0] ?? 'index.html');
      setGameZipFile(null);
      setZipEntryCandidates(normalizedCandidates);
      setZipEntryPick(chosenEntry);
      setGameDraft((prev) => ({
        ...prev,
        slug: prev.slug.trim() || slugRaw,
        storage_slug: storageKey,
        storage_entry_in_zip: chosenEntry || null,
        title: prev.title?.trim() ? prev.title : titleSaved,
      }));
      try {
        await upsertGame({
          ...gameUpsertPayload({
            ...gameDraft,
            slug: slugRaw,
            title: titleSaved,
            storage_entry_in_zip: chosenEntry || null,
          }),
          storage_slug: storageKey,
        });
      } catch (dbErr) {
        console.error(dbErr);
        flash(
          `Uploaded ${fileCount} files (from ZIP folder "${exportRootLabel}") to cloud storage, but saving the game row failed: ${
            dbErr instanceof Error ? dbErr.message : 'unknown error'
          }. Files are already on Storage — click **Save game** to retry.`,
          14000,
        );
        await reload();
        return;
      }
      await reload();
      flash(
        `✓ Uploaded ${fileCount} files from "${exportRootLabel}". Play now uses "${chosenEntry}" from this ZIP.`,
        12000,
      );
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'ZIP upload failed', 9000);
    } finally {
      setZipUploadHint(null);
      setBusy(false);
    }
  };

  const onClearHostedGame = async () => {
    const key = gameDraft.storage_slug?.trim();
    if (!key) {
      flash('This draft has no cloud build (storage_slug empty).');
      return;
    }
    if (!confirm('Remove all uploaded files for this game from Supabase Storage?')) {
      return;
    }
    setBusy(true);
    try {
      await deleteGameBuild(key);
      await upsertGame({
        ...gameUpsertPayload(gameDraft),
        storage_slug: null,
        storage_entry_in_zip: null,
      });
      setGameDraft((prev) => ({ ...prev, storage_slug: null, storage_entry_in_zip: null }));
      setZipEntryPick('');
      await reload();
      flash('Cloud build removed.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Could not remove cloud build');
    } finally {
      setBusy(false);
    }
  };

  const onUploadGameThumbnailFile = async (picked?: File) => {
    const file = picked ?? thumbFileRef.current?.files?.[0];
    const slug = gameSlugEffective;
    if (!slug) {
      flash('Enter a title or slug first (URL id).');
      return;
    }
    if (!file) {
      flash('Choose an image file.');
      return;
    }
    const titleForRow = gameDraft.title.trim() || slug;
    setBusy(true);
    try {
      const url = await uploadGameThumbnail(slug, file);
      await upsertGame({
        ...gameUpsertPayload({ ...gameDraft, slug, title: titleForRow }),
        thumbnail_url: url,
      });
      setGameDraft((prev) => ({
        ...prev,
        slug: prev.slug.trim() || slug,
        thumbnail_url: url,
        title: prev.title?.trim() ? prev.title : titleForRow,
      }));
      if (thumbFileRef.current) {
        thumbFileRef.current.value = '';
      }
      await reload();
      flash('Thumbnail uploaded and saved.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Thumbnail upload failed');
    } finally {
      setBusy(false);
    }
  };

  const onUploadGameTabIconFile = async (picked?: File) => {
    const file = picked ?? tabIconFileRef.current?.files?.[0];
    const slug = gameSlugEffective;
    if (!slug) {
      flash('Enter a title or slug first (URL id).');
      return;
    }
    if (!file) {
      flash('Choose a tab icon image.');
      return;
    }
    const titleForRow = gameDraft.title.trim() || slug;
    setBusy(true);
    try {
      const url = await uploadGameTabIcon(slug, file);
      await upsertGame({
        ...gameUpsertPayload({ ...gameDraft, slug, title: titleForRow }),
        tab_icon_url: url,
      });
      setGameDraft((prev) => ({
        ...prev,
        slug: prev.slug.trim() || slug,
        tab_icon_url: url,
        title: prev.title?.trim() ? prev.title : titleForRow,
      }));
      if (tabIconFileRef.current) {
        tabIconFileRef.current.value = '';
      }
      await reload();
      flash('Browser tab icon uploaded and saved.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Tab icon upload failed');
    } finally {
      setBusy(false);
    }
  };

  const onUploadGamePreviewVideoFile = async () => {
    const file = previewVideoFileRef.current?.files?.[0];
    const slug = gameSlugEffective;
    if (!slug) {
      flash('Enter a title or slug first (URL id).');
      return;
    }
    if (!file) {
      flash('Choose a video file.');
      return;
    }
    const titleForRow = gameDraft.title.trim() || slug;
    setBusy(true);
    try {
      const url = await uploadGamePreviewVideo(slug, file);
      await upsertGame({
        ...gameUpsertPayload({ ...gameDraft, slug, title: titleForRow }),
        preview_video_url: url,
      });
      setGameDraft((prev) => ({
        ...prev,
        slug: prev.slug.trim() || slug,
        preview_video_url: url,
        title: prev.title?.trim() ? prev.title : titleForRow,
      }));
      if (previewVideoFileRef.current) {
        previewVideoFileRef.current.value = '';
      }
      await reload();
      flash('Preview video uploaded and saved.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Video upload failed');
    } finally {
      setBusy(false);
    }
  };

  const onSavePage = async () => {
    setPageFieldErrors({});
    setPageSaveDetail(null);
    setPageSaveSummary(null);
    if (!pageDraft.slug.trim()) {
      setPageSaveStatus('error');
      setPageFieldErrors({ slug: '✗ Slug is required — public URL is /#/p/{slug}.' });
      setPageSaveDetail('✗ Slug is required — public URL is /#/p/{slug}.');
      flash('Page slug required.');
      return;
    }
    if (!pageDraft.title.trim()) {
      setPageSaveStatus('error');
      setPageFieldErrors({ title: '✗ Title is required.' });
      setPageSaveDetail('✗ Title is required.');
      flash('Page title required.');
      return;
    }
    const pageMode = pageDraft.page_mode === 'html_app' ? 'html_app' : 'blocks';
    if (pageMode === 'html_app' && !(pageDraft.raw_html ?? '').trim()) {
      setPageSaveStatus('error');
      setPageFieldErrors({ raw_html: '✗ Paste HTML or load a .html file.' });
      setPageSaveDetail('✗ HTML app mode needs non-empty raw HTML.');
      flash('HTML app: paste your exported HTML or use Load .html file.');
      return;
    }
    const moodPage = normalizeVisualPresetInput(pageDraft.visual_preset);
    const slugSaved = pageDraft.slug.trim();
    const titleSaved = pageDraft.title.trim();
    const sections = ensureSectionIds(pageDraft.sections ?? []);
    const bodySaved = pageDraft.body ?? '';
    const showNav = pageDraft.show_in_nav ?? true;
    const moodRaw = moodPage;
    const immersivePage = Boolean(pageDraft.immersive_layout ?? false);
    const customPageCss = String(pageDraft.custom_mood_css ?? '');
    const rawHtmlSaved = String(pageDraft.raw_html ?? '');
    const unlistedPage = Boolean(pageDraft.unlisted);
    const publishedPage = pageDraft.published !== false;
    const commentsEnabled = pageDraft.comments_enabled === true;
    const showOnAppsHub = pageDraft.show_on_apps_hub !== false;
    const htmlSummary = String(pageDraft.html_app_summary ?? '');
    const iframeCompat = Boolean(pageDraft.html_iframe_compat);
    setBusy(true);
    try {
      await upsertPage({
        slug: slugSaved,
        title: titleSaved,
        body: pageMode === 'html_app' ? '' : bodySaved,
        sections: pageMode === 'html_app' ? [] : sections,
        show_in_nav: showNav,
        sort_order: Number(pageDraft.sort_order ?? 0),
        visual_preset: moodRaw || null,
        immersive_layout: immersivePage,
        custom_mood_css: customPageCss,
        page_mode: pageMode,
        raw_html: pageMode === 'html_app' ? rawHtmlSaved : '',
        unlisted: unlistedPage,
        published: publishedPage,
        comments_enabled: commentsEnabled,
        show_on_apps_hub: showOnAppsHub,
        html_app_summary: htmlSummary,
        html_iframe_compat: iframeCompat,
        route_fx: pageDraft.route_fx ?? defaultRouteFxOverride(),
      });
      const verify = await fetchPageBySlug(slugSaved);
      if (!verify) {
        throw new Error(
          'Upsert returned OK but the page could not be read back (check RLS: site_pages row read for anon, or wrong slug).',
        );
      }
      setPageDraft(
        sitePageToDraft({
          ...verify,
          comments_enabled: commentsEnabled,
        }),
      );
      await reload();
      setPageSaveStatus('success');
      setPageSaveSummary(
        summarizePageSave({
          slug: slugSaved,
          title: titleSaved,
          sectionsLen: sections.length,
          hasBody: Boolean(bodySaved.trim()),
          showInNav: showNav,
          mood: moodRaw,
          immersive: immersivePage,
          hasCustomCss: Boolean(customPageCss.trim()),
          pageMode,
          unlisted: unlistedPage,
          htmlBytes: pageMode === 'html_app' ? rawHtmlSaved.length : undefined,
        }),
      );
      flash(`Page saved. Public URL: /p/${slugSaved}`);
      if (pageSaveSuccessTimerRef.current) {
        clearTimeout(pageSaveSuccessTimerRef.current);
      }
      pageSaveSuccessTimerRef.current = setTimeout(() => {
        setPageSaveStatus('idle');
        pageSaveSuccessTimerRef.current = null;
      }, 14000);
    } catch (e) {
      console.error(e);
      setPageSaveStatus('error');
      setPageSaveDetail(describeAdminWriteFailure(e));
      flash(formatSupabaseWriteError(e));
    } finally {
      setBusy(false);
    }
  };

  const onSaveNav = async () => {
    setNavSaveDetail(null);
    if (!navDraft.label.trim()) {
      setNavSaveStatus('error');
      setNavSaveDetail('✗ Label is required (button text in the top bar).');
      flash('Nav label required.');
      return;
    }
    if (!navDraft.href.trim()) {
      setNavSaveStatus('error');
      setNavSaveDetail('✗ Href is required (path like /vault or full https:// URL).');
      flash('Nav href required.');
      return;
    }
    setBusy(true);
    try {
      await upsertNav({
        id: navDraft.id ?? crypto.randomUUID(),
        label: navDraft.label.trim(),
        href: navDraft.href.trim(),
        external: navDraft.external ?? false,
        sort_order: Number(navDraft.sort_order ?? 0),
      });
      setNavDraft({ label: '', href: '', external: false, sort_order: 0 });
      await reload();
      setNavSaveStatus('success');
      setNavSaveDetail(
        '✓ Saved. This adds a button to the top navigation bar (next to Home, Vault, Dev log, and any CMS pages you marked “show in nav”). Use sort order to arrange extras.',
      );
      flash('Navigation link saved.');
      if (navSaveSuccessTimerRef.current) {
        clearTimeout(navSaveSuccessTimerRef.current);
      }
      navSaveSuccessTimerRef.current = setTimeout(() => {
        setNavSaveStatus('idle');
        navSaveSuccessTimerRef.current = null;
      }, 12000);
    } catch (e) {
      console.error(e);
      setNavSaveStatus('error');
      setNavSaveDetail(describeAdminWriteFailure(e));
      flash(formatSupabaseWriteError(e));
    } finally {
      setBusy(false);
    }
  };

  const onSaveLog = async () => {
    setLogSaveDetail(null);
    if (!logDraft.slug.trim()) {
      setLogSaveStatus('error');
      setLogSaveDetail('✗ Dev log slug is required (URL segment).');
      flash('Log slug required.');
      return;
    }
    if (!logDraft.title.trim()) {
      setLogSaveStatus('error');
      setLogSaveDetail('✗ Title is required.');
      flash('Log title required.');
      return;
    }
    const savedLogSlug = logDraft.slug.trim();
    const savedLogTitle = logDraft.title.trim();
    setBusy(true);
    try {
      const iso = logDraft.published_at
        ? new Date(logDraft.published_at).toISOString()
        : new Date().toISOString();
      await upsertDevLog({
        slug: savedLogSlug,
        title: savedLogTitle,
        body: logDraft.body ?? '',
        published_at: iso,
        sections: logDraft.sections ?? [],
      });
      setLogDraft({
        slug: '',
        title: '',
        body: '',
        published_at: new Date().toISOString().slice(0, 16),
        sections: [],
      });
      await reload();
      setLogSaveStatus('success');
      setLogSaveDetail(`✓ Saved dev log “${savedLogTitle}” — public path /#/devlog/${savedLogSlug}.`);
      flash('Dev log saved.');
      if (logSaveSuccessTimerRef.current) {
        clearTimeout(logSaveSuccessTimerRef.current);
      }
      logSaveSuccessTimerRef.current = setTimeout(() => {
        setLogSaveStatus('idle');
        logSaveSuccessTimerRef.current = null;
      }, 12000);
    } catch (e) {
      console.error(e);
      setLogSaveStatus('error');
      setLogSaveDetail(describeAdminWriteFailure(e));
      flash(formatSupabaseWriteError(e));
    } finally {
      setBusy(false);
    }
  };

  if (!auth.authConfigured) {
    return (
      <div className="admin-shell">
        <div className="admin-panel">
          <h1 className="header-title" style={{ fontSize: '1.8rem' }}>
            Admin
          </h1>
          <p className="admin-muted" style={{ marginTop: 12, lineHeight: 1.6 }}>
            Firebase is not connected yet. Open <code>cms/firebase-config.json</code> in this repo and paste your four
            values from the Firebase web app config (<code>apiKey</code>, <code>authDomain</code>,{' '}
            <code>projectId</code>, <code>appId</code>). Commit, push, wait for deploy — see{' '}
            <code>docs/FIREBASE_SETUP.md</code>.
          </p>
          {auth.authInitError ? (
            <p className="admin-muted danger-zone" style={{ marginTop: 12 }}>
              {auth.authInitError}
            </p>
          ) : null}
          <p style={{ marginTop: 16 }}>
            <Link to="/">← Back to site</Link>
          </p>
        </div>
      </div>
    );
  }

  if (auth.loading) {
    return (
      <div className="admin-shell">
        <div className="empty-state">Checking session…</div>
      </div>
    );
  }

  if (!auth.user) {
    return (
      <div className="admin-shell">
        <div className="admin-panel">
          <h1 className="header-title" style={{ fontSize: '1.8rem' }}>
            Log in to edit the site
          </h1>
          <p className="admin-muted" style={{ marginBottom: 16, lineHeight: 1.5 }}>
            Sign in with Google using an email on the admin allow list. Edit{' '}
            <code>cms/admin-config.json</code> to add your email or domain. Full guide:{' '}
            <code>docs/NO_SUPABASE_SETUP.md</code>.
          </p>
          <p className="admin-muted" style={{ marginBottom: 12, fontSize: '0.85rem' }}>
            Bookmark <strong>/admin</strong>. Optional: show “Team login” in the header with{' '}
            <code>VITE_SHOW_ADMIN_NAV=true</code>.
          </p>
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              setGoogleError(null);
              auth
                .signInWithGoogle('/admin')
                .catch((e) => {
                  console.error(e);
                  setGoogleError(e instanceof Error ? e.message : 'Google sign-in failed');
                });
            }}
          >
            Continue with Google
          </button>
          {googleError ? (
            <p className="admin-muted danger-zone" style={{ marginTop: 12, padding: 12, borderRadius: 8 }}>
              {googleError}
            </p>
          ) : null}
          <p style={{ marginTop: 20 }}>
            <Link to="/">← Back to site</Link>
          </p>
        </div>
      </div>
    );
  }

  if (!auth.isAdmin) {
    if (auth.adminCheckError) {
      return (
        <div className="admin-shell">
          <div className="admin-panel danger-zone">
            <h1 className="header-title" style={{ fontSize: '1.8rem' }}>
              Can’t verify editor access
            </h1>
            <p className="admin-muted" style={{ marginTop: 12 }}>
              Signed in as <strong>{auth.user.email}</strong>, but the database check failed. This is usually{' '}
              <strong>not</strong> your password — it means Supabase couldn’t run <code>is_site_admin</code>.
            </p>
            <p className="admin-muted" style={{ marginTop: 12 }}>
              <strong>Fix:</strong> Supabase → <strong>SQL Editor</strong> → run the full{' '}
              <code>supabase/schema.sql</code> from this repo (one paste, Run). Then sign out and sign in again.
            </p>
            <p className="admin-muted" style={{ marginTop: 12, fontSize: '0.85rem' }}>
              Technical detail: {auth.adminCheckError}
            </p>
            <button type="button" style={{ marginTop: 16 }} onClick={() => auth.signOut()}>
              Sign out
            </button>
            <p style={{ marginTop: 20 }}>
              <Link to="/">← Back to site</Link>
            </p>
          </div>
        </div>
      );
    }
    return (
      <div className="admin-shell">
        <div className="admin-panel danger-zone">
          <h1 className="header-title" style={{ fontSize: '1.8rem' }}>
            Access denied
          </h1>
          <p className="admin-muted" style={{ marginTop: 12 }}>
            Signed in as <strong>{auth.user.email}</strong>. This address is not on the editor allow list.
          </p>
          <p className="admin-muted" style={{ marginTop: 12 }}>
            <strong>Fix:</strong> Edit <code>cms/admin-config.json</code> in the repo and add your email to{' '}
            <code>admin_emails</code>, or your domain to <code>admin_domains</code>. Then redeploy. See{' '}
            <code>docs/NO_SUPABASE_SETUP.md</code>.
          </p>
          <button type="button" style={{ marginTop: 16 }} onClick={() => auth.signOut()}>
            Sign out
          </button>
          <p style={{ marginTop: 20 }}>
            <Link to="/">← Back to site</Link>
          </p>
        </div>
      </div>
    );
  }

  /** Cloud ZIP is saved on Storage and no replacement file is queued — show confirmation without refresh. */
  const zipCloudConfirmed =
    Boolean(gameDraft.storage_slug?.trim()) && gameZipFile === null;

  return (
    <div className="admin-shell" style={{ paddingBottom: showFloatingSettingsSave ? 120 : 24 }}>
      <div className="admin-row" style={{ justifyContent: 'space-between', marginBottom: 16 }}>
        <h1 className="header-title" style={{ fontSize: '1.6rem' }}>
          Site admin
        </h1>
        <div className="admin-row">
          <span className="admin-muted" style={{ fontSize: '0.8rem' }}>
            {auth.user.email}
          </span>
          <button type="button" onClick={() => auth.signOut()}>
            Sign out
          </button>
          <Link to="/">View site</Link>
        </div>
      </div>

      {message && (
        <div className="admin-panel" style={{ marginBottom: 12 }}>
          <p className="admin-muted">{message}</p>
        </div>
      )}

      <div className="admin-tabs">
        {/* Original CMS tabs */}
        {ADMIN_CMS_TABS.map(({ id, label }) => (
          <button key={id} type="button" className={tab === id ? 'active' : ''} onClick={() => setTab(id as Tab)}>
            {label}
          </button>
        ))}
        <span aria-hidden style={{ width: 1, alignSelf: 'stretch', background: 'var(--border)', margin: '0 4px' }} />
        {ADMIN_STUDIO_TABS.map(({ id, label }) => (
          <button
            key={id}
            type="button"
            className={tab === id ? 'active' : ''}
            onClick={() => setTab(id as Tab)}
            style={{ borderColor: 'rgba(166, 115, 255, 0.5)' }}
          >
            {label}
          </button>
        ))}
      </div>

      <AdminStudioPreview settings={settings} active={STUDIO_PREVIEW_TABS.includes(tab)} />

      {tab === 'overview' && (
        <>
        <div className="admin-panel" style={{ marginBottom: 20, borderColor: 'rgba(115, 248, 255, 0.35)' }}>
          <h2 style={{ fontSize: '1rem', margin: '0 0 8px', color: 'var(--accent)' }}>🏠 Homepage builder</h2>
          <p className="admin-muted" style={{ marginTop: 0, lineHeight: 1.55, fontSize: '0.88rem' }}>
            Edit homepage blocks here (same as the old Homepage tab). Hero title/logo: <strong>Brand + Hero</strong>.
            Hub mood colours: <strong>Effects → Site mood</strong>. Support/footer: <strong>Site copy</strong>.
          </p>
          <HomepageStudio settings={settings} setSettings={setSettings} />
          <div className="admin-row" style={{ marginTop: 16, gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
            <button type="button" disabled={busy || !settingsDirty} onClick={onSaveSettings}>
              {busy ? 'Saving…' : settingsDirty ? 'Save homepage & studio settings' : 'Saved'}
            </button>
            {settingsSaveStatus === 'success' && !settingsDirty ? (
              <span style={{ color: '#3ecf8e' }} aria-label="Saved">
                ✓ Saved
              </span>
            ) : null}
            {settingsDirty ? (
              <span className="admin-muted" style={{ fontSize: '0.78rem', color: '#ffbf5f' }}>
                You have unsaved changes — floating Save bar at the bottom works on every tab.
              </span>
            ) : null}
          </div>
        </div>
        <div
          className="admin-grid"
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
            gap: 16,
          }}
        >
          {ADMIN_OVERVIEW_CARDS.map(({ id, title, desc }) => (
            <button
              key={id}
              type="button"
              className="admin-panel"
              style={{ textAlign: 'left', cursor: 'pointer' }}
              onClick={() => setTab(id as Tab)}
            >
              <h2 style={{ fontSize: '1rem', margin: '0 0 8px', color: 'var(--accent)' }}>{title}</h2>
              <p className="admin-muted" style={{ margin: 0, fontSize: '0.85rem' }}>
                {desc}
              </p>
            </button>
          ))}
        </div>
        <div className="admin-panel" style={{ marginTop: 20, borderColor: 'rgba(255, 191, 95, 0.35)' }}>
          <h2 style={{ fontSize: '1rem', margin: '0 0 8px', color: 'var(--accent)' }}>💰 Monetization (no new API keys)</h2>
          <p className="admin-muted" style={{ marginTop: 0, lineHeight: 1.55, fontSize: '0.88rem' }}>
            <strong>Services tab:</strong> tips, demos, website/app/game gigs, merch — Stripe + email requests at{' '}
            <code>/#/services</code>. <strong>Games tab:</strong> sell playable builds. <strong>Site copy:</strong>{' '}
            donation link. Stripe uses one Edge Function (<code>create-checkout-session</code>) — set secrets when ready.
          </p>
          <div className="admin-row" style={{ gap: 8, flexWrap: 'wrap' }}>
            <button type="button" onClick={() => setTab('services')}>
              Open Services →
            </button>
            <button type="button" onClick={() => setTab('games')}>
              Open Games →
            </button>
          </div>
        </div>
        <div className="admin-panel" style={{ marginTop: 20, borderColor: 'rgba(115, 248, 255, 0.25)' }}>
          <h2 style={{ fontSize: '1rem', margin: '0 0 8px', color: 'var(--accent)' }}>
            Push CMS snapshots to GitHub
          </h2>
          <p className="admin-muted" style={{ marginTop: 0, lineHeight: 1.55 }}>
            Saves live in <strong>Supabase</strong>. Use these buttons to write snapshots into GitHub so deploys can ship
            content/layout changes with the build. ZIP game files still stay in Storage and are never committed. Setup:{' '}
            <code>docs/SYNC_CMS_TO_GITHUB.md</code>.
          </p>
          <div className="admin-row" style={{ marginTop: 12, flexWrap: 'wrap', gap: 8 }}>
            <button
              type="button"
              disabled={busy}
              onClick={() => {
                setBusy(true);
                setSyncRepoMessage(null);
                invokeSyncGamesJsonToGitHub()
                  .then((r) => {
                    if (r.error) {
                      setSyncRepoMessage(r.error);
                    } else {
                      setSyncRepoMessage(
                        `Synced games.json (${r.games ?? 0} published game(s)).${r.commit_url ? ` ${r.commit_url}` : ''}`,
                      );
                    }
                  })
                  .catch((e) => setSyncRepoMessage(e instanceof Error ? e.message : 'Sync failed'))
                  .finally(() => setBusy(false));
              }}
            >
              Push games.json
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => {
                setBusy(true);
                setSyncRepoMessage(null);
                invokeSyncSiteContentToGitHub()
                  .then((r) => {
                    if (r.error) {
                      setSyncRepoMessage(r.error);
                    } else {
                      setSyncRepoMessage(
                        `Synced site content snapshot (${r.files?.length ?? 0} files in /cms).${
                          r.commit_url ? ` ${r.commit_url}` : ''
                        }`,
                      );
                    }
                  })
                  .catch((e) => setSyncRepoMessage(e instanceof Error ? e.message : 'Sync failed'))
                  .finally(() => setBusy(false));
              }}
            >
              Push pages/layout snapshot
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => {
                setBusy(true);
                setSyncRepoMessage(null);
                invokeSyncAllCmsToGitHub()
                  .then((r) => {
                    if (r.error) {
                      setSyncRepoMessage(r.error);
                    } else {
                      setSyncRepoMessage(
                        `Synced full CMS snapshot (${r.files?.length ?? 0} files).${
                          r.commit_url ? ` ${r.commit_url}` : ''
                        }`,
                      );
                    }
                  })
                  .catch((e) => setSyncRepoMessage(e instanceof Error ? e.message : 'Sync failed'))
                  .finally(() => setBusy(false));
              }}
            >
              Push everything (games + pages + settings)
            </button>
          </div>
          {syncRepoMessage ? (
            <p className="admin-muted" style={{ marginTop: 12, whiteSpace: 'pre-wrap' }}>
              {syncRepoMessage}
            </p>
          ) : null}
        </div>
        </>
      )}

      {tab === 'ai' && (
        <AdminAiAssistant
          currentTab={tab}
          settings={settings}
          gamesCount={games.length}
          pagesCount={pages.length}
          servicesCount={servicesCount}
          setTab={(t) => setTab(t as Tab)}
          setSettings={setSettings}
          flash={flash}
        />
      )}

      {tab === 'services' && <ServicesAdminTab settings={settings} setSettings={setSettings} />}

      {tab === 'prebuilt' && (
        <PrebuiltPagesStudio settings={settings} setSettings={setSettings} onNotify={flash} />
      )}

      {tab === 'legal' && <LegalStudio settings={settings} setSettings={setSettings} />}

      {tab === 'settings' && (
        <div className="admin-panel admin-grid">
          {settingsFieldErrors._migration ? (
            <div
              role="alert"
              style={{
                gridColumn: '1 / -1',
                padding: '12px 14px',
                borderRadius: 8,
                border: '1px solid var(--danger)',
                background: 'rgba(255, 95, 191, 0.12)',
                color: 'var(--text)',
                fontSize: '0.88rem',
                lineHeight: 1.5,
              }}
            >
              <span style={{ color: 'var(--danger)', marginRight: 8 }} aria-hidden>
                ✗
              </span>
              {settingsFieldErrors._migration}
            </div>
          ) : null}
          <p className="admin-muted" style={{ gridColumn: '1 / -1', lineHeight: 1.55, fontSize: '0.88rem' }}>
            Hero title, logo, and tagline:{' '}
            <button type="button" style={adminJumpBtnStyle} onClick={() => setTab('brand')}>
              Brand + Hero
            </button>
            . Homepage blocks:{' '}
            <button type="button" style={adminJumpBtnStyle} onClick={() => setTab('overview')}>
              Overview → Homepage builder
            </button>
            . Site mood preset:{' '}
            <button type="button" style={adminJumpBtnStyle} onClick={() => setTab('effects')}>
              Effects
            </button>
            .
          </p>
          <div className="admin-field">
            <label htmlFor="support_title">Support section title</label>
            <input
              id="support_title"
              value={settings.support_title}
              onChange={(e) => setSettings({ ...settings, support_title: e.target.value })}
            />
          </div>
          <div className="admin-field">
            <label htmlFor="support_body">Support body</label>
            <textarea
              id="support_body"
              value={settings.support_body}
              onChange={(e) => setSettings({ ...settings, support_body: e.target.value })}
            />
          </div>
          <div className="admin-field">
            <label htmlFor="support_page_href">Support / contact page path</label>
            <input
              id="support_page_href"
              placeholder="/p/support"
              value={settings.support_page_href}
              onChange={(e) => {
                clearSettingsFieldError('support_page_href');
                setSettings({ ...settings, support_page_href: e.target.value });
              }}
            />
            {settingsFieldErrors.support_page_href ? (
              <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
                <span aria-hidden>✗ </span>
                {settingsFieldErrors.support_page_href}
              </p>
            ) : settingsLinkHints.support_page_href ? (
              <p style={{ color: '#c9a227', fontSize: '0.82rem', marginTop: 8 }}>
                <span aria-hidden>⚠ </span>
                {settingsLinkHints.support_page_href}
              </p>
            ) : null}
            <p className="admin-muted" style={{ marginTop: 8, fontSize: '0.82rem' }}>
              Used by the default Contact button at the bottom of the homepage (overrides that button&apos;s href when
              this field is non-empty).
            </p>
            <HrefQuickPick
              pages={pages.map((p) => ({ slug: p.slug, title: p.title }))}
              games={games.map((g) => ({ slug: g.slug, title: g.title }))}
              disabled={busy}
              onPick={(href) => {
                clearSettingsFieldError('support_page_href');
                setSettings({ ...settings, support_page_href: href });
              }}
            />
          </div>
          <div className="admin-field">
            <label htmlFor="stripe_donation_url">Stripe donation URL (optional)</label>
            <input
              id="stripe_donation_url"
              placeholder="https://buy.stripe.com/..."
              value={settings.stripe_donation_url}
              onChange={(e) => {
                setSettingsFieldErrors((prev) => {
                  const next = { ...prev };
                  Object.keys(next).forEach((k) => {
                    if (k.startsWith('support_btn_')) {
                      delete next[k];
                    }
                  });
                  return next;
                });
                setSettings({ ...settings, stripe_donation_url: e.target.value });
              }}
            />
            <p className="admin-muted" style={{ marginTop: 8, fontSize: '0.82rem', lineHeight: 1.5 }}>
              If set, the Donate button automatically opens this URL. Use a Stripe Payment Link configured for
              customer-chosen amount.
            </p>
          </div>
          <div className="admin-panel" style={{ borderStyle: 'dashed' }}>
            <h3 style={{ fontSize: '0.85rem', textTransform: 'uppercase', color: 'var(--muted)', marginBottom: 8 }}>
              Bottom support buttons (homepage)
            </h3>
            <p className="admin-muted" style={{ marginTop: 0, marginBottom: 12, fontSize: '0.82rem', lineHeight: 1.45 }}>
              Add as many buttons as you want in the support section. Top header links are managed in the
              <strong> Navigation</strong> tab.
            </p>
            <p className="admin-muted" style={{ marginBottom: 12, fontSize: '0.82rem', lineHeight: 1.5 }}>
              <strong>How href works:</strong> This site uses a <strong>hash router</strong>. Store internal paths like{' '}
              <code>/p/shop</code> or <code>/game/slug</code> — no <code>#</code>, no full domain. That only works if{' '}
              <em>Open in new tab (external)</em> is <strong>off</strong>. For a hosted store (Shopify, etc.), paste the
              full <code>https://…</code> URL and leave <em>external</em> on. The slug after <code>/p/</code> must match a
              page in the <strong>Pages</strong> tab (e.g. slug <code>shop</code> → link <code>/p/shop</code>).
            </p>
            <div className="admin-grid" style={{ gap: 10 }}>
              {settings.support_buttons.map((btn, i) => (
                <div
                  key={btn.id || i}
                  className="admin-panel"
                  style={
                    settingsFieldErrors[`support_btn_${i}`]
                      ? { borderColor: 'var(--danger)', borderWidth: 1, borderStyle: 'solid' }
                      : undefined
                  }
                >
                  <div className="admin-row" style={{ justifyContent: 'space-between', marginBottom: 8 }}>
                    <strong style={{ fontSize: '0.85rem' }}>Button {i + 1}</strong>
                    <span className="admin-row">
                      <button
                        type="button"
                        disabled={i === 0}
                        onClick={() => {
                          const next = [...settings.support_buttons];
                          const [item] = next.splice(i, 1);
                          if (item) next.splice(i - 1, 0, item);
                          setSettings({ ...settings, support_buttons: next });
                        }}
                      >
                        Up
                      </button>
                      <button
                        type="button"
                        disabled={i === settings.support_buttons.length - 1}
                        onClick={() => {
                          const next = [...settings.support_buttons];
                          const [item] = next.splice(i, 1);
                          if (item) next.splice(i + 1, 0, item);
                          setSettings({ ...settings, support_buttons: next });
                        }}
                      >
                        Down
                      </button>
                      <button
                        type="button"
                        onClick={() =>
                          setSettings({
                            ...settings,
                            support_buttons: settings.support_buttons.filter((_, idx) => idx !== i),
                          })
                        }
                      >
                        Remove
                      </button>
                    </span>
                  </div>
                  <div className="admin-field">
                    <label>Label</label>
                    <input
                      value={btn.label}
                      onChange={(e) =>
                        setSettings({
                          ...settings,
                          support_buttons: settings.support_buttons.map((b, idx) =>
                            idx === i ? { ...b, label: e.target.value } : b,
                          ),
                        })
                      }
                    />
                  </div>
                  <div className="admin-field">
                    <label>Href</label>
                    <input
                      value={btn.href}
                      onChange={(e) => {
                        clearSettingsFieldError(`support_btn_${i}`);
                        setSettings({
                          ...settings,
                          support_buttons: settings.support_buttons.map((b, idx) =>
                            idx === i ? { ...b, href: e.target.value } : b,
                          ),
                        });
                      }}
                    />
                    <HrefQuickPick
                      pages={pages.map((p) => ({ slug: p.slug, title: p.title }))}
                      games={games.map((g) => ({ slug: g.slug, title: g.title }))}
                      disabled={busy}
                      onPick={(href) => {
                        clearSettingsFieldError(`support_btn_${i}`);
                        setSettings({
                          ...settings,
                          support_buttons: settings.support_buttons.map((b, idx) =>
                            idx === i ? { ...b, href } : b,
                          ),
                        });
                      }}
                    />
                    {settingsFieldErrors[`support_btn_${i}`] ? (
                      <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
                        <span aria-hidden>✗ </span>
                        {settingsFieldErrors[`support_btn_${i}`]}
                      </p>
                    ) : settingsLinkHints[`support_btn_${i}`] ? (
                      <p style={{ color: '#c9a227', fontSize: '0.82rem', marginTop: 8 }}>
                        <span aria-hidden>⚠ </span>
                        {settingsLinkHints[`support_btn_${i}`]}
                      </p>
                    ) : null}
                  </div>
                  {btn.id === 'contact' && settings.support_page_href.trim() ? (
                    <p
                      className="admin-muted"
                      style={{
                        fontSize: '0.78rem',
                        marginTop: 4,
                        padding: '8px 10px',
                        borderLeft: '3px solid var(--accent)',
                        background: 'rgba(115, 248, 255, 0.06)',
                      }}
                    >
                      <strong>Homepage uses</strong> the Support / contact path above (
                      <code>{settings.support_page_href.trim()}</code>), not this href field, for the Contact button.
                    </p>
                  ) : null}
                  {btn.id === 'donate' && settings.stripe_donation_url.trim() ? (
                    <p
                      className="admin-muted"
                      style={{
                        fontSize: '0.78rem',
                        marginTop: 4,
                        padding: '8px 10px',
                        borderLeft: '3px solid var(--accent)',
                        background: 'rgba(115, 248, 255, 0.06)',
                      }}
                    >
                      <strong>Homepage uses</strong> the Stripe donation URL field for Donate, not this href.
                    </p>
                  ) : null}
                  <label className="admin-row" style={{ gap: 8 }}>
                    <input
                      type="checkbox"
                      checked={btn.external ?? false}
                      onChange={(e) => {
                        clearSettingsFieldError(`support_btn_${i}`);
                        setSettings({
                          ...settings,
                          support_buttons: settings.support_buttons.map((b, idx) =>
                            idx === i ? { ...b, external: e.target.checked } : b,
                          ),
                        });
                      }}
                    />
                    Open in new tab (external)
                  </label>
                </div>
              ))}
            </div>
            <button
              type="button"
              style={{ marginTop: 10 }}
              onClick={() =>
                setSettings({
                  ...settings,
                  support_buttons: [...settings.support_buttons, newSupportButton()],
                })
              }
            >
              Add support button
            </button>
          </div>

          <div className="admin-panel" style={{ borderStyle: 'dashed' }}>
            <h3 style={{ fontSize: '0.85rem', textTransform: 'uppercase', color: 'var(--muted)', marginBottom: 8 }}>
              Homepage events &amp; promos
            </h3>
            <p className="admin-muted" style={{ marginTop: 0, marginBottom: 12, fontSize: '0.82rem', lineHeight: 1.55 }}>
              Announcement cards above the game grid. Leave dates empty to show whenever <strong>Active</strong> is on.
              Use <code>YYYY-MM-DD</code> or a full ISO timestamp. “Learn more” uses the optional link.
            </p>
            {(settings.promo_events ?? []).map((ev, i) => (
              <div
                key={ev.id}
                className="admin-panel"
                style={{
                  marginBottom: 12,
                  borderStyle: 'solid',
                  padding: 12,
                  ...(settingsFieldErrors[`promo_${i}_href`]
                    ? { borderColor: 'var(--danger)', borderWidth: 1 }
                    : {}),
                }}
              >
                <div className="admin-row" style={{ justifyContent: 'space-between', marginBottom: 8 }}>
                  <strong style={{ fontSize: '0.85rem' }}>Event {i + 1}</strong>
                  <button
                    type="button"
                    onClick={() =>
                      setSettings({
                        ...settings,
                        promo_events: settings.promo_events.filter((_, idx) => idx !== i),
                      })
                    }
                  >
                    Remove
                  </button>
                </div>
                <div className="admin-field">
                  <label>Title</label>
                  <input
                    value={ev.title}
                    onChange={(e) =>
                      setSettings({
                        ...settings,
                        promo_events: settings.promo_events.map((x, idx) =>
                          idx === i ? { ...x, title: e.target.value } : x,
                        ),
                      })
                    }
                  />
                </div>
                <div className="admin-field">
                  <label>Body (optional)</label>
                  <textarea
                    rows={3}
                    value={ev.body}
                    onChange={(e) =>
                      setSettings({
                        ...settings,
                        promo_events: settings.promo_events.map((x, idx) =>
                          idx === i ? { ...x, body: e.target.value } : x,
                        ),
                      })
                    }
                  />
                </div>
                <div className="admin-field">
                  <label>Link href (optional)</label>
                  <input
                    placeholder="/p/about or https://…"
                    value={ev.href}
                    onChange={(e) => {
                      clearSettingsFieldError(`promo_${i}_href`);
                      setSettings({
                        ...settings,
                        promo_events: settings.promo_events.map((x, idx) =>
                          idx === i ? { ...x, href: e.target.value } : x,
                        ),
                      });
                    }}
                  />
                  <HrefQuickPick
                    pages={pages.map((p) => ({ slug: p.slug, title: p.title }))}
                    games={games.map((g) => ({ slug: g.slug, title: g.title }))}
                    disabled={busy}
                    onPick={(href) => {
                      clearSettingsFieldError(`promo_${i}_href`);
                      setSettings({
                        ...settings,
                        promo_events: settings.promo_events.map((x, idx) =>
                          idx === i ? { ...x, href } : x,
                        ),
                      });
                    }}
                  />
                  {settingsFieldErrors[`promo_${i}_href`] ? (
                    <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
                      <span aria-hidden>✗ </span>
                      {settingsFieldErrors[`promo_${i}_href`]}
                    </p>
                  ) : settingsLinkHints[`promo_${i}_href`] ? (
                    <p style={{ color: '#c9a227', fontSize: '0.82rem', marginTop: 8 }}>
                      <span aria-hidden>⚠ </span>
                      {settingsLinkHints[`promo_${i}_href`]}
                    </p>
                  ) : null}
                </div>
                <div className="admin-grid" style={{ gap: 8 }}>
                  <div className="admin-field">
                    <label>Starts (optional)</label>
                    <input
                      type="text"
                      placeholder="YYYY-MM-DD"
                      value={ev.starts_at ?? ''}
                      onChange={(e) =>
                        setSettings({
                          ...settings,
                          promo_events: settings.promo_events.map((x, idx) =>
                            idx === i
                              ? { ...x, starts_at: e.target.value.trim() || null }
                              : x,
                          ),
                        })
                      }
                    />
                  </div>
                  <div className="admin-field">
                    <label>Ends (optional)</label>
                    <input
                      type="text"
                      placeholder="YYYY-MM-DD"
                      value={ev.ends_at ?? ''}
                      onChange={(e) =>
                        setSettings({
                          ...settings,
                          promo_events: settings.promo_events.map((x, idx) =>
                            idx === i ? { ...x, ends_at: e.target.value.trim() || null } : x,
                          ),
                        })
                      }
                    />
                  </div>
                </div>
                <label className="admin-row" style={{ gap: 8, marginTop: 8 }}>
                  <input
                    type="checkbox"
                    checked={ev.external}
                    onChange={(e) => {
                      clearSettingsFieldError(`promo_${i}_href`);
                      setSettings({
                        ...settings,
                        promo_events: settings.promo_events.map((x, idx) =>
                          idx === i ? { ...x, external: e.target.checked } : x,
                        ),
                      });
                    }}
                  />
                  External link (new tab)
                </label>
                <label className="admin-row" style={{ gap: 8 }}>
                  <input
                    type="checkbox"
                    checked={ev.active}
                    onChange={(e) =>
                      setSettings({
                        ...settings,
                        promo_events: settings.promo_events.map((x, idx) =>
                          idx === i ? { ...x, active: e.target.checked } : x,
                        ),
                      })
                    }
                  />
                  Active
                </label>
              </div>
            ))}
            <button
              type="button"
              onClick={() =>
                setSettings({
                  ...settings,
                  promo_events: [...(settings.promo_events ?? []), newPromoEvent()],
                })
              }
            >
              Add homepage event
            </button>
          </div>

          <div className="admin-panel" style={{ borderStyle: 'dashed', borderColor: 'rgba(115, 248, 255, 0.35)' }}>
            <p className="admin-muted" style={{ margin: 0, fontSize: '0.85rem', lineHeight: 1.55 }}>
              🎨 Site mood, FX layers, and global CSS →{' '}
              <button type="button" onClick={() => setTab('effects')}>
                ⚡ Effects Studio
              </button>
              . Per-game/page overrides → <strong>🎮 Games</strong> / <strong>📄 Pages</strong> →{' '}
              <strong>🎨 Appearance</strong>.
            </p>
          </div>

          <div className="admin-field">
            <label htmlFor="footer_text">Footer</label>
            <textarea
              id="footer_text"
              value={settings.footer_text}
              onChange={(e) => setSettings({ ...settings, footer_text: e.target.value })}
            />
          </div>
          <div className="admin-row" style={{ alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
            <button type="button" disabled={busy || !settingsDirty} onClick={onSaveSettings}>
              {busy ? 'Saving…' : settingsDirty ? 'Save settings' : 'Saved'}
            </button>
            {settingsSaveStatus === 'success' && !settingsDirty ? (
              <span
                style={{ color: '#3ecf8e', fontSize: '1.35rem', lineHeight: 1 }}
                title="Saved successfully"
                aria-label="Saved successfully"
              >
                ✓
              </span>
            ) : null}
            {settingsSaveStatus === 'error' ? (
              <span
                style={{ color: 'var(--danger)', fontSize: '1.35rem', lineHeight: 1 }}
                title="Save failed or validation error"
                aria-label="Save failed or validation error"
              >
                ✗
              </span>
            ) : null}
            {settingsDirty ? (
              <span className="admin-muted" style={{ fontSize: '0.78rem', color: '#ffbf5f' }}>
                Unsaved changes — floating Save bar at the bottom is also active.
              </span>
            ) : null}
          </div>
          {settingsSaveDetail ? (
            <p
              style={{
                marginTop: 10,
                fontSize: '0.88rem',
                lineHeight: 1.45,
                color: settingsSaveStatus === 'error' ? 'var(--danger)' : 'var(--muted)',
              }}
              role={settingsSaveStatus === 'error' ? 'alert' : undefined}
            >
              {settingsSaveDetail}
            </p>
          ) : null}
        </div>
      )}

      {tab === 'games' && (
        <div className="admin-grid">
          <div className="admin-panel admin-grid">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Add or update game
            </h2>
            <p className="admin-muted" style={{ lineHeight: 1.55 }}>
              <strong>Quick add:</strong> enter a <strong>title</strong>, upload the Godot Web <strong>.zip</strong> (or set an
              external play URL). The URL slug is optional — if you leave it blank, we derive it from the title. Main game
              hub is <code>/#/</code>; the <strong>secret library</strong> is <code>/#/vault</code> (check “List in Vault”
              so the row appears there; uncheck “Published” to hide it from the main hub).
            </p>
            <div className="admin-field">
              <label htmlFor="g_title">Title (required)</label>
              <p className="admin-muted" style={{ margin: '0 0 6px', textTransform: 'none', fontSize: '0.8rem' }}>
                Display name on cards and the game page. Saving and ZIP upload both require a title.
              </p>
              <input
                id="g_title"
                value={gameDraft.title}
                onChange={(e) => {
                  clearGameFieldError('title');
                  setGameDraft({ ...gameDraft, title: e.target.value });
                }}
              />
              {gameFieldErrors.title ? (
                <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
                  <span aria-hidden>✗ </span>
                  {gameFieldErrors.title}
                </p>
              ) : null}
            </div>
            <div className="admin-field">
              <label htmlFor="g_slug">Slug (optional — URL id)</label>
              <p className="admin-muted" style={{ margin: '0 0 6px', textTransform: 'none', fontSize: '0.8rem' }}>
                Override the address bar id. If empty, we build one from the title (lowercase, hyphens). Effective id now:{' '}
                <code>{gameSlugEffective || '— fill title'}</code>
              </p>
              <input
                id="g_slug"
                value={gameDraft.slug}
                onChange={(e) => {
                  clearGameFieldError('play');
                  setGameDraft({ ...gameDraft, slug: e.target.value });
                }}
              />
            </div>
            {gameSlugEffective ? (
              <div
                className="admin-panel"
                style={{ borderStyle: 'dashed', marginTop: 4, padding: '12px 14px', fontSize: '0.82rem', lineHeight: 1.55 }}
              >
                <strong style={{ display: 'block', marginBottom: 8 }}>Public links (hash router)</strong>
                <div className="admin-row" style={{ flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
                  <span>
                    Detail <code>/#/game/{gameSlugEffective}</code>
                  </span>
                  <button
                    type="button"
                    onClick={() => {
                      if (copyPublicHashUrl(`/game/${gameSlugEffective}`)) {
                        flash('Copied detail URL.');
                      }
                    }}
                  >
                    Copy detail
                  </button>
                </div>
                <div className="admin-row" style={{ flexWrap: 'wrap', gap: 8, alignItems: 'center', marginTop: 8 }}>
                  <span>
                    Play <code>/#/play/{gameSlugEffective}</code>
                  </span>
                  <button
                    type="button"
                    onClick={() => {
                      if (copyPublicHashUrl(`/play/${gameSlugEffective}`)) {
                        flash('Copied play URL.');
                      }
                    }}
                  >
                    Copy play
                  </button>
                </div>
                <p className="admin-muted" style={{ margin: '10px 0 0' }}>
                  Vault catalog (all games flagged “List in Vault”): <code>/#/vault</code>
                </p>
              </div>
            ) : null}
            {gameFieldErrors.play ? (
              <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
                <span aria-hidden>✗ </span>
                {gameFieldErrors.play}
              </p>
            ) : null}
            <div className="admin-field">
              <label htmlFor="g_type">Type</label>
              <select
                id="g_type"
                value={gameDraft.type ?? 'game'}
                onChange={(e) => setGameDraft({ ...gameDraft, type: e.target.value })}
              >
                <option value="game">game</option>
                <option value="asset">asset</option>
              </select>
            </div>
            <div className="admin-field">
              <label htmlFor="g_desc">Short description</label>
              <textarea
                id="g_desc"
                value={gameDraft.description ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, description: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="g_details">Long details</label>
              <textarea
                id="g_details"
                value={gameDraft.details ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, details: e.target.value })}
              />
              <p className="admin-muted" style={{ margin: '8px 0 0', fontSize: '0.82rem', lineHeight: 1.5 }}>
                Shown on the game page when you have no content blocks below — otherwise use blocks for layout.
              </p>
            </div>

            <RouteAppearancePanel
              kind="game"
              value={gameDraft}
              onChange={(patch) => setGameDraft({ ...gameDraft, ...patch })}
              customCssError={gameFieldErrors.custom_mood_css}
              onClearCustomCssError={() => clearGameFieldError('custom_mood_css')}
              onOpenEffectsTab={() => setTab('effects')}
            />
            <label className="admin-row" style={{ gap: 8 }}>
              <input
                type="checkbox"
                checked={gameDraft.in_vault ?? false}
                onChange={(e) => setGameDraft({ ...gameDraft, in_vault: e.target.checked })}
              />
              🔐 List in Vault (<code>/#/vault</code>) — secret catalog, separate from the main hub grid
            </label>

            {/* ===== Game-page enrichment (migration 018) =================
                Each field is optional. Empty arrays don't render anything
                on the public page. */}
            <details className="admin-panel" style={{ marginTop: 8, borderStyle: 'dashed' }}>
              <summary style={{ cursor: 'pointer', textTransform: 'uppercase', letterSpacing: '0.06em', color: 'var(--muted)', fontSize: '0.82rem' }}>
                Game info panels (tags, platforms, screenshots, features, controls, credits, changelog)
              </summary>

              <div className="admin-field" style={{ marginTop: 12 }}>
                <label>Release date</label>
                <input
                  type="text"
                  value={gameDraft.release_date ?? ''}
                  onChange={(e) => setGameDraft({ ...gameDraft, release_date: e.target.value })}
                  placeholder="2026-04-12 or Coming Soon"
                />
              </div>

              <div className="admin-field">
                <label>Tags (one per line or comma-separated)</label>
                <textarea
                  rows={2}
                  value={(gameDraft.tags ?? []).join('\n')}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      tags: e.target.value.split(/[\n,]/).map((s) => s.trim()).filter(Boolean),
                    })
                  }
                  placeholder="one tag per line"
                />
              </div>

              <div className="admin-field">
                <label>Platforms (chips shown below the title)</label>
                <textarea
                  rows={2}
                  value={(gameDraft.platforms ?? []).join('\n')}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      platforms: e.target.value.split(/[\n,]/).map((s) => s.trim()).filter(Boolean),
                    })
                  }
                  placeholder="html5, windows, mac — one per line"
                />
              </div>

              <div className="admin-field">
                <label>Screenshot URLs (one per line)</label>
                <textarea
                  rows={3}
                  value={(gameDraft.screenshots ?? []).join('\n')}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      screenshots: e.target.value.split('\n').map((s) => s.trim()).filter(Boolean),
                    })
                  }
                  placeholder="https://…/screen1.png — one URL per line"
                />
                <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 4 }}>
                  Or use a gallery block in the detail page editor below for captions + lightbox.
                </p>
              </div>

              <div className="admin-field">
                <label>Key features (one bullet per line)</label>
                <textarea
                  rows={3}
                  value={(gameDraft.features ?? []).join('\n')}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      features: e.target.value.split('\n').map((s) => s.trim()).filter(Boolean),
                    })
                  }
                  placeholder="one feature per line"
                />
              </div>

              <div className="admin-field">
                <label>System requirements (one per line)</label>
                <textarea
                  rows={3}
                  value={(gameDraft.system_requirements ?? []).join('\n')}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      system_requirements: e.target.value.split('\n').map((s) => s.trim()).filter(Boolean),
                    })
                  }
                  placeholder="one requirement per line"
                />
              </div>

              <div className="admin-field">
                <label>Controls (key → description)</label>
                <p className="admin-muted" style={{ fontSize: '0.78rem', margin: '0 0 6px' }}>
                  Lines like <code>WASD = Move</code> or <code>Space|Jump</code>. Empty lines ignored.
                </p>
                <textarea
                  rows={4}
                  value={(gameDraft.controls ?? []).map((c) => `${c.key} = ${c.desc}`).join('\n')}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      controls: e.target.value
                        .split('\n')
                        .map((l) => {
                          const m = l.match(/^\s*(.+?)\s*[=|]\s*(.+)\s*$/);
                          if (!m || !m[1] || !m[2]) return null;
                          return { id: crypto.randomUUID(), key: m[1], desc: m[2] };
                        })
                        .filter(Boolean) as { id: string; key: string; desc: string }[],
                    })
                  }
                  placeholder={'WASD = Move\nSpace = Jump\nLMB = Attack'}
                />
              </div>

              <div className="admin-field">
                <label>Credits (role → name [→ link])</label>
                <p className="admin-muted" style={{ fontSize: '0.78rem', margin: '0 0 6px' }}>
                  Lines like <code>Code = Sam</code> or <code>Art = Pat = https://pat.example</code>.
                </p>
                <textarea
                  rows={4}
                  value={(gameDraft.credits ?? [])
                    .map((c) => `${c.role} = ${c.name}${c.href ? ` = ${c.href}` : ''}`)
                    .join('\n')}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      credits: e.target.value
                        .split('\n')
                        .map((l) => {
                          const parts = l.split('=').map((p) => p.trim());
                          if (parts.length < 2 || !parts[0] || !parts[1]) return null;
                          const out: { id: string; role: string; name: string; href?: string } = {
                            id: crypto.randomUUID(),
                            role: parts[0],
                            name: parts[1],
                          };
                          if (parts[2]) out.href = parts[2];
                          return out;
                        })
                        .filter(Boolean) as { id: string; role: string; name: string; href?: string }[],
                    })
                  }
                  placeholder={'Code = Sam\nArt = Pat = https://pat.example\nMusic = Anonymous'}
                />
              </div>

              <div className="admin-field">
                <label>Changelog (one entry per blank-line block)</label>
                <p className="admin-muted" style={{ fontSize: '0.78rem', margin: '0 0 6px' }}>
                  First line: <code>v1.2 | 2026-05-01</code> (date optional). Lines below: release notes.
                </p>
                <textarea
                  rows={6}
                  value={(gameDraft.changelog ?? [])
                    .map((c) => `v${c.version}${c.date ? ` | ${c.date}` : ''}\n${c.notes}`)
                    .join('\n\n')}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      changelog: e.target.value
                        .split(/\n{2,}/)
                        .map((block) => {
                          const [head, ...rest] = block.split('\n');
                          if (!head) return null;
                          const m = head.match(/^v?\s*([\w.\-]+)(?:\s*\|\s*(.+))?$/);
                          if (!m || !m[1]) return null;
                          const entry: { id: string; version: string; date?: string; notes: string } = {
                            id: crypto.randomUUID(),
                            version: m[1],
                            notes: rest.join('\n').trim(),
                          };
                          if (m[2]) entry.date = m[2].trim();
                          return entry;
                        })
                        .filter(Boolean) as { id: string; version: string; date?: string; notes: string }[],
                    })
                  }
                  placeholder={'v1.0 | 2026-05-12\nInitial public release.\n\nv0.9 | 2026-05-01\nBeta tweaks.'}
                />
              </div>
            </details>

            <h3 style={{ fontSize: '0.85rem', textTransform: 'uppercase', color: 'var(--muted)', marginTop: 8 }}>
              Detail page blocks
            </h3>
            <p className="admin-muted" style={{ marginTop: 0, fontSize: '0.85rem', lineHeight: 1.5 }}>
              Build the itch-style page under the playable embed. Use <strong>Add block → Buttons / CTA / Tabs</strong> for
              in-page navigation and calls-to-action. Requires the game slug before uploading images here. Global hub nav
              placement is under <strong>Behavior → Site chrome</strong>.
            </p>
            <PageSectionsForm
              sections={gameDraft.sections ?? []}
              onChange={(sections) => setGameDraft({ ...gameDraft, sections })}
              pageSlug={gameSlugEffective}
              mediaStorageFolder="game-detail"
              formDisabled={busy}
              onNotify={flash}
            />

            <div className="admin-field">
              <label htmlFor="g_thumb_file">Thumbnail</label>
              <p className="admin-muted" style={{ margin: '0 0 10px' }}>
                Cover image for the hub card and game page. PNG, JPG, GIF, WebP, or SVG — max 5 MB.
              </p>
              {gameDraft.thumbnail_url?.trim() ? (
                <div
                  style={{
                    marginBottom: 12,
                    position: 'relative',
                    display: 'inline-block',
                    maxWidth: '100%',
                  }}
                >
                  <img
                    src={gameDraft.thumbnail_url}
                    alt=""
                    style={{
                      maxWidth: '100%',
                      maxHeight: 140,
                      objectFit: 'contain',
                      borderRadius: 6,
                      border: '1px solid var(--border)',
                      background: '#070b12',
                      display: 'block',
                    }}
                  />
                  {gameDraft.gumroad_url?.trim() ? (
                    <span
                      className="game-thumbnail__gumroad-star"
                      style={{ fontSize: '1.1rem', top: 4, right: 4 }}
                      title="Gumroad link set — hub will show this star on the card"
                      role="img"
                      aria-label="Gumroad preview"
                    >
                      ★
                    </span>
                  ) : null}
                </div>
              ) : null}
              <input
                id="g_thumb_file"
                ref={thumbFileRef}
                type="file"
                accept="image/png,image/jpeg,image/gif,image/webp,image/svg+xml,.svg"
                disabled={busy || !gameSlugEffective}
                style={{ display: 'none' }}
                aria-hidden
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) {
                    void onUploadGameThumbnailFile(f);
                  }
                  e.target.value = '';
                }}
              />
              <button
                type="button"
                id="g_thumb_add_file"
                disabled={busy || !gameSlugEffective}
                onClick={() => thumbFileRef.current?.click()}
              >
                Add file
              </button>
              {!gameSlugEffective ? (
                <p className="admin-muted" style={{ margin: '8px 0 0' }}>
                  Enter a <strong>title</strong> (or slug) first so media uploads know which game folder to use.
                </p>
              ) : null}
              <div className="admin-field" style={{ marginTop: 16, marginBottom: 0 }}>
                <label htmlFor="g_thumb" className="admin-muted" style={{ fontSize: '0.85rem' }}>
                  Or paste an image link (optional)
                </label>
                <input
                  id="g_thumb"
                  placeholder="https://…"
                  value={gameDraft.thumbnail_url ?? ''}
                  onChange={(e) => setGameDraft({ ...gameDraft, thumbnail_url: e.target.value })}
                />
              </div>
            </div>
            <div className="admin-field">
              <label htmlFor="g_tab_icon">Browser tab icon (optional)</label>
              <p className="admin-muted" style={{ margin: '0 0 8px', textTransform: 'none', fontSize: '0.82rem' }}>
                Shown in the browser tab on this game&apos;s detail and play pages. Square 32–64px PNG or
                SVG works best. If empty, the hub thumbnail is used, then the site favicon from{' '}
                <strong>SEO + Head</strong>.
              </p>
              {gameDraft.tab_icon_url?.trim() ? (
                <img
                  src={gameDraft.tab_icon_url}
                  alt=""
                  width={48}
                  height={48}
                  style={{ display: 'block', marginBottom: 10, borderRadius: 8, border: '1px solid var(--border)' }}
                />
              ) : null}
              <input
                id="g_tab_icon_file"
                ref={tabIconFileRef}
                type="file"
                accept="image/png,image/jpeg,image/gif,image/webp,image/svg+xml,.png,.jpg,.jpeg,.gif,.webp,.svg"
                disabled={busy || !gameSlugEffective}
                style={{ display: 'none' }}
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) void onUploadGameTabIconFile(f);
                }}
              />
              <button
                type="button"
                disabled={busy || !gameSlugEffective}
                onClick={() => tabIconFileRef.current?.click()}
              >
                Upload tab icon
              </button>
              <div className="admin-field" style={{ marginTop: 12, marginBottom: 0 }}>
                <label htmlFor="g_tab_icon" className="admin-muted" style={{ fontSize: '0.85rem' }}>
                  Or paste image URL
                </label>
                <input
                  id="g_tab_icon"
                  placeholder="https://…"
                  value={gameDraft.tab_icon_url ?? ''}
                  onChange={(e) => setGameDraft({ ...gameDraft, tab_icon_url: e.target.value })}
                />
              </div>
            </div>
            <div className="admin-field">
              <label htmlFor="g_preview_video">Preview video URL (optional)</label>
              <input
                id="g_preview_video"
                value={gameDraft.preview_video_url ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, preview_video_url: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="g_preview_video_file">Upload preview video</label>
              <p className="admin-muted" style={{ margin: '0 0 8px' }}>
                MP4, WebM, or MOV — max 100 MB. Shown on the game page and hub Info modal.
              </p>
              <input
                id="g_preview_video_file"
                ref={previewVideoFileRef}
                type="file"
                accept="video/mp4,video/webm,video/quicktime,.mp4,.webm,.mov"
                disabled={busy || !gameSlugEffective}
              />
              <div style={{ marginTop: 8 }}>
                <button
                  type="button"
                  disabled={busy || !gameSlugEffective}
                  onClick={() => void onUploadGamePreviewVideoFile()}
                >
                  Upload preview video & save
                </button>
              </div>
            </div>
            <div className="admin-field">
              <label htmlFor="g_ext">External play URL (optional)</label>
              <p className="admin-muted" style={{ margin: '0 0 6px', textTransform: 'none', fontSize: '0.82rem' }}>
                Only used when <strong>no cloud ZIP</strong> is linked below. If both are set, Play uses your uploaded
                ZIP. Clear this field if you pasted a bad link (wrong links here used to make Play show raw JS/code).
              </p>
              <input
                id="g_ext"
                value={gameDraft.external_url ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, external_url: e.target.value })}
              />
            </div>
            {/* Commerce: Gumroad / external URL vs built-in Stripe (Edge create-checkout-session). */}
            <div className="admin-field">
              <label htmlFor="g_gumroad_url">Gumroad URL (optional)</label>
              <input
                id="g_gumroad_url"
                type="url"
                placeholder="https://yourstudio.gumroad.com/l/…"
                value={gameDraft.gumroad_url ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, gumroad_url: e.target.value })}
              />
              <p className="admin-muted" style={{ margin: '8px 0 0', fontSize: '0.82rem' }}>
                When set, the hub shows a <strong>★</strong> on this game&apos;s cover image and the buy button opens
                Gumroad (download / purchase there). Built-in <strong>Stripe Checkout</strong> below is skipped while
                this URL is filled — you can still configure Stripe for other games later.
              </p>
            </div>
            <div className="admin-field">
              <label htmlFor="g_pricing_model">Pricing (Stripe on this site)</label>
              <select
                id="g_pricing_model"
                value={(gameDraft.pricing_model ?? 'free') as GamePricingModel}
                onChange={(e) =>
                  setGameDraft({
                    ...gameDraft,
                    pricing_model: e.target.value as GamePricingModel,
                  })
                }
              >
                <option value="free">Free (no Stripe checkout on this site)</option>
                <option value="fixed">Fixed price — Stripe Checkout</option>
                <option value="pwyw">Pay what you want — Stripe Checkout</option>
                <option value="donation">Donation / support — Stripe Checkout</option>
              </select>
              <p className="admin-muted" style={{ margin: '8px 0 0', fontSize: '0.82rem' }}>
                Used only when <strong>Gumroad</strong> and <strong>Other external checkout</strong> below are empty.
                Requires the Edge Function <code>create-checkout-session</code> (see{' '}
                <strong>docs/STRIPE_CHECKOUT.md</strong>). Minimum charge <strong>$0.50 USD</strong> (Stripe rule).
              </p>
            </div>
            {gameDraft.pricing_model === 'fixed' ? (
              <div className="admin-field">
                <label htmlFor="g_price">Price (USD)</label>
                <input
                  id="g_price"
                  type="number"
                  min={0}
                  step={0.01}
                  value={Number(gameDraft.price_cents ?? 0) / 100}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      price_cents: Math.max(0, Math.round(Number(e.target.value || 0) * 100)),
                    })
                  }
                />
              </div>
            ) : null}
            {gameDraft.pricing_model === 'pwyw' || gameDraft.pricing_model === 'donation' ? (
              <>
                <div className="admin-field">
                  <label htmlFor="g_pwyw_min">Minimum amount (USD)</label>
                  <input
                    id="g_pwyw_min"
                    type="number"
                    min={0}
                    step={0.01}
                    value={Number(gameDraft.pwyw_min_cents ?? 0) / 100}
                    onChange={(e) =>
                      setGameDraft({
                        ...gameDraft,
                        pwyw_min_cents: Math.max(0, Math.round(Number(e.target.value || 0) * 100)),
                      })
                    }
                  />
                  <p className="admin-muted" style={{ margin: '8px 0 0', fontSize: '0.82rem' }}>
                    Checkout still enforces at least $0.50 if you leave this lower.
                  </p>
                </div>
              </>
            ) : null}
            {gameDraft.pricing_model === 'pwyw' ? (
              <div className="admin-field">
                <label htmlFor="g_pwyw_suggested">Suggested amount (USD, optional)</label>
                <input
                  id="g_pwyw_suggested"
                  type="number"
                  min={0}
                  step={0.01}
                  value={Number(gameDraft.pwyw_suggested_cents ?? 0) / 100}
                  onChange={(e) =>
                    setGameDraft({
                      ...gameDraft,
                      pwyw_suggested_cents: Math.max(0, Math.round(Number(e.target.value || 0) * 100)),
                    })
                  }
                />
              </div>
            ) : null}
            {gameDraft.pricing_model === 'donation' ? (
              <div className="admin-field">
                <label htmlFor="g_donation_presets">Quick amounts (USD, comma-separated)</label>
                <input
                  id="g_donation_presets"
                  placeholder="5, 10, 25"
                  value={(gameDraft.donation_presets_cents ?? [])
                    .map((c) => (c / 100).toString())
                    .join(', ')}
                  onChange={(e) => {
                    const cents = e.target.value
                      .split(',')
                      .map((s) => Math.round(parseFloat(s.trim()) * 100))
                      .filter((n) => Number.isFinite(n) && n > 0);
                    setGameDraft({
                      ...gameDraft,
                      donation_presets_cents: [...new Set(cents)].sort((a, b) => a - b),
                    });
                  }}
                />
              </div>
            ) : null}
            <div className="admin-field">
              <label htmlFor="g_purchase_url">Other external checkout URL (optional)</label>
              <input
                id="g_purchase_url"
                placeholder="https://buy.stripe.com/... or itch.io / your store"
                value={gameDraft.purchase_url ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, purchase_url: e.target.value })}
              />
              <p className="admin-muted" style={{ margin: '8px 0 0', fontSize: '0.82rem' }}>
                If set (and Gumroad is empty), the game page links here instead of Stripe Checkout. Use{' '}
                <strong>Gumroad URL</strong> above for Gumroad so the ★ badge appears on the card.
              </p>
            </div>
            <div className="admin-field">
              <label htmlFor="g_stripe_price_id">Stripe Price ID (optional, fixed price only)</label>
              <input
                id="g_stripe_price_id"
                placeholder="price_..."
                value={gameDraft.stripe_price_id ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, stripe_price_id: e.target.value })}
              />
              <p className="admin-muted" style={{ margin: '8px 0 0', fontSize: '0.82rem' }}>
                If set for a <strong>fixed</strong> price, Checkout uses this Price instead of the USD field above.
              </p>
            </div>
            <div className="admin-field">
              <label htmlFor="g_folder">Local folder (optional, defaults to slug)</label>
              <input
                id="g_folder"
                value={gameDraft.local_folder ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, local_folder: e.target.value })}
              />
            </div>
            <div className="admin-panel admin-grid danger-zone" style={{ borderStyle: 'dashed' }}>
              <h3 style={{ fontSize: '0.85rem', textTransform: 'uppercase', color: 'var(--accent)' }}>
                Cloud HTML5 (itch-style ZIP)
              </h3>
              <p className="admin-muted" style={{ margin: '0 0 10px', lineHeight: 1.55 }}>
                Upload <strong>one .zip per game</strong> (the whole Godot Web export). We upload <strong>every file</strong>{' '}
                with the same folders as in the ZIP — like itch/static hosting — then open the best{' '}
                <code>index.html</code> next to <code>.wasm</code> / <code>.pck</code>. If Play breaks after a code update,
                upload the ZIP again for that game.
              </p>
              <p className="admin-muted" style={{ margin: '0 0 10px', lineHeight: 1.55 }}>
                <strong>Godot 4 — blank screen or SharedArrayBuffer / cross-origin errors?</strong> Supabase
                Storage does not send the special isolation headers some threaded Web builds need. Fix: export with{' '}
                <strong>threads disabled</strong> for HTML5, <em>or</em> host the build on itch.io / Netlify /
                Cloudflare Pages and paste that URL in <strong>External play URL</strong> instead of ZIP upload.
              </p>
              <p className="admin-muted" style={{ margin: '0 0 10px', lineHeight: 1.55 }}>
                Multi-GB builds are supported — keep this tab open until upload finishes. Files upload a few
                at a time so your browser does not run out of memory on large <code>.pck</code> /{' '}
                <code>.wasm</code> files.
              </p>
              {gameDraft.storage_slug ? (
                <p className="admin-muted" style={{ margin: '0 0 10px', lineHeight: 1.55 }}>
                  Cloud folder: <code>{gameDraft.storage_slug}</code>
                  {' · '}
                  <a
                    href={publicGameEntryUrl(
                      gameDraft.storage_slug,
                      gameDraft.storage_entry_in_zip?.trim() || 'index.html',
                    )}
                    target="_blank"
                    rel="noreferrer"
                  >
                    Open hosted game page (sanity check)
                  </a>
                  <br />
                  <span style={{ opacity: 0.92 }}>
                    Games are hosted from <code>games/&lt;slug&gt;/</code> in the repo or via an external{' '}
                    <strong>Play URL</strong> in <code>games.json</code>. See <code>docs/NO_SUPABASE_SETUP.md</code>.
                  </span>
                </p>
              ) : null}
              {zipCloudConfirmed ? (
                <div className="admin-cloud-build-ok" role="status" aria-live="polite">
                  <strong>✓ Cloud build linked</strong>
                  <span className="admin-muted" style={{ display: 'block', marginTop: 6, lineHeight: 1.5 }}>
                    Folder <code>{gameDraft.storage_slug}</code> is on Storage and tied to this game. Pick another ZIP
                    only when you want to replace it.
                  </span>
                </div>
              ) : null}
              <div className="admin-field">
                <div
                  className="admin-row"
                  style={{ alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: '8px 12px' }}
                >
                  <label htmlFor="g_zip" style={{ marginBottom: 0 }}>
                    Web export .zip
                  </label>
                  {zipCloudConfirmed ? (
                    <span className="admin-upload-ok admin-upload-ok--inline" role="status">
                      ✓ Ready
                    </span>
                  ) : null}
                </div>
                <input
                  id="g_zip"
                  type="file"
                  accept=".zip,application/zip"
                  disabled={busy || !gameSlugEffective}
                  onChange={(e) => {
                    setGameZipFile(e.target.files?.[0] ?? null);
                    setZipUploadHint(null);
                    setZipEntryCandidates([]);
                    setZipEntryPick('');
                  }}
                />
                {zipUploadHint ? (
                  <p className="admin-upload-progress">{zipUploadHint}</p>
                ) : null}
                {zipEntryCandidates.length > 1 ? (
                  <div className="admin-field" style={{ marginTop: 14, marginBottom: 0 }}>
                    <label htmlFor="g_zip_entry">Override entry (only if Play picks the wrong HTML)</label>
                    <select
                      id="g_zip_entry"
                      value={zipEntryPick || zipEntryCandidates[0] || ''}
                      disabled={busy}
                      onChange={(e) => {
                        const value = e.target.value;
                        setZipEntryPick(value);
                        setGameDraft((prev) => ({ ...prev, storage_entry_in_zip: value || null }));
                      }}
                    >
                      {zipEntryCandidates.map((rel) => (
                        <option key={rel} value={rel}>
                          {rel}
                        </option>
                      ))}
                    </select>
                    <p
                      className="admin-muted"
                      style={{ marginTop: 8, textTransform: 'none', fontSize: '0.82rem', lineHeight: 1.5 }}
                    >
                      The site already selected the most likely Godot export. Change this only if you still see the
                      wrong page, then click <strong>Save game</strong>.
                    </p>
                  </div>
                ) : gameDraft.storage_entry_in_zip?.trim() && !gameZipFile ? (
                  <p className="admin-muted" style={{ marginTop: 10 }}>
                    Last upload used entry: <code>{gameDraft.storage_entry_in_zip}</code> — choose a ZIP again to change
                    it.
                  </p>
                ) : null}
              </div>
              <div className="admin-row" style={{ flexWrap: 'wrap', gap: 8 }}>
                <button
                  type="button"
                  disabled={busy || !gameZipFile || !gameSlugEffective}
                  onClick={onUploadGameZip}
                >
                  Upload ZIP & save game
                </button>
                <button
                  type="button"
                  disabled={busy || !gameDraft.storage_slug}
                  title="Re-tags HTML/JS/WASM on Storage if Play shows raw code"
                  onClick={async () => {
                    const key = gameDraft.storage_slug?.trim();
                    if (!key || !confirm('Re-apply correct file types for every file in this game’s Storage folder? Large games can take a few minutes.')) {
                      return;
                    }
                    setBusy(true);
                    setZipUploadHint(null);
                    try {
                      const { repaired } = await repairGameBuildContentTypes(key, (done, total) => {
                        setZipUploadHint(`Fixing types ${done}/${total}…`);
                      });
                      flash(`Updated ${repaired} file(s). Try Play again (hard refresh).`, 8000);
                    } catch (e) {
                      console.error(e);
                      flash(e instanceof Error ? e.message : 'MIME repair failed', 10000);
                    } finally {
                      setZipUploadHint(null);
                      setBusy(false);
                    }
                  }}
                >
                  Fix file types on Storage
                </button>
                <button type="button" disabled={busy || !gameDraft.storage_slug} onClick={onClearHostedGame}>
                  Remove cloud build
                </button>
              </div>
            </div>
            <div className="admin-field">
              <label htmlFor="g_order">Sort order</label>
              <input
                id="g_order"
                type="number"
                value={gameDraft.sort_order ?? 0}
                onChange={(e) => setGameDraft({ ...gameDraft, sort_order: Number(e.target.value) })}
              />
            </div>
            <label className="admin-row" style={{ gap: 8 }}>
              <input
                type="checkbox"
                checked={gameDraft.published ?? true}
                onChange={(e) => setGameDraft({ ...gameDraft, published: e.target.checked })}
              />
              Published (show on main game hub — turn off for vault-only or unlisted games)
            </label>
            {gameZipFile ? (
              <p
                className="admin-warning"
                role="alert"
                style={{
                  marginTop: 4,
                  marginBottom: 4,
                  padding: '10px 12px',
                  border: '1px solid rgba(255, 180, 90, 0.6)',
                  borderRadius: 8,
                  color: '#ffd9a8',
                  lineHeight: 1.5,
                }}
              >
                You picked a new ZIP but haven&apos;t uploaded it yet. Click{' '}
                <strong>Upload ZIP &amp; save game</strong> above to replace the build —{' '}
                <strong>Save game</strong> only saves text fields and will NOT change the playable game.
              </p>
            ) : null}
            <div className="admin-row" style={{ alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
              <button type="button" disabled={busy || !gameDraft.title.trim()} onClick={onSaveGame}>
                Save game
              </button>
              {gameSaveStatus === 'success' ? (
                <span
                  style={{ color: '#3ecf8e', fontSize: '1.35rem', lineHeight: 1 }}
                  title="Saved"
                  aria-label="Game saved successfully"
                >
                  ✓
                </span>
              ) : null}
              {gameSaveStatus === 'error' ? (
                <span
                  style={{ color: 'var(--danger)', fontSize: '1.35rem', lineHeight: 1 }}
                  title="Save failed"
                  aria-label="Game save failed"
                >
                  ✗
                </span>
              ) : null}
            </div>
            {gameSaveSummary ? (
              <p className="admin-muted" style={{ marginTop: 10, fontSize: '0.86rem', lineHeight: 1.5 }}>
                {gameSaveSummary}
              </p>
            ) : null}
            {gameSaveDetail ? (
              <p style={{ marginTop: 10, fontSize: '0.86rem', lineHeight: 1.5, color: 'var(--danger)' }} role="alert">
                {gameSaveDetail}
              </p>
            ) : null}
          </div>

          <div className="admin-panel">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Existing games
            </h2>
            <ul style={{ listStyle: 'none', marginTop: 12 }}>
              {games.map((g) => (
                <li key={g.slug} className="admin-row" style={{ justifyContent: 'space-between' }}>
                  <span>
                    <strong>{g.title}</strong>{' '}
                    <span className="admin-muted">
                      ({g.slug})
                      {g.in_vault ? ' · vault' : ''}
                      {g.published === false ? ' · hidden from hub' : ''}
                      {g.immersive_layout ? ' · immersive' : ''}
                    </span>
                  </span>
                  <span className="admin-row">
                    <button
                      type="button"
                      title="Copy play URL"
                      onClick={() => {
                        if (copyPublicHashUrl(`/play/${g.slug}`)) {
                          flash('Copied play URL.');
                        }
                      }}
                    >
                      Copy play URL
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setGameDraft({
                          ...g,
                          sections: ensureSectionIds(g.sections ?? []),
                          visual_preset: g.visual_preset ?? '',
                          in_vault: Boolean(g.in_vault),
                          immersive_layout: Boolean(g.immersive_layout),
                          custom_mood_css: String(g.custom_mood_css ?? ''),
                          gumroad_url: String(g.gumroad_url ?? ''),
                          pricing_model: (g.pricing_model ?? 'free') as GamePricingModel,
                          donation_presets_cents: donationPresetsFromUnknown(g.donation_presets_cents),
                          pwyw_min_cents: g.pwyw_min_cents ?? null,
                          pwyw_suggested_cents: g.pwyw_suggested_cents ?? null,
                          // Migration 018 — game-page enrichment.
                          tags: Array.isArray(g.tags) ? g.tags : [],
                          release_date: String(g.release_date ?? ''),
                          platforms: Array.isArray(g.platforms) ? g.platforms : [],
                          screenshots: Array.isArray(g.screenshots) ? g.screenshots : [],
                          features: Array.isArray(g.features) ? g.features : [],
                          controls: Array.isArray(g.controls) ? g.controls : [],
                          credits: Array.isArray(g.credits) ? g.credits : [],
                          changelog: Array.isArray(g.changelog) ? g.changelog : [],
                          system_requirements: Array.isArray(g.system_requirements) ? g.system_requirements : [],
                          route_fx: normalizeRouteFxOverride(g.route_fx),
                        });
                        setZipEntryPick(g.storage_entry_in_zip?.trim() ?? '');
                        setGameZipFile(null);
                        setZipEntryCandidates([]);
                      }}
                    >
                      Edit
                    </button>
                    <Link to={`/game/${g.slug}`}>View</Link>
                    <button
                      type="button"
                      onClick={async () => {
                        if (!confirm(`Delete ${g.slug}?`)) {
                          return;
                        }
                        setBusy(true);
                        try {
                          await deleteGameBySlug(g.slug);
                          await reload();
                          flash('Deleted.');
                        } catch (e) {
                          console.error(e);
                          flash('Delete failed');
                        } finally {
                          setBusy(false);
                        }
                      }}
                    >
                      Delete
                    </button>
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {tab === 'pages' && (
        <div className="admin-grid">
          {/* ---- Pages vs Nav explainer ----------------------------------
              A frequent source of confusion: "Pages" and "Nav" both put
              buttons in the top bar. The crucial difference is **where the
              content lives** — a Page owns content + URL + (optional) nav
              link; a Nav item is just a link, pointing wherever you want.
          ---------------------------------------------------------------- */}
          <div
            className="admin-panel"
            style={{
              borderStyle: 'dashed',
              borderColor: 'rgba(115, 248, 255, 0.45)',
              background: 'rgba(115, 248, 255, 0.04)',
            }}
          >
            <strong style={{ display: 'block', marginBottom: 6, fontSize: '0.85rem', color: 'var(--accent)' }}>
              Pages vs Nav — what goes where?
            </strong>
            <ul className="admin-muted" style={{ paddingLeft: 18, lineHeight: 1.6, fontSize: '0.85rem', margin: 0 }}>
              <li>
                <strong>Page</strong> = a route at <code>/#/p/&lt;slug&gt;</code>. Use <strong>Block composer</strong> for
                headings, panels, and images, or <strong>HTML app</strong> to paste a full exported document (Gemini / Claude)
                into a sandboxed iframe. Toggle <em>Show in top nav</em> for a header button; turn on <em>Unlisted</em> to ask
                search engines not to index (the URL still works for anyone who has it).
              </li>
              <li>
                <strong>Nav</strong> = ONLY a top-bar button. Pick anywhere it points: a CMS page, a game,
                an external URL (Discord, itch, press kit), or even a section anchor. Use this when you
                want a header link to something you didn't author as a page (or want a second link to a
                page using a different label).
              </li>
              <li>
                Rule of thumb: <em>create a Page</em> if you're writing content;{' '}
                <em>create a Nav item</em> if you only need a link.
              </li>
            </ul>
          </div>
          <div className="admin-panel admin-grid">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Custom page editor
            </h2>
            <div className="admin-row" style={{ gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
              <button
                type="button"
                onClick={() => {
                  const draft = hireUsPageDraft();
                  setPageDraft({
                    ...emptyPageDraft(),
                    ...draft,
                    sections: ensureSectionIds(draft.sections),
                  });
                  setPageFieldErrors({});
                  flash('Hire Us template loaded — edit and Save page.');
                }}
              >
                New: Hire Us page
              </button>
              <span className="admin-muted" style={{ fontSize: '0.82rem' }}>
                Creates <code>/#/p/hire-us</code> with hero + CTA blocks.
              </span>
            </div>
            <p className="admin-muted">
              Public URL: <code>/#/p/&lt;slug&gt;</code>. Pick <strong>Block composer</strong> for structured content, or{' '}
              <strong>HTML app</strong> for a single-file export. Turn off <strong>Show in top nav</strong> for a vault-style
              link-only page. Use <strong>Unlisted</strong> for <code>noindex</code> (does not password-protect). HTML apps can
              appear on <Link to="/apps">/apps</Link> when enabled below. Central hub: Behavior → show “Apps lab” link.
            </p>
            <div className="admin-field">
              <label htmlFor="p_slug">Slug</label>
              <input
                id="p_slug"
                value={pageDraft.slug}
                onChange={(e) => {
                  clearPageFieldError('slug');
                  setPageDraft({ ...pageDraft, slug: e.target.value });
                }}
              />
              {pageFieldErrors.slug ? (
                <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
                  <span aria-hidden>✗ </span>
                  {pageFieldErrors.slug}
                </p>
              ) : null}
            </div>
            <div className="admin-field">
              <label htmlFor="p_title">Title</label>
              <input
                id="p_title"
                value={pageDraft.title}
                onChange={(e) => {
                  clearPageFieldError('title');
                  setPageDraft({ ...pageDraft, title: e.target.value });
                }}
              />
              {pageFieldErrors.title ? (
                <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
                  <span aria-hidden>✗ </span>
                  {pageFieldErrors.title}
                </p>
              ) : null}
            </div>
            {pageDraft.slug.trim() ? (
              <div
                className="admin-panel"
                style={{ borderStyle: 'dashed', padding: '12px 14px', fontSize: '0.82rem', lineHeight: 1.55 }}
              >
                <strong style={{ display: 'block', marginBottom: 8 }}>Public link</strong>
                <div className="admin-row" style={{ flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
                  <code>/#/p/{pageDraft.slug.trim()}</code>
                  <button
                    type="button"
                    onClick={() => {
                      if (copyPublicHashUrl(`/p/${pageDraft.slug.trim()}`)) {
                        flash('Copied page URL.');
                      }
                    }}
                  >
                    Copy
                  </button>
                </div>
              </div>
            ) : null}
            <div className="admin-field">
              <label htmlFor="p_page_mode">Page type</label>
              <select
                id="p_page_mode"
                value={pageDraft.page_mode === 'html_app' ? 'html_app' : 'blocks'}
                onChange={(e) => {
                  const v = e.target.value === 'html_app' ? 'html_app' : 'blocks';
                  setPageDraft({ ...pageDraft, page_mode: v });
                }}
              >
                <option value="blocks">Block composer</option>
                <option value="html_app">HTML app (sandboxed iframe)</option>
              </select>
              <p className="admin-muted" style={{ margin: '8px 0 0', fontSize: '0.8rem', lineHeight: 1.45 }}>
                HTML apps are <strong>admin-trusted</strong> code running inside an iframe. Use strict mode by default; enable
                compat only if a script needs same-origin storage.
              </p>
            </div>
            <RouteAppearancePanel
              kind="page"
              value={pageDraft}
              onChange={(patch) => setPageDraft({ ...pageDraft, ...patch })}
              customCssError={pageFieldErrors.custom_mood_css}
              onClearCustomCssError={() => clearPageFieldError('custom_mood_css')}
              onOpenEffectsTab={() => setTab('effects')}
            />
            {pageDraft.page_mode === 'html_app' ? (
              <>
                <div className="admin-field">
                  <label htmlFor="p_raw_html">Full HTML document</label>
                  <p className="admin-html-paste-hint">
                    Paste an entire single-file export (1,000+ lines is fine) or use <strong>Load from file</strong>.
                    Save the page, then visit <code>/p/your-slug</code>. For Gemini-built apps, enable{' '}
                    <strong>Compat sandbox</strong> below if scripts or fetch calls fail. Do not embed production API
                    keys; anyone with the page URL can read them.
                  </p>
                  <textarea
                    id="p_raw_html"
                    className="admin-textarea--html"
                    rows={24}
                    value={pageDraft.raw_html ?? ''}
                    onChange={(e) => {
                      clearPageFieldError('raw_html');
                      setPageDraft({ ...pageDraft, raw_html: e.target.value });
                    }}
                    placeholder="<!DOCTYPE html>…"
                    spellCheck={false}
                  />
                  <p className="admin-html-paste-stats" aria-live="polite">
                    {(() => {
                      const { chars, lines } = htmlPasteStats(pageDraft.raw_html);
                      return chars > 0
                        ? `${lines.toLocaleString()} lines · ${chars.toLocaleString()} characters`
                        : 'No HTML pasted yet';
                    })()}
                  </p>
                  {pageFieldErrors.raw_html ? (
                    <p style={{ color: 'var(--danger)', fontSize: '0.82rem', marginTop: 8 }} role="alert">
                      <span aria-hidden>✗ </span>
                      {pageFieldErrors.raw_html}
                    </p>
                  ) : null}
                </div>
                <div className="admin-field">
                  <label htmlFor="p_html_file">Load from file</label>
                  <input
                    id="p_html_file"
                    type="file"
                    accept=".html,.htm,text/html"
                    disabled={busy}
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (!f) {
                        return;
                      }
                      const reader = new FileReader();
                      reader.onload = () => {
                        const text = typeof reader.result === 'string' ? reader.result : '';
                        clearPageFieldError('raw_html');
                        setPageDraft((prev) => ({ ...prev, raw_html: text }));
                        const stats = htmlPasteStats(text);
                        flash(
                          `Loaded ${f.name} (${stats.lines.toLocaleString()} lines, ${stats.chars.toLocaleString()} chars).`,
                        );
                      };
                      reader.onerror = () => flash('Could not read file.');
                      reader.readAsText(f);
                      e.target.value = '';
                    }}
                  />
                  <p className="admin-muted" style={{ margin: '8px 0 0', fontSize: '0.8rem' }}>
                    Replaces the textarea with the file contents. You can still edit after load.
                  </p>
                </div>
                <div className="admin-field">
                  <label htmlFor="p_html_app_summary">Short blurb (Apps hub card)</label>
                  <textarea
                    id="p_html_app_summary"
                    rows={3}
                    value={pageDraft.html_app_summary ?? ''}
                    onChange={(e) => setPageDraft({ ...pageDraft, html_app_summary: e.target.value })}
                    placeholder="One line for the /apps grid…"
                  />
                </div>
                <label className="admin-row" style={{ gap: 8 }}>
                  <input
                    type="checkbox"
                    checked={pageDraft.show_on_apps_hub !== false}
                    onChange={(e) => setPageDraft({ ...pageDraft, show_on_apps_hub: e.target.checked })}
                  />
                  Show on <Link to="/apps">/apps</Link> hub
                </label>
                <label className="admin-row" style={{ gap: 8 }}>
                  <input
                    type="checkbox"
                    checked={Boolean(pageDraft.html_iframe_compat)}
                    onChange={(e) => setPageDraft({ ...pageDraft, html_iframe_compat: e.target.checked })}
                  />
                  Compat sandbox (allow-same-origin) — weaker; only for HTML you fully trust
                </label>
              </>
            ) : (
              <>
                <h3 style={{ fontSize: '0.85rem', textTransform: 'uppercase', color: 'var(--muted)', marginTop: 8 }}>
                  Page blocks
                </h3>
                <p className="admin-muted" style={{ marginTop: 0, fontSize: '0.85rem', lineHeight: 1.5 }}>
                  Add <strong>Buttons</strong>, <strong>CTA</strong>, or <strong>Hero</strong> blocks for in-page actions — they
                  render inside this page, not in the global top nav. Global nav placement (top vs footer) is under{' '}
                  <strong>Behavior → Site chrome</strong>.
                </p>
                <PageSectionsForm
                  sections={pageDraft.sections ?? []}
                  onChange={(sections) => setPageDraft({ ...pageDraft, sections })}
                  pageSlug={pageDraft.slug}
                  formDisabled={busy}
                  onNotify={flash}
                />
                <div className="admin-field">
                  <label htmlFor="p_body">Legacy body (only if no blocks above)</label>
                  <textarea
                    id="p_body"
                    value={pageDraft.body ?? ''}
                    onChange={(e) => setPageDraft({ ...pageDraft, body: e.target.value })}
                  />
                </div>
              </>
            )}
            <div className="admin-field">
              <label htmlFor="p_order">Nav sort order</label>
              <input
                id="p_order"
                type="number"
                value={pageDraft.sort_order ?? 0}
                onChange={(e) => setPageDraft({ ...pageDraft, sort_order: Number(e.target.value) })}
              />
            </div>
            <label className="admin-row" style={{ gap: 8 }}>
              <input
                type="checkbox"
                checked={pageDraft.published !== false}
                onChange={(e) => setPageDraft({ ...pageDraft, published: e.target.checked })}
              />
              Published — visitors can open this page (off = draft; only signed-in admins preview)
            </label>
            <label className="admin-row" style={{ gap: 8 }}>
              <input
                type="checkbox"
                checked={pageDraft.show_in_nav ?? true}
                onChange={(e) => setPageDraft({ ...pageDraft, show_in_nav: e.target.checked })}
              />
              Show in top navigation (off = link-only; no auto nav button)
            </label>
            <label className="admin-row" style={{ gap: 8 }}>
              <input
                type="checkbox"
                checked={Boolean(pageDraft.unlisted)}
                onChange={(e) => setPageDraft({ ...pageDraft, unlisted: e.target.checked })}
              />
              Unlisted — add noindex,nofollow (URL still public; not a password)
            </label>
            <label className="admin-row" style={{ gap: 8 }}>
              <input
                type="checkbox"
                checked={pageDraft.comments_enabled === true}
                onChange={(e) => setPageDraft({ ...pageDraft, comments_enabled: e.target.checked })}
              />
              Allow comments (off = hide the comment thread — good for policy / legal pages)
            </label>
            <div className="admin-row" style={{ alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
              <button type="button" disabled={busy} onClick={onSavePage}>
                Save page
              </button>
              {pageSaveStatus === 'success' ? (
                <span
                  style={{ color: '#3ecf8e', fontSize: '1.35rem', lineHeight: 1 }}
                  title="Saved"
                  aria-label="Page saved successfully"
                >
                  ✓
                </span>
              ) : null}
              {pageSaveStatus === 'error' ? (
                <span
                  style={{ color: 'var(--danger)', fontSize: '1.35rem', lineHeight: 1 }}
                  title="Save failed"
                  aria-label="Page save failed"
                >
                  ✗
                </span>
              ) : null}
            </div>
            {pageSaveSummary ? (
              <p className="admin-muted" style={{ marginTop: 10, fontSize: '0.86rem', lineHeight: 1.5 }}>
                {pageSaveSummary}
              </p>
            ) : null}
            {pageSaveDetail ? (
              <p style={{ marginTop: 10, fontSize: '0.86rem', lineHeight: 1.5, color: 'var(--danger)' }} role="alert">
                {pageSaveDetail}
              </p>
            ) : null}
          </div>
          <div className="admin-panel">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Pages
            </h2>
            <ul style={{ listStyle: 'none', marginTop: 12 }}>
              {pages.map((p) => (
                <li key={p.slug} className="admin-row" style={{ justifyContent: 'space-between' }}>
                  <span>
                    <strong>{p.title}</strong>{' '}
                    <span className="admin-muted">
                      /p/{p.slug}
                      {p.page_mode === 'html_app' ? ' · HTML app' : ''}
                      {p.published === false ? ' · draft' : ''}
                      {p.show_in_nav ? ' · in nav' : ' · link-only'}
                      {p.unlisted ? ' · unlisted' : ''}
                      {p.visual_preset ? ` · ${p.visual_preset}` : ''}
                      {p.immersive_layout ? ' · immersive' : ''}
                    </span>
                  </span>
                  <span className="admin-row">
                    <button
                      type="button"
                      title="Copy link"
                      onClick={() => {
                        if (copyPublicHashUrl(`/p/${p.slug}`)) {
                          flash('Copied page URL.');
                        }
                      }}
                    >
                      Copy URL
                    </button>
                    <button
                      type="button"
                      onClick={() => setPageDraft(sitePageToDraft(p))}
                    >
                      Edit
                    </button>
                    <Link to={`/p/${p.slug}`}>View</Link>
                    <button
                      type="button"
                      onClick={async () => {
                        if (!confirm(`Delete page ${p.slug}?`)) {
                          return;
                        }
                        setBusy(true);
                        try {
                          await deletePageSlug(p.slug);
                          await reload();
                          flash('Deleted.');
                        } catch (e) {
                          console.error(e);
                          flash('Delete failed');
                        } finally {
                          setBusy(false);
                        }
                      }}
                    >
                      Delete
                    </button>
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {tab === 'nav' && (
        <div className="admin-grid">
          {/* See the matching note in the Pages tab — keep both panels in sync. */}
          <div
            className="admin-panel"
            style={{
              borderStyle: 'dashed',
              borderColor: 'rgba(166, 115, 255, 0.45)',
              background: 'rgba(166, 115, 255, 0.04)',
            }}
          >
            <strong style={{ display: 'block', marginBottom: 6, fontSize: '0.85rem', color: 'var(--accent-2)' }}>
              Nav vs Pages — am I in the right place?
            </strong>
            <ul className="admin-muted" style={{ paddingLeft: 18, lineHeight: 1.6, fontSize: '0.85rem', margin: 0 }}>
              <li>
                Use a <strong>Nav</strong> item when you just need a button in the top bar. It only stores
                the label + URL — no content. Perfect for external links (Discord, itch, press kit), section
                anchors, or duplicate links to existing pages with a different label.
              </li>
              <li>
                Use a <strong>Page</strong> (in the <em>Pages</em> tab) when you're writing actual content. A
                Page can <em>also</em> auto-generate a nav button (toggle “Show in top nav”). Hide that
                toggle to make a “secret page” at <code>/p/&lt;slug&gt;</code> shared only by URL.
              </li>
              <li>
                The header always starts with the built-in Home / Vault / Dev log links (each can be hidden
                from the <strong>Behavior</strong> studio), then every nav-on Page, then every Nav item from
                this tab.
              </li>
            </ul>
          </div>
          <div className="admin-panel admin-grid">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Navigation (top bar)
            </h2>
            <p className="admin-muted" style={{ lineHeight: 1.55 }}>
              The site header always includes <strong>Home</strong>, <strong>Vault</strong>, and <strong>Dev log</strong>, plus
              any CMS pages you marked “show in nav”. <strong>This tab</strong> adds <em>extra</em> buttons (partners, Discord,
              press kit, etc.). Use internal paths like <code>/p/about</code> or <code>/vault</code> (no <code>#</code>), or
              full <code>https://</code> URLs with <em>External link</em> checked.
            </p>
            <div className="admin-field">
              <label htmlFor="n_label">Label</label>
              <input
                id="n_label"
                value={navDraft.label}
                onChange={(e) => {
                  setNavSaveDetail(null);
                  setNavDraft({ ...navDraft, label: e.target.value });
                }}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="n_href">Href</label>
              <input
                id="n_href"
                value={navDraft.href}
                onChange={(e) => {
                  setNavSaveDetail(null);
                  setNavDraft({ ...navDraft, href: e.target.value });
                }}
              />
              <HrefQuickPick
                pages={pages.map((p) => ({ slug: p.slug, title: p.title }))}
                games={games.map((g) => ({ slug: g.slug, title: g.title }))}
                disabled={busy}
                onPick={(href) => setNavDraft({ ...navDraft, href })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="n_order">Sort order</label>
              <input
                id="n_order"
                type="number"
                value={navDraft.sort_order ?? 0}
                onChange={(e) => setNavDraft({ ...navDraft, sort_order: Number(e.target.value) })}
              />
            </div>
            <label className="admin-row" style={{ gap: 8 }}>
              <input
                type="checkbox"
                checked={navDraft.external ?? false}
                onChange={(e) => setNavDraft({ ...navDraft, external: e.target.checked })}
              />
              External link
            </label>
            <div className="admin-row" style={{ alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
              <button type="button" disabled={busy} onClick={onSaveNav}>
                Save link
              </button>
              {navSaveStatus === 'success' ? (
                <span style={{ color: '#3ecf8e', fontSize: '1.35rem', lineHeight: 1 }} title="Saved" aria-label="Saved">
                  ✓
                </span>
              ) : null}
              {navSaveStatus === 'error' ? (
                <span
                  style={{ color: 'var(--danger)', fontSize: '1.35rem', lineHeight: 1 }}
                  title="Error"
                  aria-label="Error"
                >
                  ✗
                </span>
              ) : null}
            </div>
            {navSaveDetail ? (
              <p
                style={{
                  marginTop: 10,
                  fontSize: '0.86rem',
                  lineHeight: 1.45,
                  color: navSaveStatus === 'error' ? 'var(--danger)' : 'var(--muted)',
                }}
                role={navSaveStatus === 'error' ? 'alert' : undefined}
              >
                {navSaveDetail}
              </p>
            ) : null}
          </div>
          <div className="admin-panel">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Links
            </h2>
            <ul style={{ listStyle: 'none', marginTop: 12 }}>
              {nav.map((n) => (
                <li key={n.id} className="admin-row" style={{ justifyContent: 'space-between' }}>
                  <span>
                    <strong>{n.label}</strong>{' '}
                    <span className="admin-muted">
                      {n.href} {n.external ? '· external' : ''}
                    </span>
                  </span>
                  <span className="admin-row">
                    <button type="button" onClick={() => setNavDraft({ ...n })}>
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={async () => {
                        if (!confirm('Delete this link?')) {
                          return;
                        }
                        setBusy(true);
                        try {
                          await deleteNavId(n.id);
                          await reload();
                          flash('Deleted.');
                        } catch (e) {
                          console.error(e);
                          flash('Delete failed');
                        } finally {
                          setBusy(false);
                        }
                      }}
                    >
                      Delete
                    </button>
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {tab === 'devlogs' && (
        <div className="admin-grid">
          <div className="admin-panel admin-grid">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Dev log post
            </h2>
            <div className="admin-field">
              <label htmlFor="l_slug">Slug</label>
              <input
                id="l_slug"
                value={logDraft.slug}
                onChange={(e) => setLogDraft({ ...logDraft, slug: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="l_title">Title</label>
              <input
                id="l_title"
                value={logDraft.title}
                onChange={(e) => setLogDraft({ ...logDraft, title: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="l_body">Body (plain-text fallback)</label>
              <textarea
                id="l_body"
                value={logDraft.body ?? ''}
                onChange={(e) => setLogDraft({ ...logDraft, body: e.target.value })}
              />
              <p className="admin-muted" style={{ fontSize: '0.78rem', marginTop: 6 }}>
                Shown only when there are no blocks below. Add blocks for rich posts (images, galleries, embeds…).
              </p>
            </div>
            <div className="admin-field">
              <label>Post blocks</label>
              <PageSectionsForm
                sections={logDraft.sections ?? []}
                onChange={(sections) => setLogDraft({ ...logDraft, sections })}
                pageSlug={logDraft.slug?.trim() ? `devlog-${logDraft.slug.trim()}` : 'devlog-draft'}
                mediaStorageFolder="devlog"
                onNotify={flash}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="l_at">Published at</label>
              <input
                id="l_at"
                type="datetime-local"
                value={logDraft.published_at ?? ''}
                onChange={(e) => setLogDraft({ ...logDraft, published_at: e.target.value })}
              />
            </div>
            <div className="admin-row" style={{ alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
              <button type="button" disabled={busy} onClick={onSaveLog}>
                Save post
              </button>
              {logSaveStatus === 'success' ? (
                <span style={{ color: '#3ecf8e', fontSize: '1.35rem', lineHeight: 1 }} title="Saved" aria-label="Saved">
                  ✓
                </span>
              ) : null}
              {logSaveStatus === 'error' ? (
                <span
                  style={{ color: 'var(--danger)', fontSize: '1.35rem', lineHeight: 1 }}
                  title="Error"
                  aria-label="Error"
                >
                  ✗
                </span>
              ) : null}
            </div>
            {logSaveDetail ? (
              <p
                style={{
                  marginTop: 10,
                  fontSize: '0.86rem',
                  lineHeight: 1.45,
                  color: logSaveStatus === 'error' ? 'var(--danger)' : 'var(--muted)',
                }}
                role={logSaveStatus === 'error' ? 'alert' : undefined}
              >
                {logSaveDetail}
              </p>
            ) : null}
          </div>
          <div className="admin-panel">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Posts
            </h2>
            <ul style={{ listStyle: 'none', marginTop: 12 }}>
              {logs.map((p) => (
                <li key={p.slug} className="admin-row" style={{ justifyContent: 'space-between' }}>
                  <span>
                    <strong>{p.title}</strong>{' '}
                    <span className="admin-muted">/devlog/{p.slug}</span>
                  </span>
                  <span className="admin-row">
                    <button type="button" onClick={() => setLogDraft({ ...p, published_at: p.published_at.slice(0, 16) })}>
                      Edit
                    </button>
                    <Link to={`/devlog/${p.slug}`}>View</Link>
                    <button
                      type="button"
                      onClick={async () => {
                        if (!confirm(`Delete ${p.slug}?`)) {
                          return;
                        }
                        setBusy(true);
                        try {
                          await deleteDevLogSlug(p.slug);
                          await reload();
                          flash('Deleted.');
                        } catch (e) {
                          console.error(e);
                          flash('Delete failed');
                        } finally {
                          setBusy(false);
                        }
                      }}
                    >
                      Delete
                    </button>
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {/* =====================================================================
          STUDIO TABS — added in migration 016 (`supabase/migrations/016_…`).
          Each tab edits one slice of `SiteSettings` and `SiteThemeApply`
          repaints the page live as the admin types. Save persists the whole
          settings row, so the studio shares one save button with this panel.
          ===================================================================== */}
      {tab === 'analytics' && (
        <AnalyticsStudio daysBack={analyticsDaysBack} onDaysBackChange={setAnalyticsDaysBack} />
      )}

      {tab === 'mailing' && <MailingListStudio />}

      {(tab === 'theme' ||
        tab === 'effects' ||
        tab === 'typography' ||
        tab === 'layout' ||
        tab === 'components' ||
        tab === 'behavior' ||
        tab === 'seo' ||
        tab === 'brand' ||
        tab === 'social' ||
        tab === 'motion' ||
        tab === 'media' ||
        tab === 'system') && (
        <>
          {tab === 'theme' && (
            <ThemeStudio
              settings={settings}
              setSettings={setSettings}
              onSavePreset={(preset: ThemePreset) =>
                setSettings({
                  ...settings,
                  theme_presets: [...(settings.theme_presets ?? []), preset],
                })
              }
            />
          )}
          {tab === 'effects' && <EffectsStudio settings={settings} setSettings={setSettings} />}
          {tab === 'typography' && <TypographyStudio settings={settings} setSettings={setSettings} />}
          {tab === 'layout' && <LayoutStudio settings={settings} setSettings={setSettings} />}
          {tab === 'components' && <ComponentsStudio settings={settings} setSettings={setSettings} />}
          {tab === 'behavior' && <BehaviorStudio settings={settings} setSettings={setSettings} />}
          {tab === 'seo' && <SeoStudio settings={settings} setSettings={setSettings} />}
          {tab === 'brand' && <BrandHeroStudio settings={settings} setSettings={setSettings} />}
          {tab === 'social' && <SocialStudio settings={settings} setSettings={setSettings} />}
          {tab === 'motion' && <MotionStudio settings={settings} setSettings={setSettings} />}
          {tab === 'media' && <MediaStudio settings={settings} setSettings={setSettings} />}
          {tab === 'system' && <SystemStudio settings={settings} setSettings={setSettings} />}
          {/* Shared save bar — sticky at the bottom of the studio shell. */}
          <div
            className="admin-panel"
            style={{
              marginTop: 16,
              borderColor: 'rgba(115, 248, 255, 0.45)',
              background: 'rgba(11, 16, 25, 0.95)',
            }}
          >
            <div className="admin-row" style={{ alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
              <button type="button" disabled={busy || !settingsDirty} onClick={onSaveSettings}>
                {busy ? 'Saving…' : settingsDirty ? 'Save studio settings' : 'Saved'}
              </button>
              {settingsSaveStatus === 'success' && !settingsDirty ? (
                <span style={{ color: '#3ecf8e', fontSize: '1.35rem', lineHeight: 1 }} aria-label="Saved">
                  ✓ Saved
                </span>
              ) : null}
              {settingsSaveStatus === 'error' ? (
                <span style={{ color: 'var(--danger)', fontSize: '1.0rem', lineHeight: 1 }} role="alert">
                  ✗ {settingsSaveDetail ?? 'Save failed.'}
                </span>
              ) : null}
              <span className="admin-muted" style={{ fontSize: '0.78rem', lineHeight: 1.4 }}>
                Floating Save bar at the bottom is always active when you have unsaved changes.
              </span>
            </div>
          </div>
        </>
      )}

      <FloatingSettingsSaveBar
        visible={showFloatingSettingsSave}
        busy={busy}
        dirty={settingsDirty}
        status={settingsSaveStatus}
        detail={settingsSaveDetail}
        onSave={onSaveSettings}
        onDiscard={onDiscardSettings}
      />
    </div>
  );
}

import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  deleteDevLogSlug,
  deleteGameBySlug,
  deleteNavId,
  deletePageSlug,
  fetchAllDevLogsAdmin,
  fetchAllGamesAdmin,
  fetchAllNavAdmin,
  fetchAllPagesAdmin,
  fetchSiteSettings,
  saveSiteSettings,
  upsertDevLog,
  upsertGame,
  upsertNav,
  upsertPage,
} from '../lib/cmsData';
import { getAuthRedirectBaseUrl } from '../lib/authRedirect';
import { supabaseConfigured } from '../lib/supabase';
import {
  anonKeyLooksValid,
  describeAnonKeyShape,
  getBuildTimeAnonKey,
  getBuildTimeSupabaseUrl,
  getRawBuildTimeSupabaseUrl,
  supabaseUrlLooksValid,
} from '../lib/supabaseHealth';
import { PageSectionsForm, ensureSectionIds } from '../components/admin/PageSectionsForm';
import {
  deleteGameBuild,
  sanitizeGameStorageSlug,
  uploadGameZip,
} from '../lib/gameStorageUpload';
import type { DevLogPost, GameRecord, NavItem, PageSection, SitePage, SiteSettings } from '../types';
import { defaultSiteSettings } from '../types';

type Tab = 'overview' | 'settings' | 'games' | 'pages' | 'nav' | 'devlogs';

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
  };
}

const emptyGame = (): Partial<GameRecord> & { slug: string; title: string } => ({
  slug: '',
  title: '',
  type: 'game',
  description: '',
  details: '',
  thumbnail_url: '',
  external_url: '',
  local_folder: '',
  storage_slug: null,
  sort_order: 0,
  published: true,
});

export function AdminPage() {
  const auth = useAuth();
  const [tab, setTab] = useState<Tab>('overview');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  const [settings, setSettings] = useState<SiteSettings>(defaultSiteSettings);
  const [games, setGames] = useState<GameRecord[]>([]);
  const [pages, setPages] = useState<SitePage[]>([]);
  const [nav, setNav] = useState<NavItem[]>([]);
  const [logs, setLogs] = useState<DevLogPost[]>([]);

  const [gameDraft, setGameDraft] = useState(emptyGame());
  const [pageDraft, setPageDraft] = useState(emptyPageDraft());
  const [emailForOtp, setEmailForOtp] = useState('');
  const [otpMessage, setOtpMessage] = useState<string | null>(null);
  const [googleError, setGoogleError] = useState<string | null>(null);
  const [gameZipFile, setGameZipFile] = useState<File | null>(null);
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
  });

  const reload = useCallback(async () => {
    if (!supabaseConfigured || !auth.isAdmin) {
      return;
    }
    const [s, g, p, n, l] = await Promise.all([
      fetchSiteSettings(),
      fetchAllGamesAdmin(),
      fetchAllPagesAdmin(),
      fetchAllNavAdmin(),
      fetchAllDevLogsAdmin(),
    ]);
    setSettings(s);
    setGames(g);
    setPages(p);
    setNav(n);
    setLogs(l);
  }, [auth.isAdmin]);

  useEffect(() => {
    reload().catch(console.error);
  }, [reload]);

  const flash = (msg: string) => {
    setMessage(msg);
    setTimeout(() => setMessage(null), 3500);
  };

  const onSaveSettings = async () => {
    setBusy(true);
    try {
      await saveSiteSettings(settings);
      flash('Site settings saved.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setBusy(false);
    }
  };

  const onSaveGame = async () => {
    if (!gameDraft.slug.trim() || !gameDraft.title.trim()) {
      flash('Slug and title are required.');
      return;
    }
    setBusy(true);
    try {
      await upsertGame({
        slug: gameDraft.slug.trim(),
        title: gameDraft.title.trim(),
        type: gameDraft.type ?? 'game',
        description: gameDraft.description ?? '',
        details: gameDraft.details ?? '',
        thumbnail_url: gameDraft.thumbnail_url ?? '',
        external_url: gameDraft.external_url ?? '',
        local_folder: gameDraft.local_folder?.trim() || gameDraft.slug.trim(),
        storage_slug: gameDraft.storage_slug ?? null,
        sort_order: Number(gameDraft.sort_order ?? 0),
        published: gameDraft.published ?? true,
      });
      setGameDraft(emptyGame());
      await reload();
      flash('Game saved.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setBusy(false);
    }
  };

  const onUploadGameZip = async () => {
    if (!gameDraft.slug.trim() || !gameDraft.title.trim()) {
      flash('Fill slug and title before uploading a ZIP.');
      return;
    }
    if (!gameZipFile) {
      flash('Choose a .zip file (Godot Web export folder).');
      return;
    }
    const storageKey = sanitizeGameStorageSlug(gameDraft.slug);
    if (!storageKey) {
      flash('Slug must include letters or numbers for cloud hosting.');
      return;
    }
    setBusy(true);
    try {
      const count = await uploadGameZip(gameDraft.slug, gameZipFile);
      await upsertGame({
        slug: gameDraft.slug.trim(),
        title: gameDraft.title.trim(),
        type: gameDraft.type ?? 'game',
        description: gameDraft.description ?? '',
        details: gameDraft.details ?? '',
        thumbnail_url: gameDraft.thumbnail_url ?? '',
        external_url: gameDraft.external_url ?? '',
        local_folder: gameDraft.local_folder?.trim() || gameDraft.slug.trim(),
        storage_slug: storageKey,
        sort_order: Number(gameDraft.sort_order ?? 0),
        published: gameDraft.published ?? true,
      });
      setGameDraft((prev) => ({ ...prev, storage_slug: storageKey }));
      setGameZipFile(null);
      await reload();
      flash(`Uploaded ${count} files to cloud storage. Play opens your index.html like itch.io.`);
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'ZIP upload failed');
    } finally {
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
        slug: gameDraft.slug.trim(),
        title: gameDraft.title.trim(),
        type: gameDraft.type ?? 'game',
        description: gameDraft.description ?? '',
        details: gameDraft.details ?? '',
        thumbnail_url: gameDraft.thumbnail_url ?? '',
        external_url: gameDraft.external_url ?? '',
        local_folder: gameDraft.local_folder?.trim() || gameDraft.slug.trim(),
        storage_slug: null,
        sort_order: Number(gameDraft.sort_order ?? 0),
        published: gameDraft.published ?? true,
      });
      setGameDraft((prev) => ({ ...prev, storage_slug: null }));
      await reload();
      flash('Cloud build removed.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Could not remove cloud build');
    } finally {
      setBusy(false);
    }
  };

  const onSavePage = async () => {
    if (!pageDraft.slug.trim() || !pageDraft.title.trim()) {
      flash('Page slug and title required.');
      return;
    }
    const slugSaved = pageDraft.slug.trim();
    setBusy(true);
    try {
      await upsertPage({
        slug: slugSaved,
        title: pageDraft.title.trim(),
        body: pageDraft.body ?? '',
        sections: ensureSectionIds(pageDraft.sections ?? []),
        show_in_nav: pageDraft.show_in_nav ?? true,
        sort_order: Number(pageDraft.sort_order ?? 0),
      });
      setPageDraft(emptyPageDraft());
      await reload();
      flash(`Page saved. Public URL: /p/${slugSaved}`);
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setBusy(false);
    }
  };

  const onSaveNav = async () => {
    if (!navDraft.label.trim() || !navDraft.href.trim()) {
      flash('Nav label and href required.');
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
      flash('Navigation link saved.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setBusy(false);
    }
  };

  const onSaveLog = async () => {
    if (!logDraft.slug.trim() || !logDraft.title.trim()) {
      flash('Log slug and title required.');
      return;
    }
    setBusy(true);
    try {
      const iso = logDraft.published_at
        ? new Date(logDraft.published_at).toISOString()
        : new Date().toISOString();
      await upsertDevLog({
        slug: logDraft.slug.trim(),
        title: logDraft.title.trim(),
        body: logDraft.body ?? '',
        published_at: iso,
      });
      setLogDraft({
        slug: '',
        title: '',
        body: '',
        published_at: new Date().toISOString().slice(0, 16),
      });
      await reload();
      flash('Dev log saved.');
    } catch (e) {
      console.error(e);
      flash(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setBusy(false);
    }
  };

  if (!supabaseConfigured) {
    const diagUrlRaw = getRawBuildTimeSupabaseUrl();
    const diagUrl = getBuildTimeSupabaseUrl();
    const diagKey = getBuildTimeAnonKey();
    const diagUrlCheck = supabaseUrlLooksValid(diagUrlRaw);
    const diagKeyCheck = anonKeyLooksValid(diagKey);
    return (
      <div className="admin-shell">
        <div className="admin-panel">
          <h1 className="header-title" style={{ fontSize: '1.8rem' }}>
            Admin
          </h1>
          <p className="admin-muted" style={{ marginTop: 12 }}>
            This exact JavaScript bundle was built <strong>without</strong> usable Supabase env vars, so admin is
            off. Your secrets can be correct in GitHub and you can still see this until a <strong>new</strong> deploy
            finishes that picked them up — or the values failed validation (wrong paste).
          </p>
          <div
            className="admin-panel"
            style={{ marginTop: 16, borderColor: 'rgba(255, 180, 100, 0.45)', background: 'rgba(255, 180, 100, 0.06)' }}
          >
            <p className="admin-muted" style={{ margin: 0, fontWeight: 700 }}>
              What this build actually contains (no secret text shown)
            </p>
            <ul className="admin-muted" style={{ marginTop: 10, marginBottom: 0, paddingLeft: 20, lineHeight: 1.6 }}>
              <li>
                <code>VITE_SUPABASE_URL</code> length in build: <strong>{diagUrlRaw.length}</strong>
                {diagUrlRaw !== diagUrl ? (
                  <>
                    {' '}
                    (client uses <strong>{diagUrl.length}</strong> chars — extra path after{' '}
                    <code>.supabase.co</code> is ignored)
                  </>
                ) : null}{' '}
                — if 0, Actions did not inject it (wrong repo, <strong>Variables</strong> instead of{' '}
                <strong>Secrets</strong>, typo in name <code>VITE_SUPABASE_URL</code>, or deploy never re-ran).
              </li>
              <li>
                <code>VITE_SUPABASE_ANON_KEY</code> length: <strong>{diagKey.length}</strong> — if 0, same as above.
                If &gt; 0 but still here, key may be truncated or wrong type (must be the long <strong>anon public</strong>{' '}
                JWT, usually 200+ characters).
              </li>
              {!diagUrlCheck.ok ? (
                <li style={{ color: 'var(--accent)' }}>URL check: {diagUrlCheck.message}</li>
              ) : null}
              {!diagKeyCheck.ok ? (
                <li style={{ color: 'var(--accent)' }}>Key check: {diagKeyCheck.message}</li>
              ) : null}
            </ul>
            <p className="admin-muted" style={{ marginTop: 12, marginBottom: 0, fontSize: '0.85rem' }}>
              <strong>If you already fixed GitHub secrets but lengths here never change:</strong> this page is still an{' '}
              <strong>old build</strong>. Open <strong>Actions</strong> → <strong>Deploy to GitHub Pages</strong> → pick a
              run <em>after</em> you saved secrets → expand <strong>Check Supabase secrets</strong> and compare{' '}
              <code>CI … length</code> lines to the numbers above. They must match. If CI shows a long anon key (~180+) but
              this page still shows ~41, you are on the wrong site, wrong repo, or a cached bundle — try incognito / another
              network. Use <strong>Run workflow</strong> (manual dispatch) on the branch you use for deploy, then wait for
              the green checkmark and hard-refresh.
            </p>
            <p className="admin-muted" style={{ marginTop: 10, marginBottom: 0, fontSize: '0.85rem' }}>
              Also confirm <strong>Settings → Pages</strong> shows a deployment from <strong>Actions</strong> that matches
              that run (not an old “Deploy from branch” upload).
            </p>
          </div>
          <p className="admin-muted" style={{ marginTop: 16 }}>
            <strong>Fix:</strong> Settings → <strong>Secrets and variables</strong> → <strong>Actions</strong> → tab{' '}
            <strong>Secrets</strong> → names exactly <code>VITE_SUPABASE_URL</code> and{' '}
            <code>VITE_SUPABASE_ANON_KEY</code> → <strong>Actions</strong> → re-run deploy. See{' '}
            <code>docs/GITHUB_ACTIONS_SUPABASE_SECRETS.md</code> and <code>docs/SUPABASE_COPY_THESE_TWO_VALUES.md</code>.
          </p>
          <p className="admin-muted" style={{ marginTop: 12 }}>
            <strong>Local only:</strong> <code>.env.local</code> next to <code>package.json</code>, same two variable
            names, <code>npm run dev</code>, <code>http://localhost:5173/#/admin</code>.
          </p>
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
    const builtUrl = getBuildTimeSupabaseUrl();
    const builtKey = getBuildTimeAnonKey();
    const urlCheck = supabaseUrlLooksValid(builtUrl);
    const keyCheck = anonKeyLooksValid(builtKey);
    const redirectExact = getAuthRedirectBaseUrl();
    return (
      <div className="admin-shell">
        <div className="admin-panel">
          <h1 className="header-title" style={{ fontSize: '1.8rem' }}>
            Log in to edit the site
          </h1>
          <p className="admin-muted" style={{ marginBottom: 16, lineHeight: 1.5 }}>
            <strong>Easiest:</strong> use <strong>Send login link</strong> below with an email that ends in{' '}
            <code>@criminallydevdads.com</code> (already allowed), or a personal address you added in Supabase SQL.
            You need <strong>Email</strong> turned on under Authentication → Providers. Full checklist:{' '}
            <code>docs/ADMIN_LOGIN_ONE_PAGE.md</code>.
          </p>
          <p className="admin-muted" style={{ marginBottom: 12, fontSize: '0.85rem' }}>
            Bookmark <strong>/#/admin</strong>. Optional: show “Team login” in the header with{' '}
            <code>VITE_SHOW_ADMIN_NAV=true</code> (<code>docs/SITE_MANUAL.md</code>).
          </p>
          {(!urlCheck.ok || !keyCheck.ok) && (
            <div className="admin-panel danger-zone" style={{ marginBottom: 16 }}>
              <p className="admin-muted" style={{ margin: 0, fontWeight: 700 }}>
                Supabase keys in this build look wrong (Google will 404 or auth will fail):
              </p>
              {!urlCheck.ok ? (
                <p className="admin-muted" style={{ marginTop: 8 }}>
                  <strong>Project URL:</strong> {urlCheck.message}
                </p>
              ) : (
                <p className="admin-muted" style={{ marginTop: 8 }}>
                  <strong>Project URL shape:</strong> OK — <code>{builtUrl}</code>
                </p>
              )}
              {!keyCheck.ok ? (
                <p className="admin-muted" style={{ marginTop: 8 }}>
                  <strong>Anon key:</strong> {keyCheck.message}
                </p>
              ) : (
                <p className="admin-muted" style={{ marginTop: 8 }}>
                  <strong>Anon key shape:</strong> OK — <code>{describeAnonKeyShape(builtKey)}</code>
                </p>
              )}
              <p className="admin-muted" style={{ marginTop: 12, marginBottom: 0 }}>
                Exact copy steps: <code>docs/SUPABASE_COPY_THESE_TWO_VALUES.md</code>
              </p>
            </div>
          )}
          {urlCheck.ok && keyCheck.ok ? (
            <div className="admin-panel" style={{ marginBottom: 16, borderColor: 'rgba(115, 248, 255, 0.35)' }}>
              <p className="admin-muted" style={{ margin: 0, fontWeight: 700 }}>
                If Google login shows 404, add this exact URL in Supabase:
              </p>
              <p style={{ marginTop: 8, marginBottom: 0 }}>
                <code style={{ wordBreak: 'break-all' }}>{redirectExact}</code>
              </p>
              <p className="admin-muted" style={{ marginTop: 10, marginBottom: 0, fontSize: '0.85rem' }}>
                Supabase dashboard → <strong>Authentication</strong> → <strong>URL Configuration</strong> →{' '}
                <strong>Redirect URLs</strong> → paste the line above. Set <strong>Site URL</strong> to the same.
                Google Cloud → OAuth client → Authorized redirect URI must be{' '}
                <code>{`${builtUrl.replace(/\/$/, '')}/auth/v1/callback`}</code>
              </p>
            </div>
          ) : null}
          <div className="admin-field" style={{ marginTop: 8 }}>
            <label htmlFor="otp_email">Your team email (magic link — try this first)</label>
            <input
              id="otp_email"
              type="email"
              autoComplete="email"
              placeholder="you@criminallydevdads.com"
              value={emailForOtp}
              onChange={(e) => setEmailForOtp(e.target.value)}
            />
          </div>
          <button
            type="button"
            disabled={busy || !emailForOtp.trim()}
            onClick={() => {
              setBusy(true);
              setOtpMessage(null);
              auth
                .signInWithEmail(emailForOtp)
                .then(() => setOtpMessage('Check your inbox — click the link, then open /#/admin again if needed.'))
                .catch((e) => setOtpMessage(e instanceof Error ? e.message : 'Could not send link'))
                .finally(() => setBusy(false));
            }}
          >
            Send login link
          </button>
          {otpMessage ? <p className="admin-muted" style={{ marginTop: 12 }}>{otpMessage}</p> : null}
          <p className="admin-muted" style={{ marginTop: 12, fontSize: '0.82rem', lineHeight: 1.5 }}>
            <strong>Link shows an error?</strong> Supabase → <strong>Authentication</strong> →{' '}
            <strong>URL Configuration</strong>: <strong>Site URL</strong> and <strong>Redirect URLs</strong> must
            include the green-box URL above (same https host, same path, trailing slash). Add <code>www</code> and
            non-<code>www</code> if needed. Open the email link in your real browser; if it still fails, set GitHub
            secret <code>VITE_AUTH_REDIRECT_URL</code> to that URL and redeploy — see{' '}
            <code>docs/ADMIN_LOGIN_ONE_PAGE.md</code>.
          </p>
          <p className="admin-muted" style={{ marginTop: 20, marginBottom: 8, fontSize: '0.85rem' }}>
            Optional: Google (extra setup — OAuth + redirect in Supabase). See{' '}
            <code>docs/SUPABASE_FIRST_TIME_SETUP.md</code>.
          </p>
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              setGoogleError(null);
              auth
                .signInWithGoogle()
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
            In Supabase → <strong>SQL Editor</strong>, run:{' '}
            <code>insert into site_admin_emails (email) values (&apos;your@email.com&apos;) on conflict do nothing;</code>
            — or add your domain to <code>site_admin_domains</code>. See <code>docs/ADMIN_LOGIN_ONE_PAGE.md</code>.
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
        {(['overview', 'settings', 'games', 'pages', 'nav', 'devlogs'] as Tab[]).map((t) => (
          <button key={t} type="button" className={tab === t ? 'active' : ''} onClick={() => setTab(t)}>
            {t === 'devlogs' ? 'dev logs' : t}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div
          className="admin-grid"
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
            gap: 16,
          }}
        >
          {(
            [
              ['settings', 'Site settings', 'Hero, footer, support block'],
              ['games', 'Games', 'ZIP uploads (itch-style), itch links, repo folders'],
              ['pages', 'Pages & panels', 'Custom URLs with headings, text, panels, images'],
              ['nav', 'Navigation', 'Extra header links'],
              ['devlogs', 'Dev logs', 'News and build notes'],
            ] as const
          ).map(([id, title, desc]) => (
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
      )}

      {tab === 'settings' && (
        <div className="admin-panel admin-grid">
          <div className="admin-field">
            <label htmlFor="hero_title">Hero title</label>
            <input
              id="hero_title"
              value={settings.hero_title}
              onChange={(e) => setSettings({ ...settings, hero_title: e.target.value })}
            />
          </div>
          <div className="admin-field">
            <label htmlFor="hero_subtitle">Hero subtitle</label>
            <input
              id="hero_subtitle"
              value={settings.hero_subtitle}
              onChange={(e) => setSettings({ ...settings, hero_subtitle: e.target.value })}
            />
          </div>
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
            <label htmlFor="footer_text">Footer</label>
            <textarea
              id="footer_text"
              value={settings.footer_text}
              onChange={(e) => setSettings({ ...settings, footer_text: e.target.value })}
            />
          </div>
          <button type="button" disabled={busy} onClick={onSaveSettings}>
            Save settings
          </button>
        </div>
      )}

      {tab === 'games' && (
        <div className="admin-grid">
          <div className="admin-panel admin-grid">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Add or update game
            </h2>
            <p className="admin-muted">
              <strong>ZIP upload:</strong> Export Web from Godot, zip the folder, upload below — files go to
              Supabase Storage (public <code>game-builds/</code>) like itch hosting.
              <strong> External URL</strong> overrides hosting if set (itch / CDN).
              <strong> Local folder</strong> is for copies in <code>games/&lt;slug&gt;/</code> on GitHub
              Pages only.
            </p>
            <div className="admin-field">
              <label htmlFor="g_slug">Slug (URL id)</label>
              <input
                id="g_slug"
                value={gameDraft.slug}
                onChange={(e) => setGameDraft({ ...gameDraft, slug: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="g_title">Title</label>
              <input
                id="g_title"
                value={gameDraft.title}
                onChange={(e) => setGameDraft({ ...gameDraft, title: e.target.value })}
              />
            </div>
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
            </div>
            <div className="admin-field">
              <label htmlFor="g_thumb">Thumbnail URL</label>
              <input
                id="g_thumb"
                value={gameDraft.thumbnail_url ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, thumbnail_url: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="g_ext">External play URL (optional)</label>
              <input
                id="g_ext"
                value={gameDraft.external_url ?? ''}
                onChange={(e) => setGameDraft({ ...gameDraft, external_url: e.target.value })}
              />
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
              <p className="admin-muted" style={{ margin: 0 }}>
                ZIP must contain <code>index.html</code> (and <code>.js</code> / <code>.wasm</code> /{' '}
                <code>.pck</code> next to it). Godot often zips one folder — we strip the wrapper automatically.
              </p>
              {gameDraft.storage_slug ? (
                <p className="admin-muted" style={{ margin: 0 }}>
                  Cloud folder: <code>{gameDraft.storage_slug}</code>
                </p>
              ) : null}
              <div className="admin-field">
                <label htmlFor="g_zip">Web export .zip</label>
                <input
                  id="g_zip"
                  type="file"
                  accept=".zip,application/zip"
                  disabled={busy || !gameDraft.slug.trim()}
                  onChange={(e) => setGameZipFile(e.target.files?.[0] ?? null)}
                />
              </div>
              <div className="admin-row" style={{ flexWrap: 'wrap', gap: 8 }}>
                <button type="button" disabled={busy || !gameZipFile || !gameDraft.slug.trim()} onClick={onUploadGameZip}>
                  Upload ZIP & save game
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
              Published (visible on hub)
            </label>
            <button type="button" disabled={busy} onClick={onSaveGame}>
              Save game
            </button>
          </div>

          <div className="admin-panel">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Existing games
            </h2>
            <ul style={{ listStyle: 'none', marginTop: 12 }}>
              {games.map((g) => (
                <li key={g.slug} className="admin-row" style={{ justifyContent: 'space-between' }}>
                  <span>
                    <strong>{g.title}</strong> <span className="admin-muted">({g.slug})</span>
                  </span>
                  <span className="admin-row">
                    <button type="button" onClick={() => setGameDraft({ ...g })}>
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
          <div className="admin-panel admin-grid">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Custom page (blocks)
            </h2>
            <p className="admin-muted">
              Public URL: <code>/#/p/&lt;slug&gt;</code>. Stack headings, text, panels, and images. If you add
              no blocks, the legacy <strong>Body</strong> field is shown instead.
            </p>
            <div className="admin-field">
              <label htmlFor="p_slug">Slug</label>
              <input
                id="p_slug"
                value={pageDraft.slug}
                onChange={(e) => setPageDraft({ ...pageDraft, slug: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="p_title">Title</label>
              <input
                id="p_title"
                value={pageDraft.title}
                onChange={(e) => setPageDraft({ ...pageDraft, title: e.target.value })}
              />
            </div>
            <h3 style={{ fontSize: '0.85rem', textTransform: 'uppercase', color: 'var(--muted)', marginTop: 8 }}>
              Page blocks
            </h3>
            <PageSectionsForm
              sections={pageDraft.sections ?? []}
              onChange={(sections) => setPageDraft({ ...pageDraft, sections })}
            />
            <div className="admin-field">
              <label htmlFor="p_body">Legacy body (only if no blocks above)</label>
              <textarea
                id="p_body"
                value={pageDraft.body ?? ''}
                onChange={(e) => setPageDraft({ ...pageDraft, body: e.target.value })}
              />
            </div>
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
                checked={pageDraft.show_in_nav ?? true}
                onChange={(e) => setPageDraft({ ...pageDraft, show_in_nav: e.target.checked })}
              />
              Show in navigation
            </label>
            <button type="button" disabled={busy} onClick={onSavePage}>
              Save page
            </button>
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
                      /p/{p.slug} {p.show_in_nav ? '· nav' : ''}
                    </span>
                  </span>
                  <span className="admin-row">
                    <button
                      type="button"
                      onClick={() =>
                        setPageDraft({
                          ...p,
                          sections: p.sections ?? [],
                        })
                      }
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
          <div className="admin-panel admin-grid">
            <h2 style={{ fontSize: '1rem', textTransform: 'uppercase', color: 'var(--muted)' }}>
              Navigation button
            </h2>
            <p className="admin-muted">
              Use internal paths like <code>/devlog</code> or <code>/p/about</code>, or full URLs for
              off-site links (toggle external).
            </p>
            <div className="admin-field">
              <label htmlFor="n_label">Label</label>
              <input
                id="n_label"
                value={navDraft.label}
                onChange={(e) => setNavDraft({ ...navDraft, label: e.target.value })}
              />
            </div>
            <div className="admin-field">
              <label htmlFor="n_href">Href</label>
              <input
                id="n_href"
                value={navDraft.href}
                onChange={(e) => setNavDraft({ ...navDraft, href: e.target.value })}
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
            <button type="button" disabled={busy} onClick={onSaveNav}>
              Save link
            </button>
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
              <label htmlFor="l_body">Body</label>
              <textarea
                id="l_body"
                value={logDraft.body ?? ''}
                onChange={(e) => setLogDraft({ ...logDraft, body: e.target.value })}
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
            <button type="button" disabled={busy} onClick={onSaveLog}>
              Save post
            </button>
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
    </div>
  );
}

/**
 * App routes (hash router: paths are really /#/play/..., /#/admin, …).
 *
 * To add a NEW top-level PAGE:
 * 1. Create `src/pages/MyPage.tsx` (copy an existing page as a template).
 * 2. Import it here and add `<Route path="/my-path" element={<MyPage />} />`.
 * 3. Optional: add a nav link in `src/components/SiteChrome.tsx` (`coreNav`) or use a CMS nav item if Supabase on.
 *
 * Dynamic CMS-backed pages use `/p/:slug` → StaticPage (content from DB when configured).
 */
import { HashRouter, Route, Routes } from 'react-router-dom';
import { ClickSound } from './components/ClickSound';
import { CookieConsentBanner } from './components/CookieConsentBanner';
import { FxBackdrop } from './components/FxBackdrop';
import { GlobalHtmlFxSync } from './components/GlobalHtmlFxSync';
import { MaintenanceGate } from './components/MaintenanceGate';
import { SiteAudio } from './components/SiteAudio';
import { SiteCursor } from './components/SiteCursor';
import { SiteCustomCss } from './components/SiteCustomCss';
import { SiteParticles } from './components/SiteParticles';
import { SiteBackgroundVideo } from './components/SiteBackgroundVideo';
import { SiteThemeApply } from './components/SiteThemeApply';
import { SiteWatermark } from './components/SiteWatermark';
import { AdminPage } from './pages/AdminPage';
import { AppsHubPage } from './pages/AppsHubPage';
import { DevLogListPage } from './pages/DevLogListPage';
import { DevLogPostPage } from './pages/DevLogPostPage';
import { GamePage } from './pages/GamePage';
import { HomePage } from './pages/HomePage';
import { PlayPage } from './pages/PlayPage';
import { PurchaseSuccessPage } from './pages/PurchaseSuccessPage';
import { PurchaseTermsPage } from './pages/PurchaseTermsPage';
import { StaticPage } from './pages/StaticPage';
import { VaultPage } from './pages/VaultPage';
import { AccountPage } from './pages/AccountPage';
import { AuthCallbackPage } from './pages/AuthCallbackPage';
import { OAuthConsentPage } from './pages/OAuthConsentPage';
import { SiteAnalytics } from './components/SiteAnalytics';
import { PrebuiltRouteGate } from './components/PrebuiltRouteGate';
import { ServicesPage } from './pages/ServicesPage';

export function App() {
  return (
    <HashRouter>
      <SiteBackgroundVideo />
      <GlobalHtmlFxSync />
      <SiteThemeApply />
      <SiteCustomCss />
      <ClickSound />
      <SiteAudio />
      <SiteCursor />
      <SiteParticles />
      <FxBackdrop />
      <SiteWatermark />
      <SiteAnalytics />
      <MaintenanceGate>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route
          path="/apps"
          element={
            <PrebuiltRouteGate flag="enable_apps_hub_page">
              <AppsHubPage />
            </PrebuiltRouteGate>
          }
        />
        <Route
          path="/services"
          element={
            <PrebuiltRouteGate flag="enable_services_page">
              <ServicesPage />
            </PrebuiltRouteGate>
          }
        />
        <Route
          path="/vault"
          element={
            <PrebuiltRouteGate flag="enable_vault_page">
              <VaultPage />
            </PrebuiltRouteGate>
          }
        />
        <Route path="/game/:slug" element={<GamePage />} />
        <Route path="/play/:slug" element={<PlayPage />} />
        <Route
          path="/devlog"
          element={
            <PrebuiltRouteGate flag="enable_devlog_section">
              <DevLogListPage />
            </PrebuiltRouteGate>
          }
        />
        <Route
          path="/devlog/:slug"
          element={
            <PrebuiltRouteGate flag="enable_devlog_section">
              <DevLogPostPage />
            </PrebuiltRouteGate>
          }
        />
        <Route path="/p/:slug" element={<StaticPage />} />
        {/* Stripe redirects: success/cancel URLs built with SITE_URL in create-checkout-session */}
        <Route path="/purchase/success" element={<PurchaseSuccessPage />} />
        <Route path="/purchase/terms" element={<PurchaseTermsPage />} />
        <Route path="/account" element={<AccountPage />} />
        <Route path="/auth/callback" element={<AuthCallbackPage />} />
        <Route path="/oauth/consent" element={<OAuthConsentPage />} />
        <Route path="/admin" element={<AdminPage />} />
      </Routes>
      </MaintenanceGate>
      <CookieConsentBanner />
    </HashRouter>
  );
}

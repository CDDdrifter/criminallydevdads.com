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
import { FxBackdrop } from './components/FxBackdrop';
import { AdminPage } from './pages/AdminPage';
import { DevLogListPage } from './pages/DevLogListPage';
import { DevLogPostPage } from './pages/DevLogPostPage';
import { GamePage } from './pages/GamePage';
import { HomePage } from './pages/HomePage';
import { PlayPage } from './pages/PlayPage';
import { PurchaseSuccessPage } from './pages/PurchaseSuccessPage';
import { PurchaseTermsPage } from './pages/PurchaseTermsPage';
import { StaticPage } from './pages/StaticPage';

export function App() {
  return (
    <>
      <FxBackdrop />
      <HashRouter>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/game/:slug" element={<GamePage />} />
          <Route path="/play/:slug" element={<PlayPage />} />
          <Route path="/devlog" element={<DevLogListPage />} />
          <Route path="/devlog/:slug" element={<DevLogPostPage />} />
          <Route path="/p/:slug" element={<StaticPage />} />
          {/* Stripe redirects: success/cancel URLs built with SITE_URL in create-checkout-session */}
          <Route path="/purchase/success" element={<PurchaseSuccessPage />} />
          <Route path="/purchase/terms" element={<PurchaseTermsPage />} />
          <Route path="/admin" element={<AdminPage />} />
        </Routes>
      </HashRouter>
    </>
  );
}

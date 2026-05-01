import { HashRouter, Route, Routes } from 'react-router-dom';
import { FxBackdrop } from './components/FxBackdrop';
import { AdminPage } from './pages/AdminPage';
import { DevLogListPage } from './pages/DevLogListPage';
import { DevLogPostPage } from './pages/DevLogPostPage';
import { GamePage } from './pages/GamePage';
import { HomePage } from './pages/HomePage';
import { PlayPage } from './pages/PlayPage';
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
          <Route path="/admin" element={<AdminPage />} />
        </Routes>
      </HashRouter>
    </>
  );
}

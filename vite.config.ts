import react from '@vitejs/plugin-react';
import { readFileSync, existsSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Plugin } from 'vite';
import { defineConfig } from 'vite';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function gamesJsonDevPlugin(): Plugin {
  const gamesJsonPath = path.join(__dirname, 'games.json');
  return {
    name: 'serve-root-games-json',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        if (req.url === '/games.json' && existsSync(gamesJsonPath)) {
          res.setHeader('Content-Type', 'application/json');
          res.end(readFileSync(gamesJsonPath));
          return;
        }
        next();
      });
    },
  };
}

const GAME_MIME: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.css': 'text/css; charset=utf-8',
};

/** Serve `./games/*` from repo `games/` in dev (matches production `dist/games/`). */
function gamesDevPlugin(): Plugin {
  const gamesDir = path.join(__dirname, 'games');
  return {
    name: 'serve-repo-games',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const raw = req.url ?? '';
        if (!raw.startsWith('/games/')) {
          next();
          return;
        }
        const rel = decodeURIComponent(raw.replace(/^\/games\//, '').split('?')[0] ?? '');
        if (!rel || rel.includes('..')) {
          next();
          return;
        }
        const filePath = path.join(gamesDir, rel);
        if (!filePath.startsWith(gamesDir) || !existsSync(filePath) || !statSync(filePath).isFile()) {
          next();
          return;
        }
        const ext = path.extname(filePath).toLowerCase();
        res.setHeader('Content-Type', GAME_MIME[ext] ?? 'application/octet-stream');
        res.end(readFileSync(filePath));
      });
    },
  };
}

/** Serve `./cms/*` from repo `cms/` in dev (matches production `dist/cms/`). */
function cmsDevPlugin(): Plugin {
  const cmsDir = path.join(__dirname, 'cms');
  return {
    name: 'serve-repo-cms-json',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const url = req.url ?? '';
        if (!url.startsWith('/cms/')) {
          next();
          return;
        }
        const rel = decodeURIComponent(url.replace(/^\/cms\//, ''));
        if (!rel || rel.includes('..')) {
          next();
          return;
        }
        const filePath = path.join(cmsDir, rel);
        if (!filePath.startsWith(cmsDir) || !existsSync(filePath)) {
          next();
          return;
        }
        res.setHeader('Content-Type', 'application/json');
        res.end(readFileSync(filePath));
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), gamesJsonDevPlugin(), gamesDevPlugin(), cmsDevPlugin()],
  // Absolute paths so refresh on deep links still loads /assets/* (not /play/assets/*).
  base: '/',
});

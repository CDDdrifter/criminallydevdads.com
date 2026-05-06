import react from '@vitejs/plugin-react';
import { readFileSync, existsSync } from 'node:fs';
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
  plugins: [react(), gamesJsonDevPlugin(), cmsDevPlugin()],
  base: './',
});

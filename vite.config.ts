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

export default defineConfig({
  plugins: [react(), gamesJsonDevPlugin()],
  base: './',
});

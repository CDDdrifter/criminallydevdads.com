import { cp } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const gamesSrc = path.join(root, 'games');
const distGames = path.join(root, 'dist', 'games');

if (!existsSync(path.join(root, 'dist'))) {
  console.warn('copy-games: dist/ missing — run vite build first');
  process.exit(0);
}

if (!existsSync(gamesSrc)) {
  console.warn('copy-games: no games/ folder at repo root');
  process.exit(0);
}

await cp(gamesSrc, distGames, { recursive: true });
console.log('copy-games: copied games/ → dist/games/');

const gamesJson = path.join(root, 'games.json');
if (existsSync(gamesJson)) {
  await cp(gamesJson, path.join(root, 'dist', 'games.json'));
  console.log('copy-games: copied games.json → dist/games.json');
}

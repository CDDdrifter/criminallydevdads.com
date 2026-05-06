import { cp } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const cmsSrc = path.join(root, 'cms');
const distCms = path.join(root, 'dist', 'cms');

if (!existsSync(path.join(root, 'dist'))) {
  console.warn('copy-cms: dist/ missing — run vite build first');
  process.exit(0);
}

if (!existsSync(cmsSrc)) {
  console.warn('copy-cms: no cms/ folder at repo root (optional — push from Admin after first sync)');
  process.exit(0);
}

await cp(cmsSrc, distCms, { recursive: true });
console.log('copy-cms: copied cms/ → dist/cms/');

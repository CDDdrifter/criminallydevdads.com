import { copyFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const indexHtml = path.join(root, 'dist', 'index.html');
const notFound = path.join(root, 'dist', '404.html');

if (!existsSync(indexHtml)) {
  console.warn('postbuild-spa-fallback: dist/index.html missing');
  process.exit(0);
}

copyFileSync(indexHtml, notFound);
console.log('postbuild-spa-fallback: dist/404.html ← index.html (GitHub Pages SPA)');

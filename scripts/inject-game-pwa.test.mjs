import test from 'node:test';
import assert from 'node:assert/strict';
import { parseGodotExecutable, parseGodotFileSizes, parseGodotTitle } from './inject-game-pwa.mjs';

test('parses Godot HTML5 export metadata', () => {
  const html = `<!DOCTYPE html>
<html><head><title>NovaDrop</title></head>
<body>
<script>
const GODOT_CONFIG = {"args":[],"executable":"index","fileSizes":{"index.pck":307404,"index.wasm":35739700}};
</script>
</body></html>`;

  assert.equal(parseGodotExecutable(html), 'index');
  assert.equal(parseGodotTitle(html, 'fallback'), 'NovaDrop');
  assert.deepEqual(parseGodotFileSizes(html), { 'index.pck': 307404, 'index.wasm': 35739700 });
});

test('parses Virtual Garden executable name', () => {
  const garden = 'const GODOT_CONFIG = {"executable":"VirtualGarden","fileSizes":{"VirtualGarden.pck":1,"VirtualGarden.wasm":2}};';
  assert.equal(parseGodotExecutable(garden), 'VirtualGarden');
  assert.deepEqual(parseGodotFileSizes(garden), { 'VirtualGarden.pck': 1, 'VirtualGarden.wasm': 2 });
});

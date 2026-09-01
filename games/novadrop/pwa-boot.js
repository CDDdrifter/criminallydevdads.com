/**
 * Per-game offline + iPhone Add to Home Screen boot.
 * Loaded from each Godot `index.html`. Never reloads the page.
 */
(function () {
  'use strict';

  if (window.__CDD_PWA_BOOT__) {
    return;
  }
  window.__CDD_PWA_BOOT__ = true;

  var CACHE_JSON = 'offline-cache.json';
  var SW_FILE = 'offline-sw.js';

  function inIframe() {
    try {
      return window.self !== window.top;
    } catch (e) {
      return true;
    }
  }

  function isIos() {
    var ua = navigator.userAgent || '';
    if (/iPhone|iPod|iPad/.test(ua)) {
      return true;
    }
    return navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1;
  }

  function isSafari() {
    var ua = navigator.userAgent || '';
    return /Safari/.test(ua) && !/CriOS|FxiOS|EdgiOS|OPiOS|DuckDuckGo/.test(ua);
  }

  function isStandalone() {
    if (window.navigator.standalone === true) {
      return true;
    }
    try {
      return window.matchMedia('(display-mode: standalone)').matches;
    } catch (e) {
      return false;
    }
  }

  function $(id) {
    return document.getElementById(id);
  }

  function formatMb(bytes) {
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }

  function ensureUi(title) {
    if ($('cdd-pwa-root')) {
      return;
    }
    var style = document.createElement('style');
    style.textContent =
      '#cdd-pwa-root{position:fixed;left:0;right:0;bottom:0;z-index:2147483000;font-family:system-ui,-apple-system,sans-serif;pointer-events:none}' +
      '#cdd-pwa-root *{box-sizing:border-box}' +
      '#cdd-pwa-bar{pointer-events:auto;margin:0 10px 10px;padding:12px 14px;border-radius:12px;background:rgba(8,12,22,.94);border:1px solid rgba(115,248,255,.45);color:#eaf0ff;box-shadow:0 8px 28px rgba(0,0,0,.45)}' +
      '#cdd-pwa-bar h2{margin:0 0 6px;font-size:14px;color:#73f8ff}' +
      '#cdd-pwa-bar p{margin:0 0 8px;font-size:12px;line-height:1.45;color:#c5cde4}' +
      '#cdd-pwa-bar button{appearance:none;margin:0 8px 0 0;padding:8px 12px;border-radius:8px;border:1px solid rgba(115,248,255,.45);background:#0c1220;color:#eaf0ff;font-weight:700;font-size:12px}' +
      '#cdd-pwa-progress{display:block;width:100%;height:6px;margin:8px 0;border:0;border-radius:99px;overflow:hidden;background:#1a2236}' +
      '#cdd-pwa-progress::-webkit-progress-value{background:#73f8ff}' +
      '#cdd-pwa-root.is-standalone,#cdd-pwa-root.is-iframe{display:none}';
    document.head.appendChild(style);

    var root = document.createElement('div');
    root.id = 'cdd-pwa-root';
    root.innerHTML =
      '<div id="cdd-pwa-bar" role="status">' +
      '<h2 id="cdd-pwa-title">Save ' +
      title +
      ' to this iPhone</h2>' +
      '<p id="cdd-pwa-msg">Keeping this tab open while the game files save. This does not reload the game.</p>' +
      '<progress id="cdd-pwa-progress" value="0" max="100"></progress>' +
      '<div id="cdd-pwa-actions"></div>' +
      '</div>';
    document.body.appendChild(root);

    if (inIframe()) {
      root.classList.add('is-iframe');
    }
    if (isStandalone()) {
      root.classList.add('is-standalone');
    }
  }

  function setMsg(text) {
    var el = $('cdd-pwa-msg');
    if (el) {
      el.textContent = text;
    }
  }

  function setProgress(value, max) {
    var el = $('cdd-pwa-progress');
    if (!el) {
      return;
    }
    el.max = String(max || 100);
    el.value = String(value || 0);
  }

  function setActions(html) {
    var el = $('cdd-pwa-actions');
    if (el) {
      el.innerHTML = html;
    }
  }

  function hideBarSoon() {
    var root = $('cdd-pwa-root');
    if (!root || inIframe() || isStandalone()) {
      return;
    }
    setTimeout(function () {
      root.style.display = 'none';
    }, 8000);
  }

  async function readManifest() {
    var res = await fetch(CACHE_JSON, { cache: 'no-store' });
    if (!res.ok) {
      throw new Error('Missing offline-cache.json');
    }
    return res.json();
  }

  async function cacheHasAll(cache, assets) {
    for (var i = 0; i < assets.length; i++) {
      var match = await cache.match(assets[i]);
      if (!match) {
        return false;
      }
    }
    return true;
  }

  async function putWithProgress(cache, url, onChunk, knownSize) {
    var res = await fetch(url, { cache: 'reload' });
    if (!res.ok) {
      throw new Error('Failed to save ' + url);
    }
    var total = Number(res.headers.get('content-length') || knownSize || 0);
    var type = res.headers.get('content-type') || 'application/octet-stream';
    if (!res.body || !res.body.getReader) {
      await cache.put(url, res);
      if (total) {
        onChunk(total, total);
      }
      return total;
    }
    var reader = res.body.getReader();
    var chunks = [];
    var received = 0;
    while (true) {
      var step = await reader.read();
      if (step.done) {
        break;
      }
      chunks.push(step.value);
      received += step.value.length;
      onChunk(received, total || received);
    }
    var blob = new Blob(chunks, { type: type });
    var headers = new Headers();
    headers.set('Content-Type', type);
    headers.set('Content-Length', String(blob.size));
    await cache.put(url, new Response(blob, { status: 200, headers: headers }));
    return blob.size;
  }

  async function saveOffline(info) {
    if (!('caches' in window)) {
      throw new Error('This browser cannot save games offline.');
    }
    var cache = await caches.open(info.cacheName);
    var assets = info.assets || [];
    if (await cacheHasAll(cache, assets)) {
      return { already: true, bytes: info.bytes || 0 };
    }
    var sizes = info.sizes || {};
    var totalKnown = 0;
    assets.forEach(function (url) {
      totalKnown += Number(sizes[url] || 0);
    });
    var received = 0;
    for (var i = 0; i < assets.length; i++) {
      var url = assets[i];
      var already = await cache.match(url);
      if (already) {
        received += Number(sizes[url] || 0);
        setProgress(received, totalKnown || assets.length);
        continue;
      }
      var before = received;
      await putWithProgress(
        cache,
        url,
        function (chunkReceived, chunkTotal) {
          var local = Number(sizes[url] || chunkTotal || 0);
          setProgress(before + chunkReceived, totalKnown || local);
        },
        sizes[url],
      );
      received += Number(sizes[url] || 0);
      setProgress(received, totalKnown || i + 1);
    }
    return { already: false, bytes: totalKnown };
  }

  async function registerSw() {
    if (!('serviceWorker' in navigator)) {
      return null;
    }
    try {
      return await navigator.serviceWorker.register(SW_FILE, { scope: './' });
    } catch (err) {
      console.warn('[cdd-pwa] service worker not registered', err);
      return null;
    }
  }

  function showSavedHelp(bytes) {
    var size = bytes ? ' (' + formatMb(bytes) + ')' : '';
    if (isStandalone()) {
      setMsg('Saved on this phone' + size + '. You can play without service.');
      hideBarSoon();
      return;
    }
    if (isIos()) {
      if (!isSafari()) {
        setMsg(
          'Files are saved' +
            size +
            '. Open this same page in Safari, then tap Share → Add to Home Screen.',
        );
        setActions('<button type="button" id="cdd-pwa-hide">OK</button>');
      } else {
        setMsg(
          'Saved on this iPhone' +
            size +
            '. Tap Share (the square with the arrow), then Add to Home Screen. After that it opens with no signal.',
        );
        setActions('<button type="button" id="cdd-pwa-hide">Got it</button>');
      }
    } else {
      setMsg('Saved on this device' + size + '. You can play this game without internet.');
      setActions('<button type="button" id="cdd-pwa-hide">OK</button>');
    }
    var btn = $('cdd-pwa-hide');
    if (btn) {
      btn.addEventListener('click', function () {
        var root = $('cdd-pwa-root');
        if (root) {
          root.style.display = 'none';
        }
      });
    }
  }

  async function boot() {
    if (inIframe()) {
      return;
    }

    var info;
    try {
      info = await readManifest();
    } catch (err) {
      console.warn('[cdd-pwa]', err);
      return;
    }

    ensureUi(info.title || document.title || 'Game');
    if (!isStandalone()) {
      setMsg('Saving game files to this phone. Keep this page open — the game itself will not refresh.');
    }

    try {
      await registerSw();
      var result = await saveOffline(info);
      setProgress(100, 100);
      if (!inIframe()) {
        showSavedHelp(result.bytes);
      }
    } catch (err) {
      console.warn('[cdd-pwa] save failed', err);
      if (!inIframe()) {
        setMsg(
          'Could not finish saving offline. Stay on Wi‑Fi, free some iPhone storage, and leave this page open until it says saved.',
        );
        setActions('<button type="button" id="cdd-pwa-retry">Try again</button>');
        var retry = $('cdd-pwa-retry');
        if (retry) {
          retry.addEventListener('click', function () {
            boot();
          });
        }
      }
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();

'use strict';

// Hand-written service worker for offline support. Flutter's own web build
// stopped generating a caching service worker (the auto-generated
// flutter_service_worker.js now just installs and immediately unregisters
// itself) — see https://docs.flutter.dev/platform-integration/web/faq
// ("How do I configure a service worker?"). This one is registered
// separately from web/flutter_bootstrap.js.
//
// __BUILD_ID__ is stamped with the deploying commit's SHA by the GitHub
// Pages workflow (.github/workflows/deploy-pages.yml) so every deploy gets
// a distinct cache automatically — that's what forces old caches to be
// dropped and fresh copies of main.dart.js etc. to be fetched. Relying on
// a hand-bumped version number here was tried first and quietly broke
// twice (a Dart-level fix would ship, but browsers kept serving the old
// cached main.dart.js because nobody remembered to bump this string).
// For local `flutter build web` runs outside CI, this stays literally
// "doc-lookup-shell-__BUILD_ID__" — fine for local testing, but bump it by
// hand (or just clear site data) if you need a local build to actually
// invalidate a previous local build's cache.
const CACHE_NAME = 'doc-lookup-shell-__BUILD_ID__';

// The few files guaranteed to exist and small enough to fetch eagerly at
// install time, so the very first offline visit after install still has an
// app shell to render. Everything else the app needs (main.dart.js,
// canvaskit, sqlite3.wasm, fonts, icons) is same-origin and gets cached
// lazily the first time it's actually requested — see the fetch handler
// below — rather than hardcoded here, since those filenames aren't stable
// across Flutter/package versions.
const CORE_ASSETS = ['./', 'index.html', 'manifest.json', 'favicon.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(CORE_ASSETS))
      .catch((e) => console.warn('Service worker precache failed:', e))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((names) => Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return; // never cache cross-origin responses

  // Scoped to this version's cache specifically — plain `caches.match()`
  // searches every cache this origin has ever created, so a stale entry
  // left over from a previous CACHE_NAME (e.g. cleanup racing a fetch) can
  // shadow a fresh one indefinitely and silently defeat the whole
  // version-bump mechanism.
  const versionedCache = caches.open(CACHE_NAME);

  if (request.mode === 'navigate') {
    // Network-first for the app shell page itself, so an online visit always
    // gets the latest index.html; offline falls back to whatever was cached.
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          versionedCache.then((cache) => cache.put('index.html', copy));
          return response;
        })
        .catch(() => versionedCache.then((cache) => cache.match('index.html')))
    );
    return;
  }

  // Cache-first for every other same-origin asset (JS, wasm, fonts, icons) —
  // these don't change without a full redeploy (which bumps CACHE_NAME), so
  // serving from cache first is both faster and offline-safe. Whatever
  // hasn't been cached yet is fetched and cached on the way through.
  event.respondWith(
    versionedCache.then((cache) =>
      cache.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request)
          .then((response) => {
            if (response.ok) cache.put(request, response.clone());
            return response;
          })
          .catch(() => cached);
      })
    )
  );
});

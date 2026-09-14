{{flutter_js}}
{{flutter_build_config}}

// Registers our own service worker (web/custom_sw.js) for offline support.
// Flutter's default flutter_bootstrap.js no longer does this — its
// generated flutter_service_worker.js now just installs and immediately
// unregisters itself. See https://docs.flutter.dev/platform-integration/web/faq.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('custom_sw.js').catch((e) => {
      console.warn('Service worker registration failed:', e);
    });
  });
}

_flutter.loader.load({
  config: {
    // Serve CanvasKit from this app's own origin (already bundled under
    // build/web/canvaskit/) instead of Google's CDN — the default. Keeping
    // it same-origin means the service worker above can actually cache it,
    // so the renderer itself works offline too, not just the app shell.
    canvasKitBaseUrl: 'canvaskit/',
  },
});

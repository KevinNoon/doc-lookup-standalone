import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Best-effort request that the browser not evict this origin's IndexedDB
/// data under storage pressure or a user-initiated "Clear site data" — it
/// reduces but doesn't eliminate that risk, and the app works the same
/// whether or not the browser grants it.
Future<void> requestPersistentStorage() async {
  await web.window.navigator.storage.persist().toDart;
}

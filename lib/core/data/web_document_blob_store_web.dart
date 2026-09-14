import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Stores document bytes directly in IndexedDB on web, bypassing the
/// SQLite `bytes` column entirely. Writing a large blob through
/// `databaseFactoryFfiWebNoWebWorker` (main-thread wasm SQLite) was found to
/// block the UI thread for 60+ seconds on an ~18MB file — the underlying
/// VFS appears to re-serialize the whole database file to IndexedDB on
/// every write, so every future write would get slower as the library
/// grows, not just large single files. Plain IndexedDB has no such scaling
/// problem; browsers handle large blobs there natively and efficiently.
class WebDocumentBlobStore {
  static const _dbName = 'doc_lookup_blobs';
  static const _storeName = 'documents';

  Future<web.IDBDatabase>? _dbFuture;

  Future<web.IDBDatabase> _open() => _dbFuture ??= _doOpen();

  Future<web.IDBDatabase> _doOpen() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_dbName, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore(_storeName);
    }).toJS;
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('Failed to open document blob store: ${request.error}'));
    }).toJS;
    return completer.future;
  }

  Future<void> put(String id, Uint8List bytes) async {
    final db = await _open();
    final completer = Completer<void>();
    final store = db.transaction(_storeName.toJS, 'readwrite').objectStore(_storeName);
    final request = store.put(bytes.toJS, id.toJS);
    request.onsuccess = ((web.Event _) => completer.complete()).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('Failed to write document bytes: ${request.error}'));
    }).toJS;
    return completer.future;
  }

  Future<Uint8List> get(String id) async {
    final db = await _open();
    final completer = Completer<Uint8List>();
    final store = db.transaction(_storeName.toJS, 'readonly').objectStore(_storeName);
    final request = store.get(id.toJS);
    request.onsuccess = ((web.Event _) {
      final result = request.result;
      if (result == null) {
        completer.completeError(StateError('No document bytes found for id $id'));
      } else {
        completer.complete((result as JSUint8Array).toDart);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('Failed to read document bytes: ${request.error}'));
    }).toJS;
    return completer.future;
  }

  Future<void> delete(String id) async {
    final db = await _open();
    final completer = Completer<void>();
    final store = db.transaction(_storeName.toJS, 'readwrite').objectStore(_storeName);
    final request = store.delete(id.toJS);
    request.onsuccess = ((web.Event _) => completer.complete()).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('Failed to delete document bytes: ${request.error}'));
    }).toJS;
    return completer.future;
  }
}

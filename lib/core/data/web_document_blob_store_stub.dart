import 'dart:typed_data';

/// Never actually called on non-web platforms — every call site guards with
/// `kIsWeb` first, since native storage keeps document bytes in the SQLite
/// `bytes` column instead. Exists only so the conditional import in
/// document_repository.dart has a same-shaped class to fall back to.
class WebDocumentBlobStore {
  Future<void> put(String id, Uint8List bytes) => throw UnsupportedError('web-only');

  Future<Uint8List> get(String id) => throw UnsupportedError('web-only');

  Future<void> delete(String id) => throw UnsupportedError('web-only');
}

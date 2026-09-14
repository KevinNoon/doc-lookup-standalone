import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/local_database.dart';
import '../../../core/data/table_change_bus.dart';
import '../../../core/data/web_document_blob_store_web.dart'
    if (dart.library.io) '../../../core/data/web_document_blob_store_stub.dart';
import '../domain/document.dart';

part 'document_repository.g.dart';

const _formatsByExtension = {
  'pdf': DocumentFormat.pdf,
  'epub': DocumentFormat.epub,
  'docx': DocumentFormat.docx,
  'txt': DocumentFormat.txt,
};

class DocumentRepository {
  DocumentRepository(this._db, this._bus);

  final LocalDatabase _db;
  final TableChangeBus _bus;
  final _webBlobs = WebDocumentBlobStore();

  Future<List<Document>> _fetchAll() async {
    final rows = await _db.db.query(
      'documents',
      columns: ['id', 'title', 'format', 'sizeBytes', 'folderId', 'createdAt'],
      orderBy: 'createdAt DESC',
    );
    return rows.map((row) => Document.fromMap(row['id'].toString(), row)).toList();
  }

  Stream<List<Document>> watchDocuments() => _bus.watch('documents', _fetchAll);

  /// One-time migration for documents imported before bytes moved to
  /// IndexedDB on web (schema v1, where `bytes` lived in this SQL column) —
  /// copies any row still carrying its bytes there into IndexedDB, then
  /// clears the column. Idempotent: once migrated, the query finds nothing.
  Future<void> migrateLegacyBytesToIndexedDbIfNeeded() async {
    if (!kIsWeb) return;
    final rows = await _db.db.query('documents', columns: ['id', 'bytes'], where: 'bytes IS NOT NULL');
    for (final row in rows) {
      final id = row['id'].toString();
      await _webBlobs.put(id, row['bytes'] as Uint8List);
      await _db.db.update('documents', {'bytes': null}, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  /// Reads [document]'s file content back out of storage. On web this comes
  /// from IndexedDB (see [WebDocumentBlobStore] for why); elsewhere it's the
  /// `bytes` column alongside the rest of the row.
  Future<Uint8List> documentBytes(Document document) async {
    if (kIsWeb) return _webBlobs.get(document.id);

    final rows = await _db.db.query(
      'documents',
      columns: ['bytes'],
      where: 'id = ?',
      whereArgs: [int.parse(document.id)],
    );
    return rows.first['bytes'] as Uint8List;
  }

  /// Opens the system file picker and, if the user selects a supported
  /// document, stores its bytes and metadata.
  Future<Document?> pickAndImportDocument() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _formatsByExtension.keys.toList(),
    );
    if (picked == null) return null;

    final extension = p.extension(picked.name).replaceFirst('.', '').toLowerCase();
    final format = _formatsByExtension[extension];
    if (format == null) return null;

    final title = p.basenameWithoutExtension(picked.name);
    final bytes = await picked.readAsBytes();
    final createdAt = DateTime.now().millisecondsSinceEpoch;

    final id = await _db.db.insert('documents', {
      'title': title,
      'format': format.name,
      'sizeBytes': bytes.length,
      // On web, bytes go to IndexedDB below instead — see documentBytes().
      'bytes': kIsWeb ? null : bytes,
      'folderId': null,
      'createdAt': createdAt,
    });
    if (kIsWeb) await _webBlobs.put(id.toString(), bytes);

    final document = Document(
      id: id.toString(),
      title: title,
      format: format,
      sizeBytes: bytes.length,
      createdAt: createdAt,
    );

    _bus.notify('documents');
    return document;
  }

  /// Removes [document] from the library: deletes its stored bytes, then
  /// its database record.
  Future<void> deleteDocument(Document document) async {
    if (kIsWeb) await _webBlobs.delete(document.id);

    await _db.db.transaction((txn) async {
      await txn.delete('documents', where: 'id = ?', whereArgs: [int.parse(document.id)]);
      if (document.folderId != null) {
        await txn.rawUpdate('UPDATE folders SET documentCount = documentCount - 1 WHERE id = ?', [
          int.parse(document.folderId!),
        ]);
      }
    });
    _bus.notify('documents');
    _bus.notify('folders');
  }
}

@riverpod
Future<DocumentRepository> documentRepository(Ref ref) async {
  final repo = DocumentRepository(await ref.watch(localDatabaseProvider.future), ref.watch(tableChangeBusProvider));
  await repo.migrateLegacyBytesToIndexedDbIfNeeded();
  return repo;
}

@riverpod
Stream<List<Document>> userDocuments(Ref ref) async* {
  final repo = await ref.watch(documentRepositoryProvider.future);
  yield* repo.watchDocuments();
}

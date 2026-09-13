import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/local_database.dart';
import '../../../core/data/table_change_bus.dart';
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

  Future<List<Document>> _fetchAll() async {
    final rows = await _db.db.query('documents', orderBy: 'createdAt DESC');
    return rows.map((row) => Document.fromMap(row['id'].toString(), row)).toList();
  }

  Stream<List<Document>> watchDocuments() => _bus.watch('documents', _fetchAll);

  Future<String> _localCachePath(Document document) async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'documents', '${document.id}.${document.fileExtension}');
  }

  /// Returns the readable local path for [document] — every document is
  /// always stored locally in this build, so this is just a path lookup.
  Future<String> ensureLocalFile(Document document) => _localCachePath(document);

  /// Opens the system file picker and, if the user selects a supported
  /// document, copies it into app-private storage and records its metadata
  /// in the local database.
  Future<Document?> pickAndImportDocument() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _formatsByExtension.keys.toList(),
    );
    final pickedPath = picked?.path;
    if (pickedPath == null) return null;

    final extension = p.extension(pickedPath).replaceFirst('.', '').toLowerCase();
    final format = _formatsByExtension[extension];
    if (format == null) return null;

    final title = p.basenameWithoutExtension(pickedPath);
    final sizeBytes = await File(pickedPath).length();
    final createdAt = DateTime.now().millisecondsSinceEpoch;

    final id = await _db.db.insert('documents', {
      'title': title,
      'format': format.name,
      'sizeBytes': sizeBytes,
      'folderId': null,
      'createdAt': createdAt,
    });
    final document = Document(id: id.toString(), title: title, format: format, sizeBytes: sizeBytes, createdAt: createdAt);

    final destination = await _localCachePath(document);
    await Directory(p.dirname(destination)).create(recursive: true);
    await File(pickedPath).copy(destination);

    _bus.notify('documents');
    return document;
  }

  /// Removes [document] from the library: deletes the local cached file,
  /// then the database record.
  Future<void> deleteDocument(Document document) async {
    final localPath = await _localCachePath(document);
    final localFile = File(localPath);
    if (await localFile.exists()) await localFile.delete();

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
  return DocumentRepository(await ref.watch(localDatabaseProvider.future), ref.watch(tableChangeBusProvider));
}

@riverpod
Stream<List<Document>> userDocuments(Ref ref) async* {
  final repo = await ref.watch(documentRepositoryProvider.future);
  yield* repo.watchDocuments();
}

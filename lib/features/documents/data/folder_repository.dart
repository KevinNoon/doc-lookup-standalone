import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/local_database.dart';
import '../../../core/data/table_change_bus.dart';
import '../domain/folder.dart';

part 'folder_repository.g.dart';

class FolderRepository {
  FolderRepository(this._db, this._bus);

  final LocalDatabase _db;
  final TableChangeBus _bus;

  Future<List<Folder>> _fetchAll() async {
    final rows = await _db.db.query('folders', orderBy: 'name');
    return rows.map((row) => Folder.fromMap(row['id'].toString(), row)).toList();
  }

  Stream<List<Folder>> watchFolders() => _bus.watch('folders', _fetchAll);

  Future<Folder> createFolder({required String name, required String colorHex}) async {
    final id = await _db.db.insert('folders', {'name': name, 'colorHex': colorHex, 'documentCount': 0});
    _bus.notify('folders');
    return Folder(id: id.toString(), name: name, colorHex: colorHex, documentCount: 0);
  }

  /// Deletes the folder itself; documents that were in it simply lose their
  /// `folderId` (they aren't deleted).
  Future<void> deleteFolder(String folderId) async {
    final id = int.parse(folderId);
    await _db.db.transaction((txn) async {
      await txn.update('documents', {'folderId': null}, where: 'folderId = ?', whereArgs: [id]);
      await txn.delete('folders', where: 'id = ?', whereArgs: [id]);
    });
    _bus.notify('documents');
    _bus.notify('folders');
  }

  /// Moves [documentId] into [folderId] (or out of any folder, if null),
  /// adjusting `documentCount` on the old and new folders to match.
  Future<void> moveDocument({required String documentId, String? oldFolderId, String? folderId}) async {
    await _db.db.transaction((txn) async {
      await txn.update(
        'documents',
        {'folderId': folderId != null ? int.parse(folderId) : null},
        where: 'id = ?',
        whereArgs: [int.parse(documentId)],
      );
      if (oldFolderId != null) {
        await txn.rawUpdate('UPDATE folders SET documentCount = documentCount - 1 WHERE id = ?', [
          int.parse(oldFolderId),
        ]);
      }
      if (folderId != null) {
        await txn.rawUpdate('UPDATE folders SET documentCount = documentCount + 1 WHERE id = ?', [
          int.parse(folderId),
        ]);
      }
    });
    _bus.notify('documents');
    _bus.notify('folders');
  }
}

@riverpod
Future<FolderRepository> folderRepository(Ref ref) async {
  return FolderRepository(await ref.watch(localDatabaseProvider.future), ref.watch(tableChangeBusProvider));
}

@riverpod
Stream<List<Folder>> userFolders(Ref ref) async* {
  final repo = await ref.watch(folderRepositoryProvider.future);
  yield* repo.watchFolders();
}

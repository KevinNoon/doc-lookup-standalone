import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/local_database.dart';
import '../../../core/data/table_change_bus.dart';
import '../domain/saved_lookup.dart';

part 'saved_lookup_repository.g.dart';

class SavedLookupRepository {
  SavedLookupRepository(this._db, this._bus);

  final LocalDatabase _db;
  final TableChangeBus _bus;

  /// Bridges a flat sqflite row back to the nested-map shape
  /// [SavedLookup.fromMap] expects (mirroring how a Firestore document looks
  /// to that same factory) — decodes the JSON-encoded columns back into
  /// nested maps/lists.
  Map<String, dynamic> _decodeRow(Map<String, Object?> row) {
    final map = Map<String, dynamic>.from(row);
    for (final key in ['quickResult', 'deepDiveResult', 'translation']) {
      if (map[key] != null) map[key] = jsonDecode(map[key] as String);
    }
    map['documentId'] = map['documentId']?.toString();
    map['groupIds'] = map['groupIds'] != null ? (jsonDecode(map['groupIds'] as String) as List).cast<String>() : const [];
    map['tags'] = map['tags'] != null ? (jsonDecode(map['tags'] as String) as List).cast<String>() : const [];
    return map;
  }

  Map<String, Object?> _encodeForDb(SavedLookup lookup) {
    final map = lookup.toMap();
    return {
      'word': map['word'],
      'documentId': map['documentId'] != null ? int.parse(map['documentId'] as String) : null,
      'documentTitle': map['documentTitle'],
      'page': map['page'],
      'contextSnippet': map['contextSnippet'],
      'quickResult': map['quickResult'] != null ? jsonEncode(map['quickResult']) : null,
      'deepDiveResult': map['deepDiveResult'] != null ? jsonEncode(map['deepDiveResult']) : null,
      'translation': map['translation'] != null ? jsonEncode(map['translation']) : null,
      'groupIds': jsonEncode(map['groupIds']),
      'tags': jsonEncode(map['tags']),
    };
  }

  Future<List<SavedLookup>> _fetchAll() async {
    final rows = await _db.db.query('lookups', orderBy: 'createdAt DESC');
    return rows.map((row) => SavedLookup.fromMap(row['id'].toString(), _decodeRow(row))).toList();
  }

  Stream<List<SavedLookup>> watchSavedLookups() => _bus.watch('lookups', _fetchAll);

  /// Saves [lookup] and atomically bumps `lookupCount` on every group it
  /// belongs to.
  Future<void> saveLookup(SavedLookup lookup) async {
    await _db.db.transaction((txn) async {
      await txn.insert('lookups', {
        ..._encodeForDb(lookup),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      for (final groupId in lookup.groupIds) {
        await txn.rawUpdate('UPDATE groups_ SET lookupCount = lookupCount + 1 WHERE id = ?', [int.parse(groupId)]);
      }
    });
    _bus.notify('lookups');
    if (lookup.groupIds.isNotEmpty) _bus.notify('groups_');
  }

  /// Changes which groups [lookup] belongs to, adjusting `lookupCount` on
  /// every affected group to match (increment for newly added groups,
  /// decrement for ones it's removed from).
  Future<void> updateGroups(SavedLookup lookup, List<String> newGroupIds) async {
    await updateGroupsForOccurrences([lookup], newGroupIds);
  }

  /// Sets the same [newGroupIds] on every lookup in [occurrences] — used to
  /// move a whole word (all its saved sources) between groups in one action.
  Future<void> updateGroupsForOccurrences(List<SavedLookup> occurrences, List<String> newGroupIds) async {
    final newIds = newGroupIds.toSet();
    await _db.db.transaction((txn) async {
      for (final lookup in occurrences) {
        final oldIds = lookup.groupIds.toSet();
        await txn.update(
          'lookups',
          {'groupIds': jsonEncode(newGroupIds)},
          where: 'id = ?',
          whereArgs: [int.parse(lookup.id)],
        );
        for (final groupId in newIds.difference(oldIds)) {
          await txn.rawUpdate('UPDATE groups_ SET lookupCount = lookupCount + 1 WHERE id = ?', [int.parse(groupId)]);
        }
        for (final groupId in oldIds.difference(newIds)) {
          await txn.rawUpdate('UPDATE groups_ SET lookupCount = lookupCount - 1 WHERE id = ?', [int.parse(groupId)]);
        }
      }
    });
    _bus.notify('lookups');
    _bus.notify('groups_');
  }

  /// Sets the same [newTags] on every lookup in [occurrences].
  Future<void> updateTagsForOccurrences(List<SavedLookup> occurrences, List<String> newTags) async {
    await _db.db.transaction((txn) async {
      for (final lookup in occurrences) {
        await txn.update(
          'lookups',
          {'tags': jsonEncode(newTags)},
          where: 'id = ?',
          whereArgs: [int.parse(lookup.id)],
        );
      }
    });
    _bus.notify('lookups');
  }

  /// Deletes [lookup] and decrements `lookupCount` on every group it
  /// belonged to.
  Future<void> deleteLookup(SavedLookup lookup) async {
    await _db.db.transaction((txn) async {
      await txn.delete('lookups', where: 'id = ?', whereArgs: [int.parse(lookup.id)]);
      for (final groupId in lookup.groupIds) {
        await txn.rawUpdate('UPDATE groups_ SET lookupCount = lookupCount - 1 WHERE id = ?', [int.parse(groupId)]);
      }
    });
    _bus.notify('lookups');
    if (lookup.groupIds.isNotEmpty) _bus.notify('groups_');
  }
}

@riverpod
Future<SavedLookupRepository> savedLookupRepository(Ref ref) async {
  return SavedLookupRepository(await ref.watch(localDatabaseProvider.future), ref.watch(tableChangeBusProvider));
}

@riverpod
Stream<List<SavedLookup>> userSavedLookups(Ref ref) async* {
  final repo = await ref.watch(savedLookupRepositoryProvider.future);
  yield* repo.watchSavedLookups();
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/local_database.dart';
import '../../../core/data/table_change_bus.dart';
import '../domain/group.dart';

part 'group_repository.g.dart';

class GroupRepository {
  GroupRepository(this._db, this._bus);

  final LocalDatabase _db;
  final TableChangeBus _bus;

  Future<List<Group>> _fetchAll() async {
    final rows = await _db.db.query('groups_', orderBy: 'name');
    return rows.map((row) => Group.fromMap(row['id'].toString(), row)).toList();
  }

  Stream<List<Group>> watchGroups() => _bus.watch('groups_', _fetchAll);

  Future<Group> createGroup({required String name, required String colorHex}) async {
    final id = await _db.db.insert('groups_', {'name': name, 'colorHex': colorHex, 'lookupCount': 0});
    _bus.notify('groups_');
    return Group(id: id.toString(), name: name, colorHex: colorHex, lookupCount: 0);
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.db.delete('groups_', where: 'id = ?', whereArgs: [int.parse(groupId)]);
    _bus.notify('groups_');
  }
}

@riverpod
Future<GroupRepository> groupRepository(Ref ref) async {
  return GroupRepository(await ref.watch(localDatabaseProvider.future), ref.watch(tableChangeBusProvider));
}

@riverpod
Stream<List<Group>> userGroups(Ref ref) async* {
  final repo = await ref.watch(groupRepositoryProvider.future);
  yield* repo.watchGroups();
}

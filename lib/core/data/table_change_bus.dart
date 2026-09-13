import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'table_change_bus.g.dart';

/// App-wide "table changed" event bus — emulates Firestore's realtime
/// `snapshots()` semantics on top of sqflite, where a write is visible to
/// every listener on that collection/table regardless of which repository
/// performed it (e.g. [FolderRepository] unsetting a document's `folderId`,
/// or [SavedLookupRepository] incrementing a group's `lookupCount`, both
/// need to notify watchers of a table they don't otherwise own).
class TableChangeBus {
  final _controller = StreamController<String>.broadcast();

  void notify(String table) => _controller.add(table);

  /// Runs [query] once immediately, then again every time [table] is
  /// notified as changed.
  Stream<List<T>> watch<T>(String table, Future<List<T>> Function() query) async* {
    yield await query();
    await for (final changedTable in _controller.stream) {
      if (changedTable == table) yield await query();
    }
  }
}

@Riverpod(keepAlive: true)
TableChangeBus tableChangeBus(Ref ref) => TableChangeBus();

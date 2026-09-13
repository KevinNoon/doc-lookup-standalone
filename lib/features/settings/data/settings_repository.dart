import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/data/local_database.dart';
import '../../../core/data/table_change_bus.dart';

part 'settings_repository.g.dart';

const geminiApiKeySettingKey = 'geminiApiKey';

class SettingsRepository {
  SettingsRepository(this._db, this._bus);

  final LocalDatabase _db;
  final TableChangeBus _bus;

  Future<String?> _get(String key) async {
    final rows = await _db.db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _set(String key, String? value) async {
    await _db.db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _bus.notify('settings');
  }

  Stream<String?> watchGeminiApiKey() => _bus.watch('settings', () async {
        final value = await _get(geminiApiKeySettingKey);
        return [value];
      }).map((values) => values.first);

  Future<String?> getGeminiApiKey() => _get(geminiApiKeySettingKey);

  Future<void> setGeminiApiKey(String? apiKey) => _set(geminiApiKeySettingKey, apiKey);
}

@riverpod
Future<SettingsRepository> settingsRepository(Ref ref) async {
  return SettingsRepository(await ref.watch(localDatabaseProvider.future), ref.watch(tableChangeBusProvider));
}

@riverpod
Stream<String?> geminiApiKey(Ref ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchGeminiApiKey();
}

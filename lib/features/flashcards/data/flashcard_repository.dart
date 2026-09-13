import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/local_database.dart';
import '../../../core/data/table_change_bus.dart';
import '../domain/flashcard.dart';
import '../domain/sm2.dart';

part 'flashcard_repository.g.dart';

class FlashcardRepository {
  FlashcardRepository(this._db, this._bus);

  final LocalDatabase _db;
  final TableChangeBus _bus;

  Future<List<Flashcard>> _fetchDue() async {
    final rows = await _db.db.query(
      'flashcards',
      where: 'dueDate <= ?',
      whereArgs: [DateTime.now().millisecondsSinceEpoch],
      orderBy: 'dueDate',
    );
    return rows.map((row) => Flashcard.fromMap(row['id'].toString(), row)).toList();
  }

  Stream<List<Flashcard>> watchDueFlashcards() => _bus.watch('flashcards', _fetchDue);

  Stream<int> watchDueCount() => watchDueFlashcards().map((cards) => cards.length);

  Future<bool> isAlreadyStudying(String lookupId) async {
    final rows = await _db.db.query('flashcards', where: 'lookupId = ?', whereArgs: [lookupId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> addToStudy({required String lookupId, required String word, required String definition}) async {
    if (await isAlreadyStudying(lookupId)) return;
    final card = Flashcard(
      id: '',
      lookupId: lookupId,
      word: word,
      definition: definition,
      easeFactor: 2.5,
      intervalDays: 0,
      repetitions: 0,
      dueDate: DateTime.now(),
    );
    await _db.db.insert('flashcards', card.toMap());
    _bus.notify('flashcards');
  }

  /// Applies the SM-2 update for [quality] (0-5) and reschedules the card.
  Future<void> reviewCard(Flashcard card, int quality) async {
    final result = computeSm2(
      quality: quality,
      previousEaseFactor: card.easeFactor,
      previousIntervalDays: card.intervalDays,
      previousRepetitions: card.repetitions,
    );
    final dueDate = DateTime.now().add(Duration(days: result.intervalDays));
    await _db.db.update(
      'flashcards',
      {
        'easeFactor': result.easeFactor,
        'intervalDays': result.intervalDays,
        'repetitions': result.repetitions,
        'dueDate': dueDate.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [int.parse(card.id)],
    );
    _bus.notify('flashcards');
  }
}

@riverpod
Future<FlashcardRepository> flashcardRepository(Ref ref) async {
  return FlashcardRepository(await ref.watch(localDatabaseProvider.future), ref.watch(tableChangeBusProvider));
}

@riverpod
Stream<List<Flashcard>> dueFlashcards(Ref ref) async* {
  final repo = await ref.watch(flashcardRepositoryProvider.future);
  yield* repo.watchDueFlashcards();
}

@riverpod
Stream<int> dueFlashcardCount(Ref ref) async* {
  final repo = await ref.watch(flashcardRepositoryProvider.future);
  yield* repo.watchDueCount();
}

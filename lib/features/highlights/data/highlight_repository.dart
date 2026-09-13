import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/local_database.dart';
import '../../../core/data/table_change_bus.dart';
import '../domain/highlight.dart';

part 'highlight_repository.g.dart';

class HighlightRepository {
  HighlightRepository(this._db, this._bus);

  final LocalDatabase _db;
  final TableChangeBus _bus;

  Map<String, dynamic> _decodeRow(Map<String, Object?> row) {
    final map = Map<String, dynamic>.from(row);
    map['documentId'] = map['documentId'].toString();
    if (map['pdfRects'] != null) map['pdfRects'] = jsonDecode(map['pdfRects'] as String);
    return map;
  }

  Future<List<Highlight>> _fetchForDocument(String documentId) async {
    final rows = await _db.db.query(
      'highlights',
      where: 'documentId = ?',
      whereArgs: [int.parse(documentId)],
      orderBy: 'createdAt DESC',
    );
    return rows.map((row) => Highlight.fromMap(row['id'].toString(), _decodeRow(row))).toList();
  }

  Future<List<Highlight>> _fetchAll() async {
    final rows = await _db.db.query('highlights', orderBy: 'createdAt DESC');
    return rows.map((row) => Highlight.fromMap(row['id'].toString(), _decodeRow(row))).toList();
  }

  Stream<List<Highlight>> watchHighlightsForDocument(String documentId) =>
      _bus.watch('highlights', () => _fetchForDocument(documentId));

  Stream<List<Highlight>> watchAllHighlights() => _bus.watch('highlights', _fetchAll);

  Future<void> addHighlight(Highlight highlight) async {
    final map = highlight.toMap();
    await _db.db.insert('highlights', {
      'documentId': int.parse(map['documentId'] as String),
      'documentTitle': map['documentTitle'],
      'page': map['page'],
      'text': map['text'],
      'colorHex': map['colorHex'],
      'startOffset': map['startOffset'],
      'endOffset': map['endOffset'],
      'pdfRects': map['pdfRects'] != null ? jsonEncode(map['pdfRects']) : null,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    _bus.notify('highlights');
  }

  Future<void> deleteHighlight(String highlightId) async {
    await _db.db.delete('highlights', where: 'id = ?', whereArgs: [int.parse(highlightId)]);
    _bus.notify('highlights');
  }
}

@riverpod
Future<HighlightRepository> highlightRepository(Ref ref) async {
  return HighlightRepository(await ref.watch(localDatabaseProvider.future), ref.watch(tableChangeBusProvider));
}

@riverpod
Stream<List<Highlight>> documentHighlights(Ref ref, String documentId) async* {
  final repo = await ref.watch(highlightRepositoryProvider.future);
  yield* repo.watchHighlightsForDocument(documentId);
}

@riverpod
Stream<List<Highlight>> userHighlights(Ref ref) async* {
  final repo = await ref.watch(highlightRepositoryProvider.future);
  yield* repo.watchAllHighlights();
}

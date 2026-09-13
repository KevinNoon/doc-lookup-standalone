import '../../lookup/domain/saved_lookup.dart';

/// All saved lookups for one word, most recent first.
class WordGroup {
  const WordGroup(this.word, this.occurrences);
  final String word;
  final List<SavedLookup> occurrences;
}

/// Groups [lookups] by word (case-insensitive), preserving the order each
/// word first appears in — used both by [SavedLookupsScreen]'s list display
/// and by the Markdown export, so a word saved from more than one source
/// reads as a single entry in both places.
List<WordGroup> groupByWord(List<SavedLookup> lookups) {
  final order = <String>[];
  final byWord = <String, List<SavedLookup>>{};
  for (final lookup in lookups) {
    final key = lookup.word.trim().toLowerCase();
    if (!byWord.containsKey(key)) order.add(key);
    byWord.putIfAbsent(key, () => []).add(lookup);
  }
  return [for (final key in order) WordGroup(byWord[key]!.first.word, byWord[key]!)];
}

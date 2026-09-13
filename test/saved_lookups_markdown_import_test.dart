import 'package:doc_lookup/features/groups_tags/domain/group.dart';
import 'package:doc_lookup/features/lookup/domain/lookup_result.dart';
import 'package:doc_lookup/features/lookup/domain/saved_lookup.dart';
import 'package:doc_lookup/features/search/data/saved_lookups_markdown_export.dart';
import 'package:doc_lookup/features/search/data/saved_lookups_markdown_import.dart';
import 'package:flutter_test/flutter_test.dart';

SavedLookup _lookup({
  required String word,
  String? documentId,
  String? documentTitle,
  int? page,
  QuickLookupResult? quickResult,
  DeepDiveResult? deepDiveResult,
  TranslationResult? translation,
  List<String> groupIds = const [],
  List<String> tags = const [],
}) {
  return SavedLookup(
    id: 'id-$word-$documentId',
    word: word,
    documentId: documentId,
    documentTitle: documentTitle,
    page: page,
    contextSnippet: '',
    quickResult: quickResult,
    deepDiveResult: deepDiveResult,
    translation: translation,
    groupIds: groupIds,
    tags: tags,
    createdAt: null,
  );
}

void main() {
  group('parseSavedLookupsMarkdown', () {
    test('round-trips a full occurrence written by buildSavedLookupsMarkdown', () {
      final original = _lookup(
        word: 'Adoptionism',
        documentId: 'doc1',
        documentTitle: 'Balanced Christianity 1',
        page: 7,
        quickResult: const QuickLookupResult(
          isValidWord: true,
          definition: 'A Christian theological doctrine.',
          partOfSpeech: 'noun',
          shortExample: 'Adoptionism was considered heretical.',
        ),
        deepDiveResult: const DeepDiveResult(
          etymology: 'From Latin adoptio.',
          usageExamples: ['Example one.', 'Example two.'],
          nuance: 'Distinct from Nestorianism.',
          contextAnalysis: 'Used here in a Christological sense.',
        ),
        translation: const TranslationResult(sourceLang: 'la', translatedText: 'adoption'),
        groupIds: ['g1'],
        tags: const ['theology', 'heresy'],
      );
      final groups = [const Group(id: 'g1', name: 'Church', colorHex: '#009688', lookupCount: 0)];

      final markdown = buildSavedLookupsMarkdown([original], groups);
      final parsed = parseSavedLookupsMarkdown(markdown);

      expect(parsed, hasLength(1));
      final result = parsed.single;
      expect(result.word, 'Adoptionism');
      expect(result.documentTitle, 'Balanced Christianity 1');
      expect(result.page, 7);
      expect(result.quickResult?.definition, 'A Christian theological doctrine.');
      expect(result.quickResult?.partOfSpeech, 'noun');
      expect(result.quickResult?.shortExample, 'Adoptionism was considered heretical.');
      expect(result.deepDiveResult?.etymology, 'From Latin adoptio.');
      expect(result.deepDiveResult?.nuance, 'Distinct from Nestorianism.');
      expect(result.deepDiveResult?.contextAnalysis, 'Used here in a Christological sense.');
      expect(result.deepDiveResult?.usageExamples, ['Example one.', 'Example two.']);
      expect(result.translation?.sourceLang, 'la');
      expect(result.translation?.translatedText, 'adoption');
      expect(result.groupNames, ['Church']);
      expect(result.tags, ['theology', 'heresy']);
    });

    test('parses a standalone lookup (no document) with no groups or tags', () {
      final markdown = buildSavedLookupsMarkdown([
        _lookup(
          word: 'serendipity',
          quickResult: const QuickLookupResult(
            isValidWord: true,
            definition: 'A pleasant surprise.',
            partOfSpeech: 'noun',
            shortExample: '',
          ),
        ),
      ], const []);

      final parsed = parseSavedLookupsMarkdown(markdown);

      expect(parsed, hasLength(1));
      expect(parsed.single.word, 'serendipity');
      expect(parsed.single.documentTitle, isNull);
      expect(parsed.single.page, isNull);
      expect(parsed.single.quickResult?.definition, 'A pleasant surprise.');
      expect(parsed.single.groupNames, isEmpty);
      expect(parsed.single.tags, isEmpty);
    });

    test('parses every occurrence of a word saved from multiple sources', () {
      final markdown = buildSavedLookupsMarkdown([
        _lookup(word: 'grace', documentId: 'd1', documentTitle: 'Romans', page: 3),
        _lookup(word: 'grace', documentId: 'd2', documentTitle: 'Ephesians', page: 1),
      ], const []);

      final parsed = parseSavedLookupsMarkdown(markdown);

      expect(parsed, hasLength(2));
      expect(parsed[0].word, 'grace');
      expect(parsed[0].documentTitle, 'Romans');
      expect(parsed[0].page, 3);
      expect(parsed[1].documentTitle, 'Ephesians');
      expect(parsed[1].page, 1);
    });

    test('returns an empty list for a file with no lookups', () {
      final markdown = buildSavedLookupsMarkdown(const [], const []);
      expect(parseSavedLookupsMarkdown(markdown), isEmpty);
    });
  });
}

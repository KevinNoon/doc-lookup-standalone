import 'package:doc_lookup/features/groups_tags/domain/group.dart';
import 'package:doc_lookup/features/lookup/domain/lookup_result.dart';
import 'package:doc_lookup/features/lookup/domain/saved_lookup.dart';
import 'package:doc_lookup/features/search/data/saved_lookups_markdown_export.dart';
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
  String contextSnippet = '',
}) {
  return SavedLookup(
    id: 'id-$word-$documentId',
    word: word,
    documentId: documentId,
    documentTitle: documentTitle,
    page: page,
    contextSnippet: contextSnippet,
    quickResult: quickResult,
    deepDiveResult: deepDiveResult,
    translation: translation,
    groupIds: groupIds,
    tags: tags,
    createdAt: null,
  );
}

void main() {
  group('buildSavedLookupsMarkdown', () {
    test('groups occurrences of the same word under one heading', () {
      final lookups = [
        _lookup(
          word: 'Adoptionism',
          documentId: 'doc1',
          documentTitle: 'Balanced Christianity 1',
          page: 7,
          quickResult: const QuickLookupResult(
            isValidWord: true,
            definition: 'A Christian theological doctrine...',
            partOfSpeech: 'noun',
            shortExample: 'Adoptionism was considered heretical.',
          ),
        ),
        _lookup(word: 'Adoptionism', documentId: null, documentTitle: null, page: null),
      ];

      final markdown = buildSavedLookupsMarkdown(lookups, const []);

      expect('## Adoptionism'.allMatches(markdown).length, 1);
      expect(markdown, contains('### Balanced Christianity 1 — p. 7'));
      expect(markdown, contains('### Standalone lookup'));
      expect(markdown, contains('**noun** — A Christian theological doctrine...'));
      expect(markdown, contains('"Adoptionism was considered heretical."'));
      expect(markdown, contains('2 occurrences'));
      expect(markdown, contains('1 word,'));
    });

    test('includes deep dive, translation, groups, and tags when present', () {
      final lookups = [
        _lookup(
          word: 'Sanctification',
          documentId: 'doc2',
          documentTitle: 'Theology 101',
          page: 3,
          deepDiveResult: const DeepDiveResult(
            etymology: 'From Latin sanctus.',
            usageExamples: ['Example one.', 'Example two.'],
            nuance: 'Distinct from justification.',
            contextAnalysis: 'Used here in a soteriological sense.',
          ),
          translation: const TranslationResult(sourceLang: 'la', translatedText: 'holiness'),
          groupIds: ['g1'],
          tags: const ['theology', 'core'],
        ),
      ];
      final groups = [const Group(id: 'g1', name: 'Church', colorHex: '#009688', lookupCount: 0)];

      final markdown = buildSavedLookupsMarkdown(lookups, groups);

      expect(markdown, contains('**Etymology:** From Latin sanctus.'));
      expect(markdown, contains('**Nuance:** Distinct from justification.'));
      expect(markdown, contains('**In this context:** Used here in a soteriological sense.'));
      expect(markdown, contains('- Example one.'));
      expect(markdown, contains('- Example two.'));
      expect(markdown, contains('**Translation (la):** holiness'));
      expect(markdown, contains('**Groups:** Church'));
      expect(markdown, contains('**Tags:** theology, core'));
    });

    test('produces a header with correct counts for an empty list', () {
      final markdown = buildSavedLookupsMarkdown(const [], const []);
      expect(markdown, contains('0 words, 0 occurrences'));
    });
  });
}

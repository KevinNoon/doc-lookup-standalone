import 'lookup_result.dart';

class SavedLookup {
  const SavedLookup({
    required this.id,
    required this.word,
    required this.documentId,
    required this.documentTitle,
    required this.page,
    required this.contextSnippet,
    required this.quickResult,
    required this.deepDiveResult,
    required this.translation,
    required this.groupIds,
    required this.tags,
    required this.createdAt,
  });

  factory SavedLookup.fromMap(String id, Map<String, dynamic> map) {
    final quick = map['quickResult'] as Map<String, dynamic>?;
    final deepDive = map['deepDiveResult'] as Map<String, dynamic>?;
    final translation = map['translation'] as Map<String, dynamic>?;
    return SavedLookup(
      id: id,
      word: map['word'] as String? ?? '',
      documentId: map['documentId'] as String?,
      documentTitle: map['documentTitle'] as String?,
      page: map['page'] as int?,
      contextSnippet: map['contextSnippet'] as String? ?? '',
      quickResult: quick == null ? null : QuickLookupResult.fromJson(quick),
      deepDiveResult: deepDive == null ? null : DeepDiveResult.fromJson(deepDive),
      translation: translation == null ? null : TranslationResult.fromJson(translation),
      groupIds: (map['groupIds'] as List?)?.cast<String>() ?? const [],
      tags: (map['tags'] as List?)?.cast<String>() ?? const [],
      createdAt: map['createdAt'],
    );
  }

  final String id;
  final String word;

  /// Null for a lookup created from the standalone "look up a word" entry
  /// point (not tied to any document that was open at the time).
  final String? documentId;
  final String? documentTitle;
  final int? page;
  final String contextSnippet;
  final QuickLookupResult? quickResult;
  final DeepDiveResult? deepDiveResult;
  final TranslationResult? translation;
  final List<String> groupIds;
  final List<String> tags;
  final Object? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'documentId': documentId,
      'documentTitle': documentTitle,
      'page': page,
      'contextSnippet': contextSnippet,
      if (quickResult != null)
        'quickResult': {
          'isValidWord': quickResult!.isValidWord,
          'definition': quickResult!.definition,
          'partOfSpeech': quickResult!.partOfSpeech,
          'shortExample': quickResult!.shortExample,
        },
      if (deepDiveResult != null)
        'deepDiveResult': {
          'etymology': deepDiveResult!.etymology,
          'usageExamples': deepDiveResult!.usageExamples,
          'nuance': deepDiveResult!.nuance,
          'contextAnalysis': deepDiveResult!.contextAnalysis,
        },
      if (translation != null)
        'translation': {
          'sourceLang': translation!.sourceLang,
          'translatedText': translation!.translatedText,
        },
      'groupIds': groupIds,
      'tags': tags,
    };
  }
}

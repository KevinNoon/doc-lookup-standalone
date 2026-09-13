import '../../lookup/domain/lookup_result.dart';

/// One lookup parsed out of a Markdown file written by
/// `buildSavedLookupsMarkdown` — the counterpart parser, used to restore or
/// migrate saved lookups (e.g. an export taken on another install of this
/// app, or the cloud-synced sibling app). [groupNames] are plain group
/// names as written in the file — the importer resolves or creates matching
/// local groups by name, since group IDs from the source install mean
/// nothing here. The original `contextSnippet` (the source document's
/// surrounding text) is intentionally not reconstructed — it's the one
/// field in the export that can itself contain blank lines, which would
/// make parsing it back out unreliable, and it's not shown anywhere once a
/// lookup is saved, only used to ground the original AI call.
class ParsedSavedLookup {
  const ParsedSavedLookup({
    required this.word,
    required this.documentTitle,
    required this.page,
    required this.quickResult,
    required this.deepDiveResult,
    required this.translation,
    required this.groupNames,
    required this.tags,
  });

  final String word;
  final String? documentTitle;
  final int? page;
  final QuickLookupResult? quickResult;
  final DeepDiveResult? deepDiveResult;
  final TranslationResult? translation;
  final List<String> groupNames;
  final List<String> tags;
}

final _translationPattern = RegExp(r'^\*\*Translation \(([^)]*)\):\*\* (.*)$');
final _headingPattern = RegExp(r'^(.*) — p\. (\d+)$');
final _quickResultPattern = RegExp(r'^\*\*(.+?)\*\* — (.*)$');

/// Parses Markdown produced by `buildSavedLookupsMarkdown` back into a list
/// of lookups, one per `###` occurrence — not deduplicated or merged here;
/// each becomes its own saved occurrence, the same as any other save.
List<ParsedSavedLookup> parseSavedLookupsMarkdown(String markdown) {
  final lookups = <ParsedSavedLookup>[];
  final wordSections = ('\n$markdown').split('\n## ').skip(1);
  for (final wordSection in wordSections) {
    final wordLines = wordSection.split('\n');
    final word = wordLines.first.trim();
    if (word.isEmpty) continue;
    final wordBody = wordLines.skip(1).join('\n');

    final occurrenceSections = ('\n$wordBody').split('\n### ').skip(1);
    for (final occSection in occurrenceSections) {
      final occLines = occSection.split('\n');
      final heading = occLines.first.trim();
      lookups.add(_parseOccurrence(word, heading, occLines.skip(1)));
    }
  }
  return lookups;
}

ParsedSavedLookup _parseOccurrence(String word, String heading, Iterable<String> bodyLines) {
  String? documentTitle;
  int? page;
  if (heading != 'Standalone lookup') {
    final match = _headingPattern.firstMatch(heading);
    if (match != null) {
      documentTitle = match.group(1);
      page = int.tryParse(match.group(2)!);
    } else {
      documentTitle = heading;
    }
  }

  String? partOfSpeech;
  String? definition;
  String? shortExample;
  String? translationLang;
  String? translationText;
  String? etymology;
  String? nuance;
  String? contextAnalysis;
  final usageExamples = <String>[];
  var groupNames = const <String>[];
  var tags = const <String>[];

  var inUsageExamples = false;
  var quickCaptured = false;

  for (final line in bodyLines) {
    final trimmed = line.trim();

    if (trimmed.startsWith('**Groups:**')) {
      groupNames = _splitCsv(trimmed.substring('**Groups:**'.length));
      inUsageExamples = false;
      continue;
    }
    if (trimmed.startsWith('**Tags:**')) {
      tags = _splitCsv(trimmed.substring('**Tags:**'.length));
      inUsageExamples = false;
      continue;
    }
    if (trimmed == '---') break;

    if (trimmed.startsWith('> "') && trimmed.endsWith('"')) {
      shortExample = trimmed.substring(3, trimmed.length - 1);
      inUsageExamples = false;
      continue;
    }
    final translationMatch = _translationPattern.firstMatch(trimmed);
    if (translationMatch != null) {
      translationLang = translationMatch.group(1);
      translationText = translationMatch.group(2);
      inUsageExamples = false;
      continue;
    }
    if (trimmed.startsWith('**Etymology:**')) {
      etymology = trimmed.substring('**Etymology:**'.length).trim();
      inUsageExamples = false;
      continue;
    }
    if (trimmed.startsWith('**Nuance:**')) {
      nuance = trimmed.substring('**Nuance:**'.length).trim();
      inUsageExamples = false;
      continue;
    }
    if (trimmed.startsWith('**In this context:**')) {
      contextAnalysis = trimmed.substring('**In this context:**'.length).trim();
      inUsageExamples = false;
      continue;
    }
    if (trimmed == '**Usage examples:**') {
      inUsageExamples = true;
      continue;
    }
    if (inUsageExamples && trimmed.startsWith('- ')) {
      usageExamples.add(trimmed.substring(2).trim());
      continue;
    }
    if (trimmed.startsWith('**Context:**')) {
      // Intentionally dropped — see the class doc comment.
      inUsageExamples = false;
      continue;
    }
    if (inUsageExamples) {
      inUsageExamples = false;
      continue;
    }
    if (!quickCaptured && trimmed.isNotEmpty) {
      final posMatch = _quickResultPattern.firstMatch(trimmed);
      if (posMatch != null) {
        partOfSpeech = posMatch.group(1);
        definition = posMatch.group(2);
      } else {
        definition = trimmed;
      }
      quickCaptured = true;
    }
  }

  final quickResult = definition == null
      ? null
      : QuickLookupResult(
          isValidWord: true,
          definition: definition,
          partOfSpeech: partOfSpeech ?? '',
          shortExample: shortExample ?? '',
        );
  final deepDiveResult = (etymology == null && nuance == null && contextAnalysis == null && usageExamples.isEmpty)
      ? null
      : DeepDiveResult(
          etymology: etymology ?? '',
          usageExamples: usageExamples,
          nuance: nuance ?? '',
          contextAnalysis: contextAnalysis ?? '',
        );
  final translation = (translationLang == null || translationText == null)
      ? null
      : TranslationResult(sourceLang: translationLang, translatedText: translationText);

  return ParsedSavedLookup(
    word: word,
    documentTitle: documentTitle,
    page: page,
    quickResult: quickResult,
    deepDiveResult: deepDiveResult,
    translation: translation,
    groupNames: groupNames,
    tags: tags,
  );
}

List<String> _splitCsv(String value) {
  return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

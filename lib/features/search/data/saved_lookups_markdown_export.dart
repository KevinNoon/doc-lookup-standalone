import '../../groups_tags/domain/group.dart';
import '../../lookup/domain/saved_lookup.dart';
import '../domain/word_group.dart';

/// Renders every saved lookup in [lookups] as a single Markdown document —
/// one `##` section per word (grouped the same way [SavedLookupsScreen]
/// groups them for display) and one `###` subsection per occurrence, mirroring
/// the fields shown in [SavedLookupDetailSheet] so the export reads like a
/// plain-text copy of what's already on screen.
String buildSavedLookupsMarkdown(List<SavedLookup> lookups, List<Group> groups) {
  final wordGroups = groupByWord(lookups);
  final buffer = StringBuffer()
    ..writeln('# Saved Lookups')
    ..writeln()
    ..writeln(
      '_${wordGroups.length} word${wordGroups.length == 1 ? '' : 's'}, '
      '${lookups.length} occurrence${lookups.length == 1 ? '' : 's'} — '
      'exported ${_formatDate(DateTime.now())}_',
    )
    ..writeln();

  for (final wordGroup in wordGroups) {
    buffer
      ..writeln('## ${wordGroup.word}')
      ..writeln();
    for (final lookup in wordGroup.occurrences) {
      _writeOccurrence(buffer, lookup, groups);
    }
  }
  return buffer.toString();
}

void _writeOccurrence(StringBuffer buffer, SavedLookup lookup, List<Group> groups) {
  final heading = lookup.documentId == null
      ? 'Standalone lookup'
      : '${lookup.documentTitle ?? 'Unknown document'} — p. ${lookup.page}';
  buffer
    ..writeln('### $heading')
    ..writeln();

  final quick = lookup.quickResult;
  if (quick != null) {
    final pos = quick.partOfSpeech.isEmpty ? '' : '**${quick.partOfSpeech}** — ';
    buffer
      ..writeln('$pos${quick.definition}')
      ..writeln();
    if (quick.shortExample.isNotEmpty) {
      buffer
        ..writeln('> "${quick.shortExample}"')
        ..writeln();
    }
  }

  final translation = lookup.translation;
  if (translation != null) {
    buffer
      ..writeln('**Translation (${translation.sourceLang}):** ${translation.translatedText}')
      ..writeln();
  }

  final deepDive = lookup.deepDiveResult;
  if (deepDive != null) {
    buffer
      ..writeln('**Etymology:** ${deepDive.etymology}')
      ..writeln()
      ..writeln('**Nuance:** ${deepDive.nuance}')
      ..writeln()
      ..writeln('**In this context:** ${deepDive.contextAnalysis}')
      ..writeln();
    if (deepDive.usageExamples.isNotEmpty) {
      buffer.writeln('**Usage examples:**');
      for (final example in deepDive.usageExamples) {
        buffer.writeln('- $example');
      }
      buffer.writeln();
    }
  }

  if (lookup.contextSnippet.isNotEmpty) {
    buffer
      ..writeln('**Context:** ${lookup.contextSnippet}')
      ..writeln();
  }

  final groupNames = [
    for (final id in lookup.groupIds) ...groups.where((g) => g.id == id).map((g) => g.name),
  ];
  if (groupNames.isNotEmpty) buffer.writeln('**Groups:** ${groupNames.join(', ')}');
  if (lookup.tags.isNotEmpty) buffer.writeln('**Tags:** ${lookup.tags.join(', ')}');

  buffer
    ..writeln()
    ..writeln('---')
    ..writeln();
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

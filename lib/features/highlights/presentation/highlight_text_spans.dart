import 'package:flutter/material.dart';

import '../domain/highlight.dart';

/// Splits [pageText] into [TextSpan]s, applying a colored background to each
/// highlight's [Highlight.startOffset]..[Highlight.endOffset] range.
/// Highlights are processed in start-offset order; one that overlaps the
/// span already consumed by an earlier highlight is skipped — overlapping
/// highlights aren't a case the highlight UI can create today, so this is
/// just a defensive fallback rather than a real merge.
List<InlineSpan> buildHighlightedTextSpans(
  String pageText,
  List<Highlight> highlightsOnPage,
  TextStyle? baseStyle,
) {
  final ranges = highlightsOnPage.where((h) => h.startOffset != null && h.endOffset != null).toList()
    ..sort((a, b) => a.startOffset!.compareTo(b.startOffset!));

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final highlight in ranges) {
    final start = highlight.startOffset!.clamp(0, pageText.length);
    final end = highlight.endOffset!.clamp(0, pageText.length);
    if (start < cursor || end <= start) continue;

    if (start > cursor) {
      spans.add(TextSpan(text: pageText.substring(cursor, start), style: baseStyle));
    }
    spans.add(TextSpan(
      text: pageText.substring(start, end),
      style: (baseStyle ?? const TextStyle()).copyWith(backgroundColor: colorFromHex(highlight.colorHex)),
    ));
    cursor = end;
  }
  if (cursor < pageText.length) {
    spans.add(TextSpan(text: pageText.substring(cursor), style: baseStyle));
  }

  return spans;
}

Color colorFromHex(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.parse(normalized.length == 6 ? 'FF$normalized' : normalized, radix: 16);
  return Color(value);
}

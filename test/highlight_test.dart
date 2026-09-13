import 'package:doc_lookup/features/documents/data/epub_parser.dart';
import 'package:doc_lookup/features/highlights/domain/highlight.dart';
import 'package:doc_lookup/features/highlights/presentation/highlight_text_spans.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Highlight _highlight({
  required String text,
  String colorHex = '#FFF59D',
  int page = 1,
  int? startOffset,
  int? endOffset,
}) {
  return Highlight(
    id: 'h1',
    documentId: 'doc1',
    documentTitle: 'Doc One',
    page: page,
    text: text,
    colorHex: colorHex,
    createdAt: null,
    startOffset: startOffset,
    endOffset: endOffset,
  );
}

void main() {
  group('Highlight.toMap / fromMap', () {
    test('round-trips a TXT/DOCX offset-based highlight', () {
      final highlight = _highlight(text: 'serendipity', startOffset: 10, endOffset: 21);
      final restored = Highlight.fromMap('h1', highlight.toMap());

      expect(restored.documentId, 'doc1');
      expect(restored.documentTitle, 'Doc One');
      expect(restored.page, 1);
      expect(restored.text, 'serendipity');
      expect(restored.colorHex, '#FFF59D');
      expect(restored.startOffset, 10);
      expect(restored.endOffset, 21);
      expect(restored.pdfRects, isNull);
    });

    test('round-trips a PDF rect-based highlight', () {
      final highlight = Highlight(
        id: 'h2',
        documentId: 'doc1',
        documentTitle: 'Doc One',
        page: 3,
        text: 'ebullient',
        colorHex: '#A5D6A7',
        createdAt: null,
        pdfRects: const [PdfHighlightRect(left: 1, top: 2, right: 3, bottom: 4, text: 'ebullient')],
      );
      final restored = Highlight.fromMap('h2', highlight.toMap());

      expect(restored.pdfRects, hasLength(1));
      expect(restored.pdfRects!.first.left, 1);
      expect(restored.pdfRects!.first.text, 'ebullient');
      expect(restored.startOffset, isNull);
    });
  });

  group('buildHighlightedTextSpans', () {
    test('applies a background color only to the highlighted range', () {
      final spans = buildHighlightedTextSpans(
        'Hello serendipity world',
        [_highlight(text: 'serendipity', startOffset: 6, endOffset: 17)],
        const TextStyle(fontSize: 14),
      );

      final texts = spans.map((s) => (s as TextSpan).text).toList();
      expect(texts, ['Hello ', 'serendipity', ' world']);
      expect((spans[1] as TextSpan).style?.backgroundColor, colorFromHex('#FFF59D'));
      expect((spans[0] as TextSpan).style?.backgroundColor, isNull);
    });

    test('skips a highlight that overlaps an already-consumed range', () {
      final spans = buildHighlightedTextSpans(
        'abcdefgh',
        [
          _highlight(text: 'abcd', startOffset: 0, endOffset: 4),
          _highlight(text: 'bcde', startOffset: 1, endOffset: 5),
        ],
        null,
      );

      final texts = spans.map((s) => (s as TextSpan).text).toList();
      expect(texts, ['abcd', 'efgh']);
    });
  });

  group('applyHighlightsToHtml', () {
    test('wraps the first literal occurrence of the highlight text in a span', () {
      final html = '<p>Hello serendipity world</p>';
      final result = applyHighlightsToHtml(html, [_highlight(text: 'serendipity')]);

      expect(
        result,
        '<p>Hello <span style="background-color: #FFF59D">serendipity</span> world</p>',
      );
    });

    test('leaves html unchanged when the highlight text is not found verbatim', () {
      final html = '<p>Hello world</p>';
      final result = applyHighlightsToHtml(html, [_highlight(text: 'missing')]);

      expect(result, html);
    });
  });
}

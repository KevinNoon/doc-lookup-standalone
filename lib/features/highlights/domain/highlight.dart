/// Preset highlighter colors offered in the highlight color picker (pastel
/// yellow, green, blue, pink, orange), as `#RRGGBB` hex strings.
const highlightColorPalette = <String>['#FFF59D', '#A5D6A7', '#90CAF9', '#F48FB1', '#FFCC80'];

/// A highlighted rectangle for one line of selected PDF text, in page-space
/// coordinates (as returned by Syncfusion's `PdfTextLine.bounds`). Stored so
/// the highlight can be reconstructed into a real `HighlightAnnotation` on
/// reload without needing the original live selection.
class PdfHighlightRect {
  const PdfHighlightRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.text,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final String text;

  factory PdfHighlightRect.fromMap(Map<String, dynamic> map) {
    return PdfHighlightRect(
      left: (map['left'] as num).toDouble(),
      top: (map['top'] as num).toDouble(),
      right: (map['right'] as num).toDouble(),
      bottom: (map['bottom'] as num).toDouble(),
      text: map['text'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
        'text': text,
      };
}

/// A user-created highlight on a document.
///
/// Rendering differs by format: PDF reconstructs native
/// `HighlightAnnotation`s from [pdfRects]; EPUB and DOCX inject a styled
/// `<span>` around the first literal occurrence of [text] in the page's
/// HTML; TXT highlights the exact [startOffset]..[endOffset] range of the
/// page's plain text. Only the fields relevant to the document's format are
/// populated. [documentTitle] is denormalized at creation time (same
/// approach as `SavedLookup.documentTitle`) so the highlights-review screen
/// can list highlights without joining against the documents collection.
class Highlight {
  const Highlight({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.page,
    required this.text,
    required this.colorHex,
    required this.createdAt,
    this.startOffset,
    this.endOffset,
    this.pdfRects,
  });

  final String id;
  final String documentId;
  final String documentTitle;
  final int page;
  final String text;
  final String colorHex;
  final DateTime? createdAt;

  /// TXT only: character offsets within that page's plain text.
  final int? startOffset;
  final int? endOffset;

  /// PDF only: one rect per selected text line.
  final List<PdfHighlightRect>? pdfRects;

  factory Highlight.fromMap(String id, Map<String, dynamic> map) {
    final rectMaps = map['pdfRects'] as List<dynamic>?;
    return Highlight(
      id: id,
      documentId: map['documentId'] as String,
      documentTitle: map['documentTitle'] as String? ?? '',
      page: map['page'] as int,
      text: map['text'] as String,
      colorHex: map['colorHex'] as String,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : null,
      startOffset: map['startOffset'] as int?,
      endOffset: map['endOffset'] as int?,
      pdfRects: rectMaps?.map((r) => PdfHighlightRect.fromMap(r as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'documentId': documentId,
        'documentTitle': documentTitle,
        'page': page,
        'text': text,
        'colorHex': colorHex,
        if (startOffset != null) 'startOffset': startOffset,
        if (endOffset != null) 'endOffset': endOffset,
        if (pdfRects != null) 'pdfRects': pdfRects!.map((r) => r.toMap()).toList(),
      };
}

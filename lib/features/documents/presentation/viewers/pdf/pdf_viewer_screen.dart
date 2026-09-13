import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../highlights/data/highlight_repository.dart';
import '../../../../highlights/domain/highlight.dart';
import '../../../../highlights/presentation/highlight_text_spans.dart' show colorFromHex;
import '../../../../lookup/presentation/lookup_sheet.dart';
import '../../../../../shared/utils/clean_selected_text.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.filePath,
  });

  final String documentId;
  final String title;
  final String filePath;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  final _controller = PdfViewerController();
  final _pdfViewerKey = GlobalKey<SfPdfViewerState>();
  Timer? _selectionDebounce;
  PdfDocument? _textDocument;
  bool _documentLoaded = false;
  final _annotatedHighlightIds = <String>{};
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void dispose() {
    _selectionDebounce?.cancel();
    _textDocument?.dispose();
    super.dispose();
  }

  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    final selectedText = details.selectedText;
    _selectionDebounce?.cancel();
    if (selectedText == null || selectedText.trim().isEmpty) return;
    final cleaned = cleanSelectedText(selectedText);
    if (cleaned.isEmpty) return;

    _selectionDebounce = Timer(const Duration(milliseconds: 500), () {
      _showLookupFor(cleaned);
    });
  }

  Future<void> _showLookupFor(String word) async {
    if (!mounted) return;
    final page = _controller.pageNumber;
    final contextSnippet = await _extractPageContext();
    final selectedLines = _pdfViewerKey.currentState?.getSelectedTextLines() ?? const <PdfTextLine>[];
    if (!mounted) return;

    await showLookupSheet(
      context,
      word: word,
      contextSnippet: contextSnippet,
      documentId: widget.documentId,
      documentTitle: widget.title,
      page: page,
      onHighlight: selectedLines.isEmpty
          ? null
          : (colorHex) async {
              final repo = await ref.read(highlightRepositoryProvider.future);
              await repo.addHighlight(
                Highlight(
                  id: '',
                  documentId: widget.documentId,
                  documentTitle: widget.title,
                  page: selectedLines.first.pageNumber,
                  text: word,
                  colorHex: colorHex,
                  createdAt: null,
                  pdfRects: selectedLines
                      .map((line) => PdfHighlightRect(
                            left: line.bounds.left,
                            top: line.bounds.top,
                            right: line.bounds.right,
                            bottom: line.bounds.bottom,
                            text: line.text,
                          ))
                      .toList(),
                ),
              );
            },
    );
  }

  Future<String> _extractPageContext() async {
    try {
      _textDocument ??= PdfDocument(inputBytes: await File(widget.filePath).readAsBytes());
      final pageIndex = _controller.pageNumber - 1;
      return PdfTextExtractor(_textDocument!).extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
    } catch (_) {
      return '';
    }
  }

  /// Reconstructs and adds a native [HighlightAnnotation] for each highlight
  /// not already rendered. Safe to call repeatedly as the highlights stream
  /// emits — [_annotatedHighlightIds] prevents the same highlight being
  /// added twice (once optimistically, once again once Firestore confirms
  /// the write and the stream re-emits).
  void _renderNewHighlights(List<Highlight> highlights) {
    if (!_documentLoaded) return;
    for (final highlight in highlights) {
      if (_annotatedHighlightIds.contains(highlight.id)) continue;
      final rects = highlight.pdfRects;
      if (rects == null || rects.isEmpty) continue;

      final textLines = rects
          .map((r) => PdfTextLine(Rect.fromLTRB(r.left, r.top, r.right, r.bottom), r.text, highlight.page))
          .toList();
      final annotation = HighlightAnnotation(textBoundsCollection: textLines)
        ..color = colorFromHex(highlight.colorHex).withAlpha(160);
      _controller.addAnnotation(annotation);
      _annotatedHighlightIds.add(highlight.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(documentHighlightsProvider(widget.documentId), (previous, next) {
      next.whenData(_renderNewHighlights);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: _totalPages > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Page $_currentPage of $_totalPages',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            : null,
      ),
      body: SfPdfViewer.file(
        File(widget.filePath),
        key: _pdfViewerKey,
        controller: _controller,
        canShowTextSelectionMenu: false,
        onTextSelectionChanged: _onTextSelectionChanged,
        onPageChanged: (details) => setState(() => _currentPage = details.newPageNumber),
        onDocumentLoaded: (details) {
          _documentLoaded = true;
          setState(() {
            _currentPage = _controller.pageNumber;
            _totalPages = details.document.pages.count;
          });
          final highlights = ref.read(documentHighlightsProvider(widget.documentId)).value;
          if (highlights != null) _renderNewHighlights(highlights);
        },
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../../../../highlights/data/highlight_repository.dart';
import '../../../../highlights/domain/highlight.dart';
import '../../../../lookup/presentation/lookup_sheet.dart';
import '../../../../../shared/utils/clean_selected_text.dart';
import '../../../data/epub_parser.dart' show applyHighlightsToHtml, stripHtmlToText;

/// Shared paginated HTML reader used by any format whose content is richer
/// than flat text but has no built-in page geometry to anchor selection
/// against (EPUB chapters, DOCX paragraphs converted to HTML). Handles the
/// debounced text-selection -> lookup-sheet flow and highlight
/// rendering/creation identically for both.
class PaginatedHtmlViewerScreen extends ConsumerStatefulWidget {
  const PaginatedHtmlViewerScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.loadPages,
    this.pageLabel = 'Page',
    this.errorPrefix = 'Could not open this file',
  });

  final String documentId;
  final String title;
  final Future<List<String>> Function() loadPages;
  final String pageLabel;
  final String errorPrefix;

  @override
  ConsumerState<PaginatedHtmlViewerScreen> createState() => _PaginatedHtmlViewerScreenState();
}

enum _LoadState { loading, ready, error }

class _PaginatedHtmlViewerScreenState extends ConsumerState<PaginatedHtmlViewerScreen> {
  final _pageController = PageController();
  Timer? _selectionDebounce;
  _LoadState _state = _LoadState.loading;
  List<String> _pages = const [];
  String? _errorMessage;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pages = await widget.loadPages();
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _state = _LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e';
        _state = _LoadState.error;
      });
    }
  }

  @override
  void dispose() {
    _selectionDebounce?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onSelectionChanged(SelectedContent? content) {
    final selectedText = content?.plainText;
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
    final pageIndex = _currentPageIndex;
    final contextSnippet = stripHtmlToText(_pages[pageIndex]);

    await showLookupSheet(
      context,
      word: word,
      contextSnippet: contextSnippet,
      documentId: widget.documentId,
      documentTitle: widget.title,
      page: pageIndex + 1,
      onHighlight: (colorHex) async {
        final repo = await ref.read(highlightRepositoryProvider.future);
        await repo.addHighlight(
          Highlight(
            id: '',
            documentId: widget.documentId,
            documentTitle: widget.title,
            page: pageIndex + 1,
            text: word,
            colorHex: colorHex,
            createdAt: null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: _state == _LoadState.ready
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${widget.pageLabel} ${_currentPageIndex + 1} of ${_pages.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${widget.errorPrefix}: $_errorMessage'),
          ),
        );
      case _LoadState.ready:
        final highlightsAsync = ref.watch(documentHighlightsProvider(widget.documentId));
        final highlights = highlightsAsync.value ?? const <Highlight>[];

        return PageView.builder(
          controller: _pageController,
          itemCount: _pages.length,
          onPageChanged: (index) => setState(() => _currentPageIndex = index),
          itemBuilder: (context, index) {
            final pageHighlights = highlights.where((h) => h.page == index + 1).toList();
            final html = applyHighlightsToHtml(_pages[index], pageHighlights);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectionArea(
                contextMenuBuilder: (context, state) => const SizedBox.shrink(),
                onSelectionChanged: _onSelectionChanged,
                child: HtmlWidget(html),
              ),
            );
          },
        );
    }
  }
}

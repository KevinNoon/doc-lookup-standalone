import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../highlights/data/highlight_repository.dart';
import '../../../../highlights/domain/highlight.dart';
import '../../../../highlights/presentation/highlight_text_spans.dart';
import '../../../../lookup/presentation/lookup_sheet.dart';
import '../../../../../shared/utils/clean_selected_text.dart';

/// Shared paginated plain-text reader used by any format that ends up as a
/// flat string with no native page/chapter structure (TXT, and DOCX after
/// its formatting is stripped during extraction). Handles the debounced
/// text-selection -> lookup-sheet flow, and highlight rendering/creation,
/// identically to the PDF/EPUB viewers.
class PaginatedTextViewerScreen extends ConsumerStatefulWidget {
  const PaginatedTextViewerScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.loadText,
    this.errorPrefix = 'Could not open this file',
  });

  final String documentId;
  final String title;
  final Future<String> Function() loadText;
  final String errorPrefix;

  @override
  ConsumerState<PaginatedTextViewerScreen> createState() => _PaginatedTextViewerScreenState();
}

enum _LoadState { loading, ready, error }

/// Characters per page. There's no natural page boundary for flat text, so
/// this just chunks it to keep each page's DOM/context size reasonable
/// rather than rendering the whole document as one giant selectable block.
const _charsPerPage = 3000;

class _PaginatedTextViewerScreenState extends ConsumerState<PaginatedTextViewerScreen> {
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
      final content = await widget.loadText();
      if (!mounted) return;
      setState(() {
        _pages = _paginate(content);
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

  /// Chunks [content] into pages of roughly [_charsPerPage] characters,
  /// breaking at the nearest preceding whitespace rather than mid-word so a
  /// long word never gets split across a page boundary.
  List<String> _paginate(String content) {
    if (content.isEmpty) return [''];
    final pages = <String>[];
    var start = 0;
    while (start < content.length) {
      var end = start + _charsPerPage;
      if (end >= content.length) {
        end = content.length;
      } else {
        final breakPoint = content.lastIndexOf(RegExp(r'\s'), end);
        if (breakPoint > start) end = breakPoint + 1;
      }
      pages.add(content.substring(start, end));
      start = end;
    }
    return pages;
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
    final pageText = _pages[pageIndex];
    final offset = pageText.indexOf(word);

    await showLookupSheet(
      context,
      word: word,
      contextSnippet: pageText,
      documentId: widget.documentId,
      documentTitle: widget.title,
      page: pageIndex + 1,
      onHighlight: offset == -1
          ? null
          : (colorHex) async {
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
                  startOffset: offset,
                  endOffset: offset + word.length,
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
                    'Page ${_currentPageIndex + 1} of ${_pages.length}',
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
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectionArea(
                contextMenuBuilder: (context, state) => const SizedBox.shrink(),
                onSelectionChanged: _onSelectionChanged,
                child: Text.rich(
                  TextSpan(
                    children: buildHighlightedTextSpans(
                      _pages[index],
                      pageHighlights,
                      DefaultTextStyle.of(context).style,
                    ),
                  ),
                ),
              ),
            );
          },
        );
    }
  }
}

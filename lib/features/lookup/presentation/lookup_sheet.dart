import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups_tags/presentation/save_lookup_sheet.dart';
import '../../highlights/domain/highlight.dart';
import '../data/ai_lookup_repository.dart';
import '../data/saved_lookup_repository.dart';
import '../domain/lookup_result.dart';
import '../domain/saved_lookup.dart';

/// Shows the quick-lookup / deep-dive bottom sheet for [word], using
/// [contextSnippet] (surrounding text) to ground the AI's answer.
///
/// [onHighlight], if given, adds a "Highlight" action that lets the user
/// mark [word]'s selection with a color; each viewer supplies its own
/// implementation since what needs to be persisted (PDF rects vs. plain-text
/// offsets vs. an HTML snippet) is format-specific.
Future<void> showLookupSheet(
  BuildContext context, {
  required String word,
  required String contextSnippet,
  required String? documentId,
  required String? documentTitle,
  required int? page,
  Future<void> Function(String colorHex)? onHighlight,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => LookupSheet(
      word: word,
      contextSnippet: contextSnippet,
      documentId: documentId,
      documentTitle: documentTitle,
      page: page,
      onHighlight: onHighlight,
    ),
  );
}

class LookupSheet extends ConsumerStatefulWidget {
  const LookupSheet({
    super.key,
    required this.word,
    required this.contextSnippet,
    required this.documentId,
    required this.documentTitle,
    required this.page,
    this.onHighlight,
  });

  final String word;
  final String contextSnippet;
  final String? documentId;
  final String? documentTitle;
  final int? page;
  final Future<void> Function(String colorHex)? onHighlight;

  @override
  ConsumerState<LookupSheet> createState() => _LookupSheetState();
}

enum _Stage { loadingQuick, quickReady, loadingDeepDive, deepDiveReady, error }

enum _TranslationStage { idle, loading, ready, error }

class _LookupSheetState extends ConsumerState<LookupSheet> {
  _Stage _stage = _Stage.loadingQuick;
  QuickLookupResult? _quickResult;
  DeepDiveResult? _deepDiveResult;
  String? _errorMessage;
  bool _isSaved = false;
  bool _isHighlighted = false;
  bool _showColorPicker = false;

  _TranslationStage _translationStage = _TranslationStage.idle;
  TranslationResult? _translation;
  String? _translationError;

  @override
  void initState() {
    super.initState();
    _loadQuickResult();
  }

  Future<void> _loadQuickResult() async {
    setState(() {
      _stage = _Stage.loadingQuick;
      _errorMessage = null;
    });
    try {
      final repo = await ref.read(aiLookupRepositoryProvider.future);
      final result = await repo.quickLookup(word: widget.word, contextSnippet: widget.contextSnippet);
      if (mounted) {
        setState(() {
          _quickResult = result;
          _stage = _Stage.quickReady;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
          _stage = _Stage.error;
        });
      }
    }
  }

  Future<void> _loadDeepDive() async {
    setState(() => _stage = _Stage.loadingDeepDive);
    try {
      final repo = await ref.read(aiLookupRepositoryProvider.future);
      final result = await repo.deepDive(
        word: widget.word,
        contextSnippet: widget.contextSnippet,
        quickDefinition: _quickResult?.definition,
      );
      if (mounted) {
        setState(() {
          _deepDiveResult = result;
          _stage = _Stage.deepDiveReady;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
          _stage = _Stage.error;
        });
      }
    }
  }

  Future<void> _loadTranslation() async {
    setState(() => _translationStage = _TranslationStage.loading);
    try {
      final repo = await ref.read(aiLookupRepositoryProvider.future);
      final result = await repo.translate(
        text: widget.word,
        targetLang: 'English',
        contextSnippet: widget.contextSnippet,
      );
      if (mounted) {
        setState(() {
          _translation = result;
          _translationStage = _TranslationStage.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translationError = '$e';
          _translationStage = _TranslationStage.error;
        });
      }
    }
  }

  Future<void> _save() async {
    final draft = SavedLookup(
      id: '',
      word: widget.word,
      documentId: widget.documentId,
      documentTitle: widget.documentTitle,
      page: widget.page,
      contextSnippet: widget.contextSnippet,
      quickResult: _quickResult,
      deepDiveResult: _deepDiveResult,
      translation: _translation,
      groupIds: const [],
      tags: const [],
      createdAt: null,
    );
    final saved = await showSaveLookupSheet(context, draftLookup: draft);
    if (saved && mounted) setState(() => _isSaved = true);
  }

  /// Whether [widget.word] is already present among this user's saved
  /// lookups (case-insensitive) — shown as soon as the quick result loads,
  /// before the user decides whether to save, mirroring how [SaveLookupSheet]
  /// treats a repeat save as another context for the same word rather than
  /// an unrelated new entry.
  bool get _isDuplicateWord {
    final word = widget.word.trim().toLowerCase();
    final existing = ref.watch(userSavedLookupsProvider).value ?? const <SavedLookup>[];
    return existing.any((l) => l.word.trim().toLowerCase() == word);
  }

  Future<void> _applyHighlight(String colorHex) async {
    await widget.onHighlight?.call(colorHex);
    if (mounted) {
      setState(() {
        _isHighlighted = true;
        _showColorPicker = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.word, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (widget.onHighlight != null)
                    IconButton(
                      icon: Icon(_isHighlighted ? Icons.highlight : Icons.highlight_outlined),
                      tooltip: _isHighlighted ? 'Highlighted' : 'Highlight',
                      onPressed: _isHighlighted
                          ? null
                          : () => setState(() => _showColorPicker = !_showColorPicker),
                    ),
                  if (_quickResult != null)
                    IconButton(
                      icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_outline),
                      tooltip: _isSaved ? 'Saved' : 'Save',
                      onPressed: _isSaved ? null : _save,
                    ),
                ],
              ),
              if (_showColorPicker) _buildColorPicker(context),
              const SizedBox(height: 12),
              _buildBody(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_stage) {
      case _Stage.loadingQuick:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );

      case _Stage.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_errorMessage ?? 'Something went wrong.', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _loadQuickResult, child: const Text('Retry')),
          ],
        );

      case _Stage.quickReady:
      case _Stage.loadingDeepDive:
      case _Stage.deepDiveReady:
        final quick = _quickResult!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isDuplicateWord) ...[
              _buildDuplicateBanner(context),
              const SizedBox(height: 12),
            ],
            if (quick.partOfSpeech.isNotEmpty)
              Text(quick.partOfSpeech, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(quick.definition),
            if (quick.shortExample.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"${quick.shortExample}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                if (_stage == _Stage.quickReady)
                  OutlinedButton(onPressed: _loadDeepDive, child: const Text('Deep dive'))
                else if (_stage == _Stage.loadingDeepDive)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                if (_translationStage == _TranslationStage.idle)
                  OutlinedButton(onPressed: _loadTranslation, child: const Text('Translate'))
                else if (_translationStage == _TranslationStage.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
            if (_translationStage == _TranslationStage.error) ...[
              const SizedBox(height: 8),
              Text(
                _translationError ?? 'Translation failed.',
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (_translationStage == _TranslationStage.ready) _buildTranslation(context, _translation!),
            if (_stage == _Stage.deepDiveReady) _buildDeepDive(context, _deepDiveResult!),
          ],
        );
    }
  }

  Widget _buildDuplicateBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You already have "${widget.word}" saved — saving again will add this as another context for it.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (final colorHex in highlightColorPalette)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _applyHighlight(colorHex),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTranslation(BuildContext context, TranslationResult translation) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text('(${translation.sourceLang}) ${translation.translatedText}'),
    );
  }

  Widget _buildDeepDive(BuildContext context, DeepDiveResult deepDive) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Etymology', style: textTheme.labelLarge),
        Text(deepDive.etymology),
        const SizedBox(height: 12),
        Text('Nuance', style: textTheme.labelLarge),
        Text(deepDive.nuance),
        const SizedBox(height: 12),
        Text('In this context', style: textTheme.labelLarge),
        Text(deepDive.contextAnalysis),
        if (deepDive.usageExamples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Usage examples', style: textTheme.labelLarge),
          for (final example in deepDive.usageExamples) Text('• $example'),
        ],
      ],
    );
  }
}

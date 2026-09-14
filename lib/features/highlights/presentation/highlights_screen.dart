import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../documents/data/document_repository.dart';
import '../../documents/domain/document.dart';
import '../data/highlight_repository.dart';
import '../domain/highlight.dart';
import 'highlight_text_spans.dart' show colorFromHex;

class HighlightsScreen extends ConsumerStatefulWidget {
  const HighlightsScreen({super.key});

  @override
  ConsumerState<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends ConsumerState<HighlightsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _openingHighlightId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Highlight> _filter(List<Highlight> highlights) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return highlights;
    return highlights
        .where((h) => '${h.text} ${h.documentTitle}'.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _openHighlight(Highlight highlight, List<Document> documents) async {
    final matches = documents.where((d) => d.id == highlight.documentId);
    final document = matches.isEmpty ? null : matches.first;
    if (document == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That document is no longer in your library.')),
      );
      return;
    }
    setState(() => _openingHighlightId = highlight.id);
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      final bytes = await repo.documentBytes(document);
      if (mounted) {
        context.push('/document', extra: (document.id, document.title, bytes, document.format));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingHighlightId = null);
    }
  }

  Future<void> _confirmAndDelete(Highlight highlight) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove highlight?'),
        content: Text('The highlight on "${highlight.text}" will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await ref.read(highlightRepositoryProvider.future);
    await repo.deleteHighlight(highlight.id);
  }

  @override
  Widget build(BuildContext context) {
    final highlightsAsync = ref.watch(userHighlightsProvider);
    final documentsAsync = ref.watch(userDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Highlights')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search highlighted text or document…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: highlightsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (highlights) {
                final filtered = _filter(highlights);
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      highlights.isEmpty
                          ? 'No highlights yet — select text in a document and tap the highlighter icon.'
                          : 'No matches.',
                    ),
                  );
                }
                final documents = documentsAsync.value ?? const <Document>[];
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final highlight = filtered[index];
                    final isOpening = _openingHighlightId == highlight.id;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: colorFromHex(highlight.colorHex),
                      ),
                      title: Text(
                        highlight.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${highlight.documentTitle} · page ${highlight.page}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isOpening
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                              onPressed: () => _confirmAndDelete(highlight),
                            ),
                      onTap: isOpening ? null : () => _openHighlight(highlight, documents),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

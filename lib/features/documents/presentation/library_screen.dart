import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../flashcards/data/flashcard_repository.dart';
import '../../lookup/presentation/lookup_sheet.dart';
import '../data/document_repository.dart';
import '../data/folder_repository.dart';
import '../domain/document.dart';
import '../domain/folder.dart';

enum _DocumentSort { recent, nameAZ, sizeLargest }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isImporting = false;
  String? _openingDocumentId;
  String? _deletingDocumentId;
  String? _movingDocumentId;
  String? _selectedFolderId;
  _DocumentSort _sort = _DocumentSort.recent;

  List<Document> _sorted(List<Document> documents) {
    final sorted = [...documents];
    switch (_sort) {
      case _DocumentSort.recent:
        break; // already ordered newest-first by the database query.
      case _DocumentSort.nameAZ:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _DocumentSort.sizeLargest:
        sorted.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    }
    return sorted;
  }

  Future<void> _importDocument() async {
    setState(() => _isImporting = true);
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      await repo.pickAndImportDocument();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openDocument(Document document) async {
    setState(() => _openingDocumentId = document.id);
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
      if (mounted) setState(() => _openingDocumentId = null);
    }
  }

  Future<void> _confirmAndDelete(Document document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove document?'),
        content: Text('"${document.title}" will be removed from your library. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingDocumentId = document.id);
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      await repo.deleteDocument(document);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingDocumentId = null);
    }
  }

  static const _noFolderSentinel = '';
  static const _unassignedFilterId = '__unassigned__';

  Future<void> _moveToFolder(Document document) async {
    final folders = ref.read(userFoldersProvider).value ?? const <Folder>[];
    // showDialog<String> distinguishes "dismissed without choosing" (null,
    // handled below) from "chose No folder" (the sentinel, mapped to a real
    // null folderId just before the repository call).
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move to folder'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _noFolderSentinel),
            child: Row(
              children: [
                const Icon(Icons.close, size: 20),
                const SizedBox(width: 12),
                Text('No folder', style: document.folderId == null ? const TextStyle(fontWeight: FontWeight.bold) : null),
              ],
            ),
          ),
          for (final folder in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, folder.id),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    folder.name,
                    style: document.folderId == folder.id ? const TextStyle(fontWeight: FontWeight.bold) : null,
                  ),
                ],
              ),
            ),
          if (folders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('No folders yet — create one from the Folders screen first.'),
            ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final selectedId = result == _noFolderSentinel ? null : result;

    setState(() => _movingDocumentId = document.id);
    try {
      final repo = await ref.read(folderRepositoryProvider.future);
      await repo.moveDocument(documentId: document.id, oldFolderId: document.folderId, folderId: selectedId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not move document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _movingDocumentId = null);
    }
  }

  /// Opens a plain word/phrase lookup that isn't tied to any document —
  /// reuses the same [showLookupSheet] flow every document viewer uses, just
  /// with no document context, so saving it produces a [SavedLookup] with a
  /// null documentId/documentTitle/page.
  Future<void> _lookUpWord() async {
    final controller = TextEditingController();
    final word = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Look up a word'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'word or phrase'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
    if (word == null || word.isEmpty || !mounted) return;
    await showLookupSheet(
      context,
      word: word,
      contextSnippet: '',
      documentId: null,
      documentTitle: null,
      page: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final dueCount = ref.watch(dueFlashcardCountProvider).value ?? 0;
              return IconButton(
                icon: Badge(
                  label: Text('$dueCount'),
                  isLabelVisible: dueCount > 0,
                  child: const Icon(Icons.style_outlined),
                ),
                tooltip: 'Study',
                onPressed: () => context.push('/study'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Look up a word',
            onPressed: _lookUpWord,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Saved lookups',
            onPressed: () => context.push('/saved-lookups'),
          ),
          IconButton(
            icon: const Icon(Icons.highlight_outlined),
            tooltip: 'Highlights',
            onPressed: () => context.push('/highlights'),
          ),
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Groups',
            onPressed: () => context.push('/groups'),
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Folders',
            onPressed: () => context.push('/folders'),
          ),
          PopupMenuButton<_DocumentSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _DocumentSort.recent, child: Text('Recently added')),
              PopupMenuItem(value: _DocumentSort.nameAZ, child: Text('Name (A–Z)')),
              PopupMenuItem(value: _DocumentSort.sizeLargest, child: Text('Largest first')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer(
            builder: (context, ref, _) {
              final foldersAsync = ref.watch(userFoldersProvider);
              return foldersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (folders) => _buildFolderFilterChips(folders),
              );
            },
          ),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final documentsAsync = ref.watch(userDocumentsProvider);
                return documentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error: $error')),
                  data: (allDocuments) {
                    final documents = _sorted(
                      switch (_selectedFolderId) {
                        null => allDocuments,
                        _unassignedFilterId => allDocuments.where((d) => d.folderId == null).toList(),
                        final folderId => allDocuments.where((d) => d.folderId == folderId).toList(),
                      },
                    );
                    if (documents.isEmpty) {
                      return Center(
                        child: Text(
                          allDocuments.isEmpty
                              ? 'No documents yet — import a PDF to get started.'
                              : _selectedFolderId == _unassignedFilterId
                                  ? 'No unassigned documents.'
                                  : 'No documents in this folder.',
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final document = documents[index];
                        final isOpening = _openingDocumentId == document.id;
                        final isDeleting = _deletingDocumentId == document.id;
                        final isMoving = _movingDocumentId == document.id;
                        final isBusy = isOpening || isDeleting || isMoving;
                        return ListTile(
                          leading: Icon(_iconFor(document.format)),
                          title: Text(document.title),
                          subtitle: Text('${(document.sizeBytes / 1024).round()} KB'),
                          trailing: isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.drive_file_move_outline),
                                      tooltip: 'Move to folder',
                                      onPressed: () => _moveToFolder(document),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Remove',
                                      onPressed: () => _confirmAndDelete(document),
                                    ),
                                  ],
                                ),
                          onTap: isBusy ? null : () => _openDocument(document),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isImporting ? null : _importDocument,
        tooltip: 'Import document',
        child: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFolderFilterChips(List<Folder> folders) {
    if (folders.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _selectedFolderId == null,
              onSelected: (_) => setState(() => _selectedFolderId = null),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Unassigned'),
              selected: _selectedFolderId == _unassignedFilterId,
              onSelected: (_) => setState(
                () => _selectedFolderId = _selectedFolderId == _unassignedFilterId ? null : _unassignedFilterId,
              ),
            ),
          ),
          for (final folder in folders)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(folder.name),
                selected: _selectedFolderId == folder.id,
                onSelected: (_) => setState(
                  () => _selectedFolderId = _selectedFolderId == folder.id ? null : folder.id,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(DocumentFormat format) {
    return switch (format) {
      DocumentFormat.pdf => Icons.picture_as_pdf_outlined,
      DocumentFormat.epub => Icons.menu_book_outlined,
      DocumentFormat.docx => Icons.description_outlined,
      DocumentFormat.txt => Icons.article_outlined,
    };
  }
}

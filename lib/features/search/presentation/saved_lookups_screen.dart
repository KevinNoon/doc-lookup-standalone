import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups_tags/data/group_repository.dart';
import '../../groups_tags/domain/group.dart';
import '../../lookup/data/saved_lookup_repository.dart';
import '../../lookup/domain/saved_lookup.dart';
import '../data/saved_lookups_markdown_export.dart';
import '../data/saved_lookups_markdown_import.dart';
import '../domain/word_group.dart';
import 'saved_lookup_detail_sheet.dart';

enum _LookupSort { recent, wordAZ }

class SavedLookupsScreen extends ConsumerStatefulWidget {
  const SavedLookupsScreen({super.key});

  @override
  ConsumerState<SavedLookupsScreen> createState() => _SavedLookupsScreenState();
}

class _SavedLookupsScreenState extends ConsumerState<SavedLookupsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedGroupId;
  _LookupSort _sort = _LookupSort.recent;
  bool _isExporting = false;
  bool _isImporting = false;

  /// Imports lookups from a Markdown file written by [_exportMarkdown] (from
  /// this app or its cloud-synced sibling) — lets someone restore or migrate
  /// their saved lookups into a fresh, local-only install. Each parsed
  /// occurrence becomes a new saved lookup, same as any other save; groups
  /// are matched by name to existing local groups, creating one if no match
  /// exists.
  Future<void> _importMarkdown() async {
    setState(() => _isImporting = true);
    try {
      final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['md']);
      if (picked == null) return;

      final content = utf8.decode(await picked.readAsBytes());
      final parsed = parseSavedLookupsMarkdown(content);
      if (parsed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No lookups found in that file.')),
          );
        }
        return;
      }

      final groupRepo = await ref.read(groupRepositoryProvider.future);
      final lookupRepo = await ref.read(savedLookupRepositoryProvider.future);
      final existingGroups = ref.read(userGroupsProvider).value ?? const <Group>[];
      final groupIdByName = <String, String>{
        for (final g in existingGroups) g.name.toLowerCase(): g.id,
      };

      for (final item in parsed) {
        final groupIds = <String>[];
        for (final name in item.groupNames) {
          final key = name.toLowerCase();
          final existingId = groupIdByName[key];
          if (existingId != null) {
            groupIds.add(existingId);
            continue;
          }
          final created = await groupRepo.createGroup(name: name, colorHex: '#009688');
          groupIdByName[key] = created.id;
          groupIds.add(created.id);
        }
        await lookupRepo.saveLookup(
          SavedLookup(
            id: '',
            word: item.word,
            documentId: null,
            documentTitle: item.documentTitle,
            page: item.page,
            contextSnippet: '',
            quickResult: item.quickResult,
            deepDiveResult: item.deepDiveResult,
            translation: item.translation,
            groupIds: groupIds,
            tags: item.tags,
            createdAt: null,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${parsed.length} lookup${parsed.length == 1 ? '' : 's'}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Exports every saved lookup (not just what's currently filtered/visible)
  /// as a single Markdown file via the system "Save As" dialog — uses
  /// [FilePicker.saveFile] directly rather than writing to a fixed path,
  /// since Android's scoped storage makes writing to a public Downloads
  /// folder unreliable without extra permissions.
  Future<void> _exportMarkdown(List<SavedLookup> lookups) async {
    if (lookups.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final groups = ref.read(userGroupsProvider).value ?? const <Group>[];
      final markdown = buildSavedLookupsMarkdown(lookups, groups);
      final path = await FilePicker.saveFile(
        fileName: 'saved_lookups.md',
        bytes: Uint8List.fromList(utf8.encode(markdown)),
        type: FileType.any,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path == null ? 'Export cancelled.' : 'Saved to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WordGroup> _filter(List<WordGroup> groups) {
    final query = _query.trim().toLowerCase();
    return groups.where((group) {
      if (_selectedGroupId != null &&
          !group.occurrences.any((o) => o.groupIds.contains(_selectedGroupId))) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        group.word,
        for (final occurrence in group.occurrences) ...[
          occurrence.quickResult?.definition ?? '',
          ...occurrence.tags,
        ],
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<WordGroup> _sorted(List<WordGroup> groups) {
    if (_sort == _LookupSort.recent) return groups; // already newest-first from the database query.
    final sorted = [...groups];
    sorted.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final lookupsAsync = ref.watch(userSavedLookupsProvider);
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved lookups'),
        actions: [
          IconButton(
            icon: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_outlined),
            tooltip: 'Import from Markdown',
            onPressed: _isImporting ? null : _importMarkdown,
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: 'Export as Markdown',
            onPressed: _isExporting || (lookupsAsync.value ?? const []).isEmpty
                ? null
                : () => _exportMarkdown(lookupsAsync.value!),
          ),
          PopupMenuButton<_LookupSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _LookupSort.recent, child: Text('Recently saved')),
              PopupMenuItem(value: _LookupSort.wordAZ, child: Text('Word (A–Z)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search word, definition, tags…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          groupsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (groups) => _buildGroupFilterChips(groups),
          ),
          Expanded(
            child: lookupsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (lookups) {
                final wordGroups = groupByWord(lookups);
                final filtered = _sorted(_filter(wordGroups));
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      wordGroups.isEmpty
                          ? 'No saved lookups yet — save one from a document.'
                          : 'No matches.',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final group = filtered[index];
                    final mostRecent = group.occurrences.first;
                    return ListTile(
                      title: Text(group.word),
                      subtitle: Text(
                        mostRecent.quickResult?.definition ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: group.occurrences.length > 1
                          ? Text('${group.occurrences.length} sources')
                          : (mostRecent.tags.isEmpty ? null : Text(mostRecent.tags.join(', '))),
                      onTap: () => showSavedLookupDetailSheet(context, group),
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

  Widget _buildGroupFilterChips(List<Group> groups) {
    if (groups.isEmpty) return const SizedBox.shrink();
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
              selected: _selectedGroupId == null,
              onSelected: (_) => setState(() => _selectedGroupId = null),
            ),
          ),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(group.name),
                selected: _selectedGroupId == group.id,
                onSelected: (_) => setState(
                  () => _selectedGroupId = _selectedGroupId == group.id ? null : group.id,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

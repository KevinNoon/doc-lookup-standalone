import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../documents/data/document_repository.dart';
import '../../documents/domain/document.dart';
import '../../flashcards/data/flashcard_repository.dart';
import '../../groups_tags/data/group_repository.dart';
import '../../groups_tags/domain/group.dart';
import '../../lookup/data/saved_lookup_repository.dart';
import '../../lookup/domain/saved_lookup.dart';
import '../domain/word_group.dart';

Future<void> showSavedLookupDetailSheet(BuildContext context, WordGroup group) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SavedLookupDetailSheet(group: group),
  );
}

class SavedLookupDetailSheet extends ConsumerStatefulWidget {
  const SavedLookupDetailSheet({super.key, required this.group});

  final WordGroup group;

  @override
  ConsumerState<SavedLookupDetailSheet> createState() => _SavedLookupDetailSheetState();
}

class _SavedLookupDetailSheetState extends ConsumerState<SavedLookupDetailSheet> {
  final _addedToStudyIds = <String>{};
  final _deletedIds = <String>{};
  final _groupIdsOverride = <String, List<String>>{};
  final _tagsOverride = <String, List<String>>{};
  bool _isBusy = false;

  Future<void> _addToStudy(SavedLookup lookup) async {
    setState(() => _isBusy = true);
    try {
      final repo = await ref.read(flashcardRepositoryProvider.future);
      await repo.addToStudy(
        lookupId: lookup.id,
        word: lookup.word,
        definition: lookup.quickResult?.definition ?? '',
      );
      if (mounted) setState(() => _addedToStudyIds.add(lookup.id));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmAndDelete(SavedLookup lookup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this occurrence?'),
        content: Text(
          lookup.documentTitle == null
              ? 'The saved lookup for "${lookup.word}" will be removed. This cannot be undone.'
              : 'The lookup for "${lookup.word}" from "${lookup.documentTitle}" will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final repo = await ref.read(savedLookupRepositoryProvider.future);
      await repo.deleteLookup(lookup);
      if (mounted) setState(() => _deletedIds.add(lookup.id));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Moves the whole word — every occurrence in [widget.group], not just
  /// one — to the selected groups in a single batched write. Editing groups
  /// per-occurrence used to let a word saved from more than one document end
  /// up split across the old and new group whenever only one of its
  /// occurrences got edited; operating on all of them at once removes that
  /// possibility.
  Future<void> _editGroups() async {
    final occurrences = widget.group.occurrences.where((o) => !_deletedIds.contains(o.id)).toList();
    if (occurrences.isEmpty) return;
    final groups = ref.read(userGroupsProvider).value ?? const <Group>[];
    final currentIds = _groupIdsOverride[occurrences.first.id] ?? occurrences.first.groupIds;
    final selected = Set<String>.from(currentIds);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Move to groups'),
          content: groups.isEmpty
              ? const Text('No groups yet — create one from the Groups screen first.')
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final group in groups)
                        FilterChip(
                          label: Text(group.name),
                          selected: selected.contains(group.id),
                          onSelected: (isSelected) => setDialogState(() {
                            if (isSelected) {
                              selected.add(group.id);
                            } else {
                              selected.remove(group.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Done')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final newGroupIds = result.toList();
      final repo = await ref.read(savedLookupRepositoryProvider.future);
      await repo.updateGroupsForOccurrences(occurrences, newGroupIds);
      if (mounted) {
        setState(() {
          for (final occurrence in occurrences) {
            _groupIdsOverride[occurrence.id] = newGroupIds;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update groups: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Retags the whole word — every occurrence in [widget.group] — in a
  /// single batched write, for the same reason [_editGroups] operates on all
  /// occurrences at once rather than one at a time.
  Future<void> _editTags() async {
    final occurrences = widget.group.occurrences.where((o) => !_deletedIds.contains(o.id)).toList();
    if (occurrences.isEmpty) return;
    final currentTags = _tagsOverride[occurrences.first.id] ?? occurrences.first.tags;
    final controller = TextEditingController(text: currentTags.join(', '));

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit tags'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'comma, separated, tags'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final newTags = result.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    setState(() => _isBusy = true);
    try {
      final repo = await ref.read(savedLookupRepositoryProvider.future);
      await repo.updateTagsForOccurrences(occurrences, newTags);
      if (mounted) {
        setState(() {
          for (final occurrence in occurrences) {
            _tagsOverride[occurrence.id] = newTags;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update tags: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openSource(SavedLookup lookup) async {
    final documents = ref.read(userDocumentsProvider).value ?? const <Document>[];
    final matches = documents.where((d) => d.id == lookup.documentId);
    final document = matches.isEmpty ? null : matches.first;
    if (document == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${lookup.documentTitle}" is no longer in your library.')),
      );
      return;
    }
    setState(() => _isBusy = true);
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      final filePath = await repo.ensureLocalFile(document);
      if (mounted) {
        context.push('/document', extra: (document.id, document.title, filePath, document.format));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    final occurrences = widget.group.occurrences.where((o) => !_deletedIds.contains(o.id)).toList();

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
                    child: Text(widget.group.word, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (occurrences.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.folder_outlined),
                      tooltip: 'Move to groups',
                      onPressed: _isBusy ? null : _editGroups,
                    ),
                    IconButton(
                      icon: const Icon(Icons.sell_outlined),
                      tooltip: 'Edit tags',
                      onPressed: _isBusy ? null : _editTags,
                    ),
                  ],
                ],
              ),
              if (occurrences.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('All occurrences removed.'),
                )
              else
                for (var i = 0; i < occurrences.length; i++) ...[
                  if (i > 0) const Divider(height: 32),
                  _buildOccurrence(context, occurrences[i]),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOccurrence(BuildContext context, SavedLookup lookup) {
    final textTheme = Theme.of(context).textTheme;
    final quick = lookup.quickResult;
    final deepDive = lookup.deepDiveResult;
    final translation = lookup.translation;
    final addedToStudy = _addedToStudyIds.contains(lookup.id);
    final groupIds = _groupIdsOverride[lookup.id] ?? lookup.groupIds;
    final tags = _tagsOverride[lookup.id] ?? lookup.tags;
    final allGroups = ref.watch(userGroupsProvider).value ?? const <Group>[];
    final groupNames = [
      for (final id in groupIds)
        ...allGroups.where((g) => g.id == id).map((g) => g.name),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: lookup.documentId == null
                  ? Text(
                      'Standalone lookup',
                      style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.launch, size: 18),
                      label: Text(
                        '${lookup.documentTitle} · p.${lookup.page}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _isBusy ? null : () => _openSource(lookup),
                    ),
            ),
            IconButton(
              icon: Icon(addedToStudy ? Icons.style : Icons.style_outlined),
              tooltip: addedToStudy ? 'In study deck' : 'Add to study',
              onPressed: _isBusy || addedToStudy ? null : () => _addToStudy(lookup),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove',
              onPressed: _isBusy ? null : () => _confirmAndDelete(lookup),
            ),
          ],
        ),
        if (groupNames.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final name in groupNames)
                Chip(
                  label: Text(name),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (quick != null) ...[
          if (quick.partOfSpeech.isNotEmpty) Text(quick.partOfSpeech, style: textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(quick.definition),
          if (quick.shortExample.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('"${quick.shortExample}"', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ],
        if (translation != null) ...[
          const SizedBox(height: 8),
          Text('(${translation.sourceLang}) ${translation.translatedText}'),
        ],
        if (deepDive != null) ...[
          const SizedBox(height: 12),
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
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [for (final tag in tags) Chip(label: Text(tag))],
          ),
        ],
      ],
    );
  }
}

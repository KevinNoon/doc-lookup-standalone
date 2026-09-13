import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lookup/data/saved_lookup_repository.dart';
import '../../lookup/domain/saved_lookup.dart';
import '../data/group_repository.dart';
import '../domain/group.dart';

/// Shows a sheet for assigning [draftLookup] to groups and tags, then saves
/// it. Returns true if the lookup was saved, false if the user cancelled.
Future<bool> showSaveLookupSheet(
  BuildContext context, {
  required SavedLookup draftLookup,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SaveLookupSheet(draftLookup: draftLookup),
  );
  return saved ?? false;
}

class SaveLookupSheet extends ConsumerStatefulWidget {
  const SaveLookupSheet({super.key, required this.draftLookup});

  final SavedLookup draftLookup;

  @override
  ConsumerState<SaveLookupSheet> createState() => _SaveLookupSheetState();
}

class _SaveLookupSheetState extends ConsumerState<SaveLookupSheet> {
  final _selectedGroupIds = <String>{};
  final _newGroupController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _newGroupController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _newGroupController.text.trim();
    if (name.isEmpty) return;
    final repo = await ref.read(groupRepositoryProvider.future);
    final group = await repo.createGroup(name: name, colorHex: '#009688');
    setState(() {
      _selectedGroupIds.add(group.id);
      _newGroupController.clear();
    });
  }

  /// Whether [widget.draftLookup]'s word is already present among this
  /// user's saved lookups (case-insensitive) — used to warn before saving,
  /// since saving proceeds as another occurrence of the same word rather
  /// than a separate unrelated entry (see [SavedLookupsScreen]'s
  /// client-side word grouping).
  bool get _isDuplicateWord {
    final word = widget.draftLookup.word.trim().toLowerCase();
    final existing = ref.watch(userSavedLookupsProvider).value ?? const <SavedLookup>[];
    return existing.any((l) => l.word.trim().toLowerCase() == word);
  }

  Future<void> _save() async {
    final wasDuplicate = _isDuplicateWord;
    setState(() => _isSaving = true);
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final lookup = SavedLookup(
      id: '',
      word: widget.draftLookup.word,
      documentId: widget.draftLookup.documentId,
      documentTitle: widget.draftLookup.documentTitle,
      page: widget.draftLookup.page,
      contextSnippet: widget.draftLookup.contextSnippet,
      quickResult: widget.draftLookup.quickResult,
      deepDiveResult: widget.draftLookup.deepDiveResult,
      translation: widget.draftLookup.translation,
      groupIds: _selectedGroupIds.toList(),
      tags: tags,
      createdAt: null,
    );
    try {
      final repo = await ref.read(savedLookupRepositoryProvider.future);
      await repo.saveLookup(lookup);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasDuplicate
                  ? 'Added this context to your existing "${lookup.word}" entry.'
                  : 'Saved "${lookup.word}".',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Save "${widget.draftLookup.word}"', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text('Groups', style: Theme.of(context).textTheme.labelLarge),
              Consumer(
                builder: (context, ref, _) {
                  final groupsAsync = ref.watch(userGroupsProvider);
                  return groupsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                    error: (e, _) => Text('Error loading groups: $e'),
                    data: (groups) => Wrap(
                      spacing: 8,
                      children: [
                        for (final group in groups) _buildGroupChip(group),
                      ],
                    ),
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newGroupController,
                      decoration: const InputDecoration(hintText: 'New group name'),
                      onSubmitted: (_) => _createGroup(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add), onPressed: _createGroup),
                ],
              ),
              const SizedBox(height: 12),
              Text('Tags', style: Theme.of(context).textTheme.labelLarge),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(hintText: 'comma, separated, tags'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupChip(Group group) {
    final isSelected = _selectedGroupIds.contains(group.id);
    return FilterChip(
      label: Text(group.name),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedGroupIds.add(group.id);
          } else {
            _selectedGroupIds.remove(group.id);
          }
        });
      },
    );
  }
}

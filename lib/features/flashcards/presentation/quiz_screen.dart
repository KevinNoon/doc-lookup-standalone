import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/flashcard_repository.dart';
import '../domain/flashcard.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueAsync = ref.watch(dueFlashcardsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      body: dueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cards) {
          if (cards.isEmpty) {
            return const Center(child: Text('Nothing due right now — nice work.'));
          }
          return _QuizSession(initialCards: cards);
        },
      ),
    );
  }
}

class _QuizSession extends ConsumerStatefulWidget {
  const _QuizSession({required this.initialCards});

  final List<Flashcard> initialCards;

  @override
  ConsumerState<_QuizSession> createState() => _QuizSessionState();
}

class _QuizSessionState extends ConsumerState<_QuizSession> {
  late final List<Flashcard> _queue = List.of(widget.initialCards);
  bool _showAnswer = false;
  bool _isGrading = false;

  Future<void> _grade(int quality) async {
    setState(() => _isGrading = true);
    final card = _queue.first;
    final repo = await ref.read(flashcardRepositoryProvider.future);
    await repo.reviewCard(card, quality);
    if (!mounted) return;
    setState(() {
      _queue.removeAt(0);
      _showAnswer = false;
      _isGrading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return const Center(child: Text('Session complete — nice work.'));
    }
    final card = _queue.first;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_queue.length} remaining', style: textTheme.bodySmall),
          const Spacer(),
          Text(card.word, textAlign: TextAlign.center, style: textTheme.headlineMedium),
          const SizedBox(height: 24),
          if (_showAnswer)
            Text(card.definition, textAlign: TextAlign.center, style: textTheme.bodyLarge)
          else
            OutlinedButton(
              onPressed: () => setState(() => _showAnswer = true),
              child: const Text('Show answer'),
            ),
          const Spacer(),
          if (_showAnswer)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _GradeButton(label: 'Again', color: Colors.red, onPressed: _isGrading ? null : () => _grade(0)),
                _GradeButton(label: 'Hard', color: Colors.orange, onPressed: _isGrading ? null : () => _grade(3)),
                _GradeButton(label: 'Good', color: Colors.teal, onPressed: _isGrading ? null : () => _grade(4)),
                _GradeButton(label: 'Easy', color: Colors.green, onPressed: _isGrading ? null : () => _grade(5)),
              ],
            ),
        ],
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.label, required this.color, required this.onPressed});

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: color),
      child: Text(label),
    );
  }
}

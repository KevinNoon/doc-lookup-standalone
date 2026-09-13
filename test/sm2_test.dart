import 'package:doc_lookup/features/flashcards/domain/sm2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeSm2', () {
    test('first three "easy" reviews follow the standard 1, 6, ~17 day progression', () {
      var ease = 2.5;
      var interval = 0;
      var repetitions = 0;

      final first = computeSm2(
        quality: 5,
        previousEaseFactor: ease,
        previousIntervalDays: interval,
        previousRepetitions: repetitions,
      );
      expect(first.intervalDays, 1);
      expect(first.repetitions, 1);
      ease = first.easeFactor;
      interval = first.intervalDays;
      repetitions = first.repetitions;

      final second = computeSm2(
        quality: 5,
        previousEaseFactor: ease,
        previousIntervalDays: interval,
        previousRepetitions: repetitions,
      );
      expect(second.intervalDays, 6);
      expect(second.repetitions, 2);
      ease = second.easeFactor;
      interval = second.intervalDays;
      repetitions = second.repetitions;

      final third = computeSm2(
        quality: 5,
        previousEaseFactor: ease,
        previousIntervalDays: interval,
        previousRepetitions: repetitions,
      );
      expect(third.repetitions, 3);
      expect(third.intervalDays, (6 * ease).round());
    });

    test('a failed review (quality < 3) resets repetitions and interval to 1 day', () {
      final result = computeSm2(
        quality: 1,
        previousEaseFactor: 2.8,
        previousIntervalDays: 17,
        previousRepetitions: 3,
      );
      expect(result.repetitions, 0);
      expect(result.intervalDays, 1);
    });

    test('ease factor never drops below 1.3', () {
      var ease = 1.3;
      for (var i = 0; i < 5; i++) {
        final result = computeSm2(
          quality: 0,
          previousEaseFactor: ease,
          previousIntervalDays: 1,
          previousRepetitions: 0,
        );
        ease = result.easeFactor;
        expect(ease, greaterThanOrEqualTo(1.3));
      }
    });
  });
}

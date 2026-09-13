/// Standard SM-2 (SuperMemo-2) spaced-repetition scheduling.
///
/// [quality] is the recall grade for this review, 0-5 (0 = total blackout,
/// 5 = perfect recall). Below 3 resets the card's progress, matching the
/// classic SM-2 behavior of treating a failed recall as starting over.
class Sm2Result {
  const Sm2Result({required this.easeFactor, required this.intervalDays, required this.repetitions});

  final double easeFactor;
  final int intervalDays;
  final int repetitions;
}

Sm2Result computeSm2({
  required int quality,
  required double previousEaseFactor,
  required int previousIntervalDays,
  required int previousRepetitions,
}) {
  assert(quality >= 0 && quality <= 5);

  if (quality < 3) {
    return Sm2Result(
      easeFactor: _updatedEaseFactor(previousEaseFactor, quality),
      intervalDays: 1,
      repetitions: 0,
    );
  }

  final repetitions = previousRepetitions + 1;
  final int intervalDays;
  if (repetitions == 1) {
    intervalDays = 1;
  } else if (repetitions == 2) {
    intervalDays = 6;
  } else {
    intervalDays = (previousIntervalDays * previousEaseFactor).round();
  }

  return Sm2Result(
    easeFactor: _updatedEaseFactor(previousEaseFactor, quality),
    intervalDays: intervalDays,
    repetitions: repetitions,
  );
}

double _updatedEaseFactor(double previousEaseFactor, int quality) {
  final raw = previousEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  return raw < 1.3 ? 1.3 : raw;
}

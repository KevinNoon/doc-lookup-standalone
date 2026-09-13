class Flashcard {
  const Flashcard({
    required this.id,
    required this.lookupId,
    required this.word,
    required this.definition,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.dueDate,
  });

  factory Flashcard.fromMap(String id, Map<String, dynamic> map) {
    return Flashcard(
      id: id,
      lookupId: map['lookupId'] as String? ?? '',
      word: map['word'] as String? ?? '',
      definition: map['definition'] as String? ?? '',
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: map['intervalDays'] as int? ?? 0,
      repetitions: map['repetitions'] as int? ?? 0,
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
          : DateTime.now(),
    );
  }

  final String id;
  final String lookupId;
  final String word;
  final String definition;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime dueDate;

  Map<String, dynamic> toMap() {
    return {
      'lookupId': lookupId,
      'word': word,
      'definition': definition,
      'easeFactor': easeFactor,
      'intervalDays': intervalDays,
      'repetitions': repetitions,
      'dueDate': dueDate.millisecondsSinceEpoch,
    };
  }
}

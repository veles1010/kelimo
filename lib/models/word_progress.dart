class WordProgress {
  const WordProgress({
    required this.wordId,
    required this.isFavorite,
    required this.mastery,
    required this.repetitionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.updatedAt,
    this.reviewStage = 0,
    this.isKnown = false,
  });

  factory WordProgress.initial(String wordId, {DateTime? now}) {
    return WordProgress(
      wordId: wordId,
      isFavorite: false,
      mastery: 'new',
      repetitionCount: 0,
      correctCount: 0,
      wrongCount: 0,
      lastReviewedAt: null,
      nextReviewAt: null,
      updatedAt: now ?? DateTime.now(),
      reviewStage: 0,
      isKnown: false,
    );
  }

  factory WordProgress.fromMap(Map<String, Object?> map) {
    return WordProgress(
      wordId: map['word_id']! as String,
      isFavorite: map['is_favorite'] == 1,
      mastery: map['mastery']! as String,
      repetitionCount: map['repetition_count']! as int,
      correctCount: map['correct_count']! as int,
      wrongCount: map['wrong_count']! as int,
      lastReviewedAt: _dateTimeFromDatabase(map['last_reviewed_at']),
      nextReviewAt: _dateTimeFromDatabase(map['next_review_at']),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      reviewStage: (map['review_stage'] as int?) ?? 0,
      isKnown: map['is_known'] == 1,
    );
  }

  final String wordId;
  final bool isFavorite;
  final String mastery;
  final int repetitionCount;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final DateTime updatedAt;
  final int reviewStage;

  /// True only when the learner explicitly marks this word as known.
  ///
  /// This intentionally differs from legacy `mastery: 'easy'` records.
  final bool isKnown;

  Map<String, Object?> toMap() {
    return {
      'word_id': wordId,
      'is_favorite': isFavorite ? 1 : 0,
      'mastery': mastery,
      'repetition_count': repetitionCount,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'last_reviewed_at': lastReviewedAt?.toUtc().toIso8601String(),
      'next_review_at': nextReviewAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'review_stage': reviewStage,
      'is_known': isKnown ? 1 : 0,
    };
  }

  WordProgress copyWith({
    bool? isFavorite,
    String? mastery,
    int? repetitionCount,
    int? correctCount,
    int? wrongCount,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    DateTime? updatedAt,
    int? reviewStage,
    bool? isKnown,
    bool clearNextReviewAt = false,
  }) {
    return WordProgress(
      wordId: wordId,
      isFavorite: isFavorite ?? this.isFavorite,
      mastery: mastery ?? this.mastery,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: clearNextReviewAt
          ? null
          : nextReviewAt ?? this.nextReviewAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewStage: reviewStage ?? this.reviewStage,
      isKnown: isKnown ?? this.isKnown,
    );
  }
}

DateTime? _dateTimeFromDatabase(Object? value) {
  return value == null ? null : DateTime.parse(value as String).toUtc();
}

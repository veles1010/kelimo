import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/review_scheduler.dart';
import 'package:kelimo/utils/review_time_label.dart';

class _MemoryWordProgressStore implements WordProgressStore {
  _MemoryWordProgressStore([Map<String, WordProgress>? values])
    : values = values ?? {};

  final Map<String, WordProgress> values;

  @override
  void clearCachedData() => values.clear();

  @override
  List<WordProgress> getAllProgress() => List.unmodifiable(values.values);

  @override
  Future<void> initialize() async {}

  @override
  WordProgress progressFor(String wordId) =>
      values[wordId] ?? WordProgress.initial(wordId);

  @override
  Future<void> resetProgress(String wordId) async => values.remove(wordId);

  @override
  Future<WordProgress> saveFavorite(String wordId, bool isFavorite) async {
    final progress = progressFor(wordId).copyWith(isFavorite: isFavorite);
    await saveProgress(progress);
    return progress;
  }

  @override
  Future<WordProgress> saveLearningResult(
    LearningReviewResult result, {
    DateTime? reviewedAt,
  }) async {
    final progress = wordProgressAfterLearningResult(
      progressFor(result.word.id),
      result,
      reviewedAt: reviewedAt,
    );
    await saveProgress(progress);
    return progress;
  }

  @override
  Future<void> saveProgress(WordProgress progress) async {
    values[progress.wordId] = progress;
  }
}

WordProgress _progress({
  required String wordId,
  String mastery = 'new',
  int reviewStage = 0,
  DateTime? nextReviewAt,
  bool isFavorite = false,
}) {
  final now = DateTime.utc(2026, 7, 16, 9);
  return WordProgress(
    wordId: wordId,
    isFavorite: isFavorite,
    mastery: mastery,
    repetitionCount: mastery == 'new' ? 0 : 1,
    correctCount: mastery == 'easy' ? 1 : 0,
    wrongCount: mastery == 'again' || mastery == 'hard' ? 1 : 0,
    lastReviewedAt: mastery == 'new' ? null : now,
    nextReviewAt: nextReviewAt,
    updatedAt: now,
    reviewStage: reviewStage,
  );
}

void main() {
  final now = DateTime.utc(2026, 7, 16, 9);

  group('ReviewScheduler', () {
    late ReviewScheduler scheduler;

    setUp(() => scheduler = ReviewScheduler(now: () => now));

    test('Tekrar Et aşama 0 ile hemen vadesi gelir', () {
      final schedule = scheduler.schedule(
        rating: LearningRating.again,
        currentStage: 4,
      );

      expect(schedule.reviewStage, 0);
      expect(schedule.nextReviewAt, now);
    });

    test('Zor aşamayı azaltır ve bir gün sonrasını planlar', () {
      final schedule = scheduler.schedule(
        rating: LearningRating.hard,
        currentStage: 3,
      );
      final minimum = scheduler.schedule(
        rating: LearningRating.hard,
        currentStage: 0,
      );

      expect(schedule.reviewStage, 2);
      expect(schedule.nextReviewAt, now.add(const Duration(days: 1)));
      expect(minimum.reviewStage, 0);
    });

    test('Kolay aşamaları 1, 3, 7, 14, 30 ve 60 gün planlar', () {
      const days = [1, 3, 7, 14, 30, 60];
      for (var currentStage = 0; currentStage < days.length; currentStage++) {
        final schedule = scheduler.schedule(
          rating: LearningRating.easy,
          currentStage: currentStage,
        );
        expect(schedule.reviewStage, currentStage + 1);
        expect(
          schedule.nextReviewAt,
          now.add(Duration(days: days[currentStage])),
        );
      }
    });

    test(
      'Kolay aşama 6 üzerinde ilerlemez ve enjekte edilen saati kullanır',
      () {
        final schedule = scheduler.schedule(
          rating: LearningRating.easy,
          currentStage: 99,
        );

        expect(schedule.reviewStage, 6);
        expect(schedule.nextReviewAt, now.add(const Duration(days: 60)));
      },
    );

    test(
      'eski again hard ve easy kayıtlarını güvenli biçimde geri doldurur',
      () {
        for (final mastery in ['again', 'hard']) {
          final schedule = ReviewScheduler.legacySchedule(
            mastery: mastery,
            migratedAt: now,
          )!;
          expect(schedule.reviewStage, 0);
          expect(schedule.nextReviewAt, now);
        }

        final reviewedAt = now.subtract(const Duration(hours: 3));
        final easy = ReviewScheduler.legacySchedule(
          mastery: 'easy',
          migratedAt: now,
          lastReviewedAt: reviewedAt,
        )!;
        expect(easy.reviewStage, 1);
        expect(easy.nextReviewAt, reviewedAt.add(const Duration(days: 1)));
        expect(
          ReviewScheduler.legacySchedule(mastery: 'new', migratedAt: now),
          isNull,
        );
      },
    );
  });

  group('Öğrenme Merkezi vade filtresi', () {
    LearningCenterSnapshot load(Map<String, WordProgress> values) {
      return LearningCenterService(
        wordProgressStore: _MemoryWordProgressStore(values),
        now: () => now,
      ).load();
    }

    test('yalnızca geçmişte veya şimdi vadesi gelen kayıtları döndürür', () {
      final snapshot = load({
        'dog': _progress(
          wordId: 'dog',
          mastery: 'again',
          nextReviewAt: now.subtract(const Duration(minutes: 1)),
        ),
        'cat': _progress(wordId: 'cat', mastery: 'again', nextReviewAt: now),
        'bird': _progress(
          wordId: 'bird',
          mastery: 'hard',
          nextReviewAt: now.add(const Duration(days: 1)),
        ),
        'fish': _progress(wordId: 'fish', mastery: 'again'),
        'horse': _progress(wordId: 'horse', isFavorite: true),
      });

      expect(
        snapshot
            .wordsFor(LearningCenterFilter.repeatPending)
            .map((entry) => entry.word.id),
        ['dog', 'cat'],
      );
    });

    test(
      'değerlendirme planı servis yeniden oluşturulduğunda korunur',
      () async {
        final store = _MemoryWordProgressStore();
        final result = LearningReviewResult(
          word: animalWords.first,
          rating: LearningRating.again,
        );
        await store.saveLearningResult(result, reviewedAt: now);

        final reopened = LearningCenterService(
          wordProgressStore: store,
          now: () => now,
        ).load();
        expect(reopened.repeatPendingCount, 1);
        expect(reopened.allWords.first.progress.reviewStage, 0);
        expect(reopened.allWords.first.progress.nextReviewAt, now);

        final hard = wordProgressAfterLearningResult(
          reopened.allWords.first.progress,
          LearningReviewResult(
            word: animalWords.first,
            rating: LearningRating.hard,
          ),
          reviewedAt: now,
        );
        await store.saveProgress(hard);
        expect(
          LearningCenterService(
            wordProgressStore: store,
            now: () => now,
          ).load().repeatPendingCount,
          0,
        );
      },
    );

    test('Kolay planlanan güne kadar tekrar listesine girmez', () {
      final progress = wordProgressAfterLearningResult(
        WordProgress.initial('dog', now: now),
        LearningReviewResult(
          word: animalWords.first,
          rating: LearningRating.easy,
        ),
        reviewedAt: now,
      );

      expect(load({'dog': progress}).repeatPendingCount, 0);
      expect(
        LearningCenterService(
          wordProgressStore: _MemoryWordProgressStore({'dog': progress}),
          now: () => now.add(const Duration(days: 1)),
        ).load().repeatPendingCount,
        1,
      );
    });
  });

  test('tekrar zamanı etiketleri kullanıcı dostu biçimlenir', () {
    expect(reviewTimeLabel(now, now: now), 'Şimdi');
    expect(
      reviewTimeLabel(now.add(const Duration(hours: 2)), now: now),
      'Bugün',
    );
    expect(
      reviewTimeLabel(now.add(const Duration(days: 1)), now: now),
      'Yarın',
    );
    expect(
      reviewTimeLabel(now.add(const Duration(days: 7)), now: now),
      '7 gün sonra',
    );
  });

  test(
    'favori değişikliği tekrar planını korur ve reset planı temizler',
    () async {
      final scheduled = _progress(
        wordId: 'dog',
        mastery: 'easy',
        reviewStage: 3,
        nextReviewAt: now.add(const Duration(days: 7)),
      );
      final store = _MemoryWordProgressStore({'dog': scheduled});

      final favorite = await store.saveFavorite('dog', true);
      expect(favorite.reviewStage, 3);
      expect(favorite.nextReviewAt, now.add(const Duration(days: 7)));

      await store.resetProgress('dog');
      expect(store.progressFor('dog').reviewStage, 0);
      expect(store.progressFor('dog').nextReviewAt, isNull);
    },
  );
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kelimo/data/achievement_catalog.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/achievement.dart';
import 'package:kelimo/repositories/achievement_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/streak_service.dart';

abstract interface class AchievementMetricsSource {
  Future<AchievementMetrics> load();
}

class AchievementMetricsLoader implements AchievementMetricsSource {
  const AchievementMetricsLoader({
    required this.wordProgressStore,
    required this.quizStore,
    required this.streakService,
  });

  final WordProgressStore wordProgressStore;
  final QuizStore quizStore;
  final StreakService streakService;

  @override
  Future<AchievementMetrics> load() async {
    final knownWordIds = CategoryCatalog.categories
        .expand((category) => category.words)
        .map((word) => word.id)
        .toSet();
    final progress = wordProgressStore
        .getAllProgress()
        .where((record) => knownWordIds.contains(record.wordId))
        .toList(growable: false);
    final attempts = await quizStore.getAllAttempts();

    return AchievementMetrics(
      totalReviewCount: progress.fold<int>(
        0,
        (total, record) => total + record.repetitionCount,
      ),
      learnedWordCount: progress.where(isLearnedProgress).length,
      favoriteWordCount: progress.where((record) => record.isFavorite).length,
      completedQuizCount: attempts.length,
      hasPerfectQuiz: attempts.any((attempt) => attempt.scorePercent == 100),
      currentStreak: streakService.currentStreak,
    );
  }
}

class AchievementService extends ChangeNotifier {
  AchievementService({
    required this.repository,
    required this.metricsLoader,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AchievementStore repository;
  final AchievementMetricsSource metricsLoader;
  final DateTime Function() _now;
  final Map<String, AchievementUnlock> _unlocks = {};
  Future<void> _evaluationQueue = Future.value();
  AchievementMetrics _metrics = AchievementMetrics.empty;
  bool _isLoading = true;

  AchievementMetrics get metrics => _metrics;
  bool get isLoading => _isLoading;
  int get unlockedCount => _unlocks.length;
  Map<String, AchievementUnlock> get unlocks => Map.unmodifiable(_unlocks);
  bool isUnlocked(String id) => _unlocks.containsKey(id);
  AchievementUnlock? unlockFor(String id) => _unlocks[id];

  Future<void> initialize() async {
    _isLoading = true;
    try {
      final unlocked = await repository.loadUnlocked();
      _unlocks
        ..clear()
        ..addEntries(
          unlocked.map((entry) => MapEntry(entry.achievementId, entry)),
        );
      await evaluate();
    } catch (error, stackTrace) {
      debugPrint('Başarım servisi başlatılamadı: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Achievement>> evaluate() {
    final completer = Completer<List<Achievement>>();
    _evaluationQueue = _evaluationQueue.then((_) async {
      try {
        completer.complete(await _evaluateNow());
      } catch (error, stackTrace) {
        debugPrint('Başarımlar değerlendirilemedi: $error\n$stackTrace');
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<List<Achievement>> _evaluateNow() async {
    _metrics = await metricsLoader.load();
    final newlyUnlocked = <Achievement>[];
    for (final achievement in AchievementCatalog.achievements) {
      if (_unlocks.containsKey(achievement.id) ||
          !achievement.isMet(_metrics)) {
        continue;
      }
      final unlockedAt = _now().toUtc();
      if (await repository.unlock(achievement.id, unlockedAt)) {
        _unlocks[achievement.id] = AchievementUnlock(
          achievementId: achievement.id,
          unlockedAt: unlockedAt,
        );
        newlyUnlocked.add(achievement);
      }
    }
    notifyListeners();
    return List.unmodifiable(newlyUnlocked);
  }

  void resetAfterDataClear() {
    repository.clearCachedData();
    _unlocks.clear();
    _metrics = AchievementMetrics.empty;
    _isLoading = false;
    notifyListeners();
  }
}

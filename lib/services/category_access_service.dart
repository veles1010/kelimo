import 'package:flutter/foundation.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/category_unlock.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/repositories/category_unlock_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/xp_service.dart';

const initialUnlockedCategoryIds = <String>{
  'animals',
  'foods',
  'colors',
  'home',
  'family',
  'daily_routines',
};

int earnedCategoryUnlockCredits(int totalXp) {
  if (totalXp < 100) return 0;
  var credits = 1;
  if (totalXp >= 250) credits++;
  if (totalXp >= 450) credits++;
  if (totalXp >= 700) credits += 2;
  if (totalXp >= 1000) credits += ((totalXp - 700) ~/ 300) * 2;
  return credits;
}

int? nextCategoryUnlockXp(int totalXp) {
  if (totalXp < 100) return 100;
  if (totalXp < 250) return 250;
  if (totalXp < 450) return 450;
  if (totalXp < 700) return 700;
  return 700 + (((totalXp - 700) ~/ 300) + 1) * 300;
}

class CategoryAccessService extends ChangeNotifier {
  CategoryAccessService({
    required this.repository,
    required this.wordProgressStore,
    required this.quizStore,
    required this.xpService,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    xpService.addListener(_handleXpChanged);
  }

  final CategoryUnlockStore repository;
  final WordProgressStore wordProgressStore;
  final QuizStore quizStore;
  final XpService xpService;
  final DateTime Function() _now;
  final Map<String, CategoryUnlock> _unlocks = {};
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  Set<String> get unlockedCategoryIds => Set.unmodifiable(_unlocks.keys);
  int get manuallySpentCredits =>
      _unlocks.values.where((unlock) => unlock.consumesCredit).length;
  int get lockedCategoryCount => CategoryCatalog.categories
      .where((category) => !isUnlocked(category.id))
      .length;
  int get availableUnlockCredits {
    final earned = earnedCategoryUnlockCredits(xpService.totalXp);
    return (earned - manuallySpentCredits).clamp(0, lockedCategoryCount);
  }

  int get xpUntilNextCredit {
    if (lockedCategoryCount == 0 || availableUnlockCredits > 0) return 0;
    final target = nextCategoryUnlockXp(xpService.totalXp);
    return target == null ? 0 : (target - xpService.totalXp).clamp(0, target);
  }

  bool isUnlocked(String categoryId) => _unlocks.containsKey(categoryId);
  bool canOpen(LearningCategory category) => isUnlocked(category.id);

  Future<void> initialize() async {
    _isLoading = true;
    try {
      final loaded = await repository.loadUnlocks();
      _unlocks
        ..clear()
        ..addEntries(
          loaded.map((unlock) => MapEntry(unlock.categoryId, unlock)),
        );
      await _backfillRequiredUnlocks();
    } catch (error, stackTrace) {
      debugPrint('Kategori erişimi başlatılamadı: $error\n$stackTrace');
      _seedInitialInMemory();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _backfillRequiredUnlocks() async {
    final categoryByWordId = <String, String>{
      for (final category in CategoryCatalog.categories)
        for (final word in category.words) word.id: category.id,
    };
    final required = <String>{...initialUnlockedCategoryIds};
    for (final progress in wordProgressStore.getAllProgress()) {
      if (!isReviewedProgress(progress) && !progress.isFavorite) continue;
      final categoryId = categoryByWordId[progress.wordId];
      if (categoryId != null) required.add(categoryId);
    }
    for (final attempt in await quizStore.getAllAttempts()) {
      if (CategoryCatalog.findById(attempt.categoryId) != null) {
        required.add(attempt.categoryId);
      }
    }
    for (final categoryId in required) {
      if (_unlocks.containsKey(categoryId)) continue;
      final unlock = CategoryUnlock(
        categoryId: categoryId,
        unlockedAt: _now().toUtc(),
        consumesCredit: false,
      );
      await repository.unlock(unlock);
      _unlocks[categoryId] = unlock;
    }
  }

  Future<bool> unlockCategory(String categoryId) async {
    if (_unlocks.containsKey(categoryId) || availableUnlockCredits <= 0) {
      return false;
    }
    if (CategoryCatalog.findById(categoryId) == null) return false;
    final unlock = CategoryUnlock(
      categoryId: categoryId,
      unlockedAt: _now().toUtc(),
      consumesCredit: true,
    );
    if (!await repository.unlock(unlock)) return false;
    _unlocks[categoryId] = unlock;
    notifyListeners();
    return true;
  }

  Future<void> resetAfterDataClear() async {
    final now = _now().toUtc();
    final defaults = initialUnlockedCategoryIds.map(
      (id) => CategoryUnlock(
        categoryId: id,
        unlockedAt: now,
        consumesCredit: false,
      ),
    );
    await repository.replaceWithDefaults(defaults);
    _seedInitialInMemory(now: now);
    notifyListeners();
  }

  void _seedInitialInMemory({DateTime? now}) {
    final date = now ?? _now().toUtc();
    _unlocks
      ..clear()
      ..addEntries(
        initialUnlockedCategoryIds.map(
          (id) => MapEntry(
            id,
            CategoryUnlock(
              categoryId: id,
              unlockedAt: date,
              consumesCredit: false,
            ),
          ),
        ),
      );
  }

  void _handleXpChanged() => notifyListeners();

  @override
  void dispose() {
    xpService.removeListener(_handleXpChanged);
    super.dispose();
  }
}

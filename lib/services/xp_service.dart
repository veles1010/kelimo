import 'package:flutter/foundation.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/services/learning_engine.dart';

int xpRewardForRating(LearningRating rating) {
  return switch (rating) {
    LearningRating.easy => 5,
    LearningRating.again => 2,
    LearningRating.hard => 3,
  };
}

class XpService extends ChangeNotifier {
  XpService({required this.repository});

  static const xpPerLevel = 1000;

  final XpStore repository;

  int _totalXp = 0;
  bool _isLoading = true;

  int get totalXp => _totalXp;
  int get currentLevel => _totalXp ~/ xpPerLevel + 1;
  int get xpInCurrentLevel => _totalXp % xpPerLevel;
  int get xpRequiredForNextLevel => xpPerLevel;
  double get progress => (xpInCurrentLevel / xpPerLevel).clamp(0.0, 1.0);
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    try {
      final state = await repository.loadState();
      _applyState(state);
    } catch (error, stackTrace) {
      debugPrint('XP servisi başlatılamadı: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addXp(int amount) async {
    try {
      final state = await repository.addXp(amount);
      _applyState(state);
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrint('XP servisi güncellenemedi: $error\n$stackTrace');
      return false;
    }
  }

  Future<bool> awardWordReview({
    required String wordId,
    required LearningRating rating,
    DateTime? awardedAt,
  }) async {
    final amount = xpRewardForRating(rating);
    if (repository is! XpAwardStore) return addXp(amount);
    final awardStore = repository as XpAwardStore;
    try {
      final state = await awardStore.awardWordReview(
        wordId: wordId,
        rating: rating,
        amount: amount,
        awardedAt: awardedAt,
      );
      _applyState(state);
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Kelime XP ödülü uygulanamadı: $error\n$stackTrace');
      return false;
    }
  }

  void applyPersistedState(XpState state) {
    repository.synchronizeState(state);
    _applyState(state);
    notifyListeners();
  }

  void resetAfterDataClear() {
    applyPersistedState(XpState.initial());
  }

  void _applyState(XpState state) {
    _totalXp = state.totalXp < 0 ? 0 : state.totalXp;
  }
}

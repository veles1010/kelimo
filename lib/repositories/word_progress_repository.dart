import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:sqflite/sqflite.dart';

WordProgress wordProgressAfterLearningResult(
  WordProgress current,
  LearningReviewResult result, {
  DateTime? reviewedAt,
}) {
  final reviewDate = reviewedAt ?? DateTime.now();
  final isCorrect = result.rating == LearningRating.easy;
  return current.copyWith(
    mastery: result.rating.name,
    repetitionCount: current.repetitionCount + 1,
    correctCount: current.correctCount + (isCorrect ? 1 : 0),
    wrongCount: current.wrongCount + (isCorrect ? 0 : 1),
    lastReviewedAt: reviewDate,
    updatedAt: reviewDate,
  );
}

abstract interface class WordProgressStore {
  Future<void> initialize();
  List<WordProgress> getAllProgress();
  WordProgress progressFor(String wordId);
  Future<void> saveProgress(WordProgress progress);
  Future<WordProgress> saveFavorite(String wordId, bool isFavorite);
  Future<WordProgress> saveLearningResult(
    LearningReviewResult result, {
    DateTime? reviewedAt,
  });
  Future<void> resetProgress(String wordId);
}

class WordProgressRepository implements WordProgressStore {
  WordProgressRepository(this._databaseService);

  final DatabaseService _databaseService;
  final Map<String, WordProgress> _progressByWordId = {};

  @override
  Future<void> initialize() async {
    try {
      final database = await _databaseService.database;
      final rows = await database.query('word_progress');
      _progressByWordId
        ..clear()
        ..addEntries(
          rows.map((row) {
            final progress = WordProgress.fromMap(row);
            return MapEntry(progress.wordId, progress);
          }),
        );
    } catch (error, stackTrace) {
      debugPrint('Kelime ilerlemeleri yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  List<WordProgress> getAllProgress() {
    return List.unmodifiable(_progressByWordId.values);
  }

  @override
  WordProgress progressFor(String wordId) {
    return _progressByWordId[wordId] ?? WordProgress.initial(wordId);
  }

  @override
  Future<void> saveProgress(WordProgress progress) async {
    final previous = _progressByWordId[progress.wordId];
    _progressByWordId[progress.wordId] = progress;
    try {
      final database = await _databaseService.database;
      await database.insert(
        'word_progress',
        progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (error, stackTrace) {
      if (previous == null) {
        _progressByWordId.remove(progress.wordId);
      } else {
        _progressByWordId[progress.wordId] = previous;
      }
      debugPrint('Kelime ilerlemesi kaydedilemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<WordProgress> saveFavorite(String wordId, bool isFavorite) async {
    final progress = progressFor(
      wordId,
    ).copyWith(isFavorite: isFavorite, updatedAt: DateTime.now());
    await saveProgress(progress);
    return progress;
  }

  @override
  Future<WordProgress> saveLearningResult(
    LearningReviewResult result, {
    DateTime? reviewedAt,
  }) async {
    final current = progressFor(result.word.id);
    final progress = wordProgressAfterLearningResult(
      current,
      result,
      reviewedAt: reviewedAt,
    );
    await saveProgress(progress);
    return progress;
  }

  @override
  Future<void> resetProgress(String wordId) async {
    final previous = _progressByWordId.remove(wordId);
    try {
      final database = await _databaseService.database;
      await database.delete(
        'word_progress',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
    } catch (error, stackTrace) {
      if (previous != null) _progressByWordId[wordId] = previous;
      debugPrint('Kelime ilerlemesi sıfırlanamadı: $error\n$stackTrace');
      rethrow;
    }
  }
}

import 'dart:math' as math;

import 'package:kelimo/models/word.dart';

enum LearningRating { easy, again, hard }

class LearningReviewResult {
  const LearningReviewResult({required this.word, required this.rating});

  final Word word;
  final LearningRating rating;
}

class LearningEngine {
  LearningEngine(List<Word> words, {int initialWordIndex = 0})
    : assert(words.isNotEmpty),
      assert(initialWordIndex >= 0 && initialWordIndex < words.length),
      _allWords = List.of(words),
      _sessionQueue = [
        ...words.skip(initialWordIndex),
        ...words.take(initialWordIndex),
      ];

  final List<Word> _allWords;
  final List<Word> _sessionQueue;
  final List<Word> _manualHistory = [];
  bool _isComplete = false;
  LearningReviewResult? _lastReview;

  Word get currentWord => _sessionQueue.first;
  int get currentWordNumber => _allWords.indexOf(currentWord) + 1;
  int get totalWordCount => _allWords.length;
  bool get isComplete => _isComplete;
  bool get canNext => !_isComplete && _sessionQueue.length > 1;
  bool get canPrevious => !_isComplete && _manualHistory.isNotEmpty;
  LearningReviewResult? get lastReview => _lastReview;

  Word nextWord() {
    if (!canNext) return currentWord;

    final previousWord = _sessionQueue.removeAt(0);
    _sessionQueue.add(previousWord);
    _manualHistory.add(previousWord);
    return currentWord;
  }

  Word previousWord() {
    if (!canPrevious) return currentWord;

    final previousWord = _manualHistory.removeLast();
    _sessionQueue.remove(previousWord);
    _sessionQueue.insert(0, previousWord);
    return currentWord;
  }

  Word rateEasy() {
    if (_isComplete) return currentWord;

    _manualHistory.clear();
    final current = currentWord;
    _lastReview = LearningReviewResult(
      word: current,
      rating: LearningRating.easy,
    );
    _sessionQueue.removeWhere((word) => word.id == current.id);
    _manualHistory.removeWhere((word) => word.id == current.id);
    if (_sessionQueue.isEmpty) {
      _isComplete = true;
      return current;
    }
    return currentWord;
  }

  Word rateAgain() {
    if (_isComplete) return currentWord;
    _lastReview = LearningReviewResult(
      word: currentWord,
      rating: LearningRating.again,
    );
    return _rescheduleCurrentWord(2);
  }

  Word rateHard() {
    if (_isComplete) return currentWord;
    _lastReview = LearningReviewResult(
      word: currentWord,
      rating: LearningRating.hard,
    );
    return _rescheduleCurrentWord(1);
  }

  Word _rescheduleCurrentWord(int spacing) {
    if (_isComplete) return currentWord;

    _manualHistory.clear();
    final current = _sessionQueue.removeAt(0);
    _sessionQueue.insert(math.min(spacing, _sessionQueue.length), current);
    return currentWord;
  }
}

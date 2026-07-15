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
  final Set<Word> _easyConfirmations = {};
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
    final isConfirmed = _easyConfirmations.contains(current);

    if (_sessionQueue.length == 1) {
      _isComplete = true;
      return currentWord;
    }

    if (isConfirmed) {
      _easyConfirmations.remove(current);
      _sessionQueue.removeAt(0);
      return currentWord;
    }

    _easyConfirmations.add(current);
    return _rescheduleCurrentWord(9);
  }

  Word rateAgain() {
    if (_isComplete) return currentWord;
    _lastReview = LearningReviewResult(
      word: currentWord,
      rating: LearningRating.again,
    );
    _easyConfirmations.remove(currentWord);
    return _rescheduleCurrentWord(2);
  }

  Word rateHard() {
    if (_isComplete) return currentWord;
    _lastReview = LearningReviewResult(
      word: currentWord,
      rating: LearningRating.hard,
    );
    _easyConfirmations.remove(currentWord);
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

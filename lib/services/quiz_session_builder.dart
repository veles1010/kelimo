import 'dart:math';

import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/word.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.word,
    required this.options,
    required this.correctOptionIndex,
  });

  final Word word;
  final List<String> options;
  final int correctOptionIndex;

  String get correctAnswer => word.turkish;

  bool isCorrectAnswer(String answer) => answer == correctAnswer;
}

class QuizSession {
  QuizSession(List<QuizQuestion> questions)
    : questions = List.unmodifiable(questions);

  final List<QuizQuestion> questions;
}

class QuizSessionBuilder {
  QuizSessionBuilder({Random? random}) : _random = random ?? Random();

  static const int defaultQuestionCount = 10;

  final Random _random;

  QuizSession build(
    LearningCategory category, {
    int questionCount = defaultQuestionCount,
  }) {
    final uniqueWords = <String, Word>{
      for (final word in category.words) word.id: word,
    }.values.toList(growable: false);
    final actualQuestionCount = min(questionCount, uniqueWords.length);
    if (actualQuestionCount == 0) {
      return QuizSession(const []);
    }

    final distinctTranslations = category.words
        .map((word) => word.turkish)
        .toSet();
    if (distinctTranslations.length < 4) {
      throw StateError('Quiz için en az dört farklı cevap gerekir.');
    }

    final questionWords = uniqueWords.toList()..shuffle(_random);
    final correctPositions = _buildCorrectPositionBag(actualQuestionCount);
    final questions = <QuizQuestion>[];

    for (var index = 0; index < actualQuestionCount; index++) {
      final word = questionWords[index];
      final wrongOptions =
          distinctTranslations
              .where((translation) => translation != word.turkish)
              .toList()
            ..shuffle(_random);
      final options = <String>[word.turkish, ...wrongOptions.take(3)]
        ..shuffle(_random);

      final targetIndex = correctPositions[index];
      final shuffledCorrectIndex = options.indexOf(word.turkish);
      final displacedOption = options[targetIndex];
      options[targetIndex] = word.turkish;
      options[shuffledCorrectIndex] = displacedOption;
      final correctOptionIndex = options.indexOf(word.turkish);

      questions.add(
        QuizQuestion(
          word: word,
          options: List.unmodifiable(options),
          correctOptionIndex: correctOptionIndex,
        ),
      );
    }

    return QuizSession(questions);
  }

  List<int> _buildCorrectPositionBag(int questionCount) {
    final bag = <int>[];
    final baseCount = questionCount ~/ 4;
    for (var position = 0; position < 4; position++) {
      bag.addAll(List.filled(baseCount, position));
    }

    final remainingPositions = [0, 1, 2, 3]..shuffle(_random);
    bag.addAll(remainingPositions.take(questionCount % 4));

    for (var attempt = 0; attempt < 200; attempt++) {
      final candidate = bag.toList()..shuffle(_random);
      if (!_hasThreeConsecutive(candidate) &&
          !_isFixedFourPositionCycle(candidate)) {
        return candidate;
      }
    }

    final result = <int>[];
    final counts = <int, int>{
      for (var position = 0; position < 4; position++)
        position: bag.where((item) => item == position).length,
    };
    if (_fillBalancedPositions(result, counts, questionCount)) {
      return result;
    }
    throw StateError('Dengeli doğru cevap konumları oluşturulamadı.');
  }

  bool _fillBalancedPositions(
    List<int> result,
    Map<int, int> remaining,
    int targetLength,
  ) {
    if (result.length == targetLength) {
      return !_isFixedFourPositionCycle(result);
    }

    final candidates =
        remaining.entries
            .where((entry) => entry.value > 0)
            .map((entry) => entry.key)
            .toList()
          ..shuffle(_random);
    for (final position in candidates) {
      final length = result.length;
      if (length >= 2 &&
          result[length - 1] == position &&
          result[length - 2] == position) {
        continue;
      }
      result.add(position);
      remaining[position] = remaining[position]! - 1;
      if (_fillBalancedPositions(result, remaining, targetLength)) {
        return true;
      }
      remaining[position] = remaining[position]! + 1;
      result.removeLast();
    }
    return false;
  }

  bool _hasThreeConsecutive(List<int> positions) {
    for (var index = 2; index < positions.length; index++) {
      if (positions[index] == positions[index - 1] &&
          positions[index] == positions[index - 2]) {
        return true;
      }
    }
    return false;
  }

  bool _isFixedFourPositionCycle(List<int> positions) {
    if (positions.length < 8 || positions.take(4).toSet().length != 4) {
      return false;
    }
    for (var index = 4; index < positions.length; index++) {
      if (positions[index] != positions[index % 4]) return false;
    }
    return true;
  }
}

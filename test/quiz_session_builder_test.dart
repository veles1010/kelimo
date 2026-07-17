import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/services/quiz_session_builder.dart';

void main() {
  group('QuizSessionBuilder', () {
    test('her soruda dört benzersiz seçenek ve tek doğru cevap üretir', () {
      final session = QuizSessionBuilder(
        random: Random(42),
      ).build(CategoryCatalog.animals);

      for (final question in session.questions) {
        expect(question.options, hasLength(4));
        expect(question.options.toSet(), hasLength(4));
        expect(
          question.options.where((option) => option == question.correctAnswer),
          hasLength(1),
        );
        expect(
          question.options[question.correctOptionIndex],
          question.correctAnswer,
        );
        expect(question.isCorrectAnswer(question.correctAnswer), isTrue);
        expect(
          question.isCorrectAnswer(
            question.options.firstWhere(
              (option) => option != question.correctAnswer,
            ),
          ),
          isFalse,
        );
      }
    });

    test('on soruda doğru cevap konumlarını dengeli dağıtır', () {
      final session = QuizSessionBuilder(
        random: Random(7),
      ).build(CategoryCatalog.animals);
      final positions = session.questions
          .map((question) => question.correctOptionIndex)
          .toList();

      for (var position = 0; position < 4; position++) {
        final count = positions.where((item) => item == position).length;
        expect(count, inInclusiveRange(2, 3));
      }
      for (var index = 2; index < positions.length; index++) {
        expect(
          positions[index] == positions[index - 1] &&
              positions[index] == positions[index - 2],
          isFalse,
        );
      }
      expect(_isFixedFourPositionCycle(positions), isFalse);
    });

    test('sabit seed tekrarlanabilir oturum üretir', () {
      final first = QuizSessionBuilder(
        random: Random(123),
      ).build(CategoryCatalog.foods);
      final second = QuizSessionBuilder(
        random: Random(123),
      ).build(CategoryCatalog.foods);

      expect(_snapshot(first), _snapshot(second));
    });

    test('farklı seed soru ve doğru konum dizisini değiştirir', () {
      final first = QuizSessionBuilder(
        random: Random(10),
      ).build(CategoryCatalog.colors);
      final second = QuizSessionBuilder(
        random: Random(11),
      ).build(CategoryCatalog.colors);

      expect(_snapshot(first), isNot(_snapshot(second)));
      expect(
        first.questions.map((question) => question.correctOptionIndex),
        isNot(
          orderedEquals(
            second.questions.map((question) => question.correctOptionIndex),
          ),
        ),
      );
    });

    test('aynı üreticiyle art arda oturumlar yeniden karıştırılır', () {
      final builder = QuizSessionBuilder(random: Random(2026));
      final first = builder.build(CategoryCatalog.animals);
      final second = builder.build(CategoryCatalog.animals);

      expect(
        first.questions.map((question) => question.word.id),
        isNot(
          orderedEquals(second.questions.map((question) => question.word.id)),
        ),
      );
      expect(
        first.questions.map((question) => question.correctOptionIndex),
        isNot(
          orderedEquals(
            second.questions.map((question) => question.correctOptionIndex),
          ),
        ),
      );
    });

    test('quiz içinde soru kelimelerini tekrarlamaz', () {
      final session = QuizSessionBuilder(
        random: Random(99),
      ).build(CategoryCatalog.transportation);
      final wordIds = session.questions
          .map((question) => question.word.id)
          .toList();

      expect(wordIds, hasLength(10));
      expect(wordIds.toSet(), hasLength(10));
    });
  });
}

List<String> _snapshot(QuizSession session) {
  return session.questions
      .map(
        (question) =>
            '${question.word.id}|${question.options.join(',')}|'
            '${question.correctOptionIndex}',
      )
      .toList();
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

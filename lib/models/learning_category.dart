import 'package:kelimo/models/word.dart';

class LearningCategory {
  const LearningCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.words,
  });

  final String id;
  final String title;
  final String emoji;
  final List<Word> words;

  bool get isAvailable => words.isNotEmpty;
}

import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/models/learning_category.dart';

abstract final class CategoryCatalog {
  static const animals = LearningCategory(
    id: 'animals',
    title: 'Hayvanlar',
    emoji: '🐶',
    words: animalWords,
  );

  static const categories = <LearningCategory>[
    animals,
    LearningCategory(id: 'foods', title: 'Yiyecekler', emoji: '🍎', words: []),
    LearningCategory(id: 'colors', title: 'Renkler', emoji: '🎨', words: []),
    LearningCategory(id: 'home', title: 'Ev', emoji: '🏠', words: []),
    LearningCategory(id: 'family', title: 'Aile', emoji: '👨‍👩‍👧', words: []),
    LearningCategory(
      id: 'transportation',
      title: 'Ulaşım',
      emoji: '🚌',
      words: [],
    ),
  ];

  static LearningCategory? findById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/data/color_words.dart';
import 'package:kelimo/data/food_words.dart';
import 'package:kelimo/models/learning_category.dart';

abstract final class CategoryCatalog {
  static const animals = LearningCategory(
    id: 'animals',
    title: 'Hayvanlar',
    emoji: '🐶',
    words: animalWords,
  );

  static const foods = LearningCategory(
    id: 'foods',
    title: 'Yiyecekler',
    emoji: '🍎',
    words: foodWords,
  );

  static const colors = LearningCategory(
    id: 'colors',
    title: 'Renkler',
    emoji: '🎨',
    words: colorWords,
  );

  static const categories = <LearningCategory>[
    animals,
    foods,
    colors,
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

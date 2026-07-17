import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/data/body_words.dart';
import 'package:kelimo/data/city_place_words.dart';
import 'package:kelimo/data/clothing_words.dart';
import 'package:kelimo/data/color_words.dart';
import 'package:kelimo/data/daily_routine_words.dart';
import 'package:kelimo/data/family_words.dart';
import 'package:kelimo/data/food_words.dart';
import 'package:kelimo/data/health_words.dart';
import 'package:kelimo/data/home_words.dart';
import 'package:kelimo/data/school_words.dart';
import 'package:kelimo/data/transportation_words.dart';
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

  static const home = LearningCategory(
    id: 'home',
    title: 'Ev',
    emoji: '🏠',
    words: homeWords,
  );

  static const family = LearningCategory(
    id: 'family',
    title: 'Aile',
    emoji: '👨‍👩‍👧‍👦',
    words: familyWords,
  );

  static const transportation = LearningCategory(
    id: 'transportation',
    title: 'Ulaşım',
    emoji: '🚍',
    words: transportationWords,
  );

  static const dailyRoutines = LearningCategory(
    id: 'daily_routines',
    title: 'Günlük Rutinler',
    emoji: '⏰',
    words: dailyRoutineWords,
  );

  static const school = LearningCategory(
    id: 'school',
    title: 'Okul',
    emoji: '🏫',
    words: schoolWords,
  );

  static const clothing = LearningCategory(
    id: 'clothing',
    title: 'Giysiler',
    emoji: '👕',
    words: clothingWords,
  );

  static const body = LearningCategory(
    id: 'body',
    title: 'Vücut',
    emoji: '🧍',
    words: bodyWords,
  );

  static const health = LearningCategory(
    id: 'health',
    title: 'Sağlık',
    emoji: '🩺',
    words: healthWords,
  );

  static const cityPlaces = LearningCategory(
    id: 'city_places',
    title: 'Şehir ve Mekânlar',
    emoji: '🏙️',
    words: cityPlaceWords,
  );

  static const categories = <LearningCategory>[
    animals,
    foods,
    colors,
    home,
    family,
    transportation,
    dailyRoutines,
    school,
    clothing,
    body,
    health,
    cityPlaces,
  ];

  static LearningCategory? findById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

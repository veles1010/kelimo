import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/category_catalog.dart';

void main() {
  const legacyIdsByCategory = <String, List<String>>{
    'animals': [
      'dog',
      'cat',
      'bird',
      'fish',
      'horse',
      'cow',
      'sheep',
      'goat',
      'duck',
      'chicken',
      'rabbit',
      'mouse',
      'lion',
      'tiger',
      'bear',
      'monkey',
      'elephant',
      'giraffe',
      'zebra',
      'fox',
      'wolf',
      'frog',
      'turtle',
      'bee',
    ],
    'foods': [
      'foods_apple',
      'foods_banana',
      'foods_orange',
      'foods_strawberry',
      'foods_grape',
      'foods_watermelon',
      'foods_bread',
      'foods_cheese',
      'foods_milk',
      'foods_water',
      'foods_rice',
      'foods_soup',
      'foods_salad',
      'foods_cake',
      'foods_cookie',
      'foods_chocolate',
      'foods_ice_cream',
      'foods_hamburger',
      'foods_pizza',
      'foods_sandwich',
    ],
    'colors': [
      'colors_red',
      'colors_blue',
      'colors_yellow',
      'colors_green',
      'colors_orange',
      'colors_purple',
      'colors_pink',
      'colors_brown',
      'colors_black',
      'colors_white',
      'colors_gray',
      'colors_light_blue',
      'colors_dark_blue',
      'colors_gold',
      'colors_silver',
      'colors_colorful',
    ],
    'home': [
      'home_house',
      'home_room',
      'home_kitchen',
      'home_bathroom',
      'home_bedroom',
      'home_living_room',
      'home_door',
      'home_window',
      'home_wall',
      'home_floor',
      'home_roof',
      'home_table',
      'home_chair',
      'home_bed',
      'home_sofa',
      'home_lamp',
      'home_television',
      'home_refrigerator',
      'home_oven',
      'home_washing_machine',
      'home_garden',
      'home_key',
    ],
    'family': [
      'family_family',
      'family_mother',
      'family_father',
      'family_parents',
      'family_sister',
      'family_brother',
      'family_grandmother',
      'family_grandfather',
      'family_grandparents',
      'family_daughter',
      'family_son',
      'family_child',
      'family_children',
      'family_baby',
      'family_aunt',
      'family_uncle',
      'family_cousin',
      'family_wife',
      'family_husband',
      'family_relative',
    ],
    'transportation': [
      'transportation_car',
      'transportation_bus',
      'transportation_train',
      'transportation_bicycle',
      'transportation_motorcycle',
      'transportation_airplane',
      'transportation_ship',
      'transportation_boat',
      'transportation_taxi',
      'transportation_truck',
      'transportation_subway',
      'transportation_tram',
      'transportation_helicopter',
      'transportation_ambulance',
      'transportation_fire_truck',
      'transportation_police_car',
      'transportation_station',
      'transportation_airport',
      'transportation_road',
      'transportation_bridge',
    ],
  };

  test('içerik paketi 12 kategoride toplam 360 kelime içerir', () {
    expect(CategoryCatalog.categories, hasLength(12));
    expect(CategoryCatalog.categories.map((category) => category.id), [
      'animals',
      'foods',
      'colors',
      'home',
      'family',
      'transportation',
      'daily_routines',
      'school',
      'clothing',
      'body',
      'health',
      'city_places',
    ]);

    final allWords = CategoryCatalog.categories
        .expand((category) => category.words)
        .toList(growable: false);
    expect(allWords, hasLength(360));
    expect(allWords.map((word) => word.id).toSet(), hasLength(360));
  });

  test(
    'her kategori 30 eksiksiz ve quiz için ayırt edilebilir kelime içerir',
    () {
      for (final category in CategoryCatalog.categories) {
        expect(category.words, hasLength(30), reason: category.id);
        expect(
          category.words.map((word) => word.english.toLowerCase()).toSet(),
          hasLength(30),
          reason: '${category.id} İngilizce tekrar içeriyor',
        );
        expect(
          category.words.map((word) => word.turkish.toLowerCase()).toSet(),
          hasLength(30),
          reason: '${category.id} Türkçe seçenek tekrarı içeriyor',
        );
        for (final word in category.words) {
          expect(word.id, isNotEmpty, reason: category.id);
          expect(word.english, isNotEmpty, reason: word.id);
          expect(word.turkish, isNotEmpty, reason: word.id);
          expect(word.emoji, isNotEmpty, reason: word.id);
          expect(word.exampleSentence, isNotEmpty, reason: word.id);
          expect(word.exampleTranslation, isNotEmpty, reason: word.id);
        }
      }
    },
  );

  test('mevcut 122 kelimenin kimlikleri ve sırası korunur', () {
    var legacyWordCount = 0;
    for (final entry in legacyIdsByCategory.entries) {
      final category = CategoryCatalog.findById(entry.key)!;
      expect(
        category.words.take(entry.value.length).map((word) => word.id),
        entry.value,
        reason: entry.key,
      );
      legacyWordCount += entry.value.length;
    }
    expect(legacyWordCount, 122);
  });

  test(
    'yeni kategori ve kelime kimlikleri kararlı kategori öneklerini kullanır',
    () {
      for (final categoryId in [
        'daily_routines',
        'school',
        'clothing',
        'body',
        'health',
        'city_places',
      ]) {
        final category = CategoryCatalog.findById(categoryId)!;
        expect(category.isAvailable, isTrue);
        expect(
          category.words.every((word) => word.id.startsWith('${categoryId}_')),
          isTrue,
          reason: categoryId,
        );
      }
    },
  );
}

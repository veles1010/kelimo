import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/category_catalog.dart';

void main() {
  const existingIdSnapshots = <String, String>{
    'animals':
        'dog|cat|bird|fish|horse|cow|sheep|goat|duck|chicken|rabbit|mouse|lion|tiger|bear|monkey|elephant|giraffe|zebra|fox|wolf|frog|turtle|bee|animals_penguin|animals_dolphin|animals_whale|animals_snake|animals_owl|animals_butterfly',
    'foods':
        'foods_apple|foods_banana|foods_orange|foods_strawberry|foods_grape|foods_watermelon|foods_bread|foods_cheese|foods_milk|foods_water|foods_rice|foods_soup|foods_salad|foods_cake|foods_cookie|foods_chocolate|foods_ice_cream|foods_hamburger|foods_pizza|foods_sandwich|foods_egg|foods_tomato|foods_potato|foods_carrot|foods_yogurt|foods_honey|foods_tea|foods_coffee|foods_juice|foods_pasta',
    'colors':
        'colors_red|colors_blue|colors_yellow|colors_green|colors_orange|colors_purple|colors_pink|colors_brown|colors_black|colors_white|colors_gray|colors_light_blue|colors_dark_blue|colors_gold|colors_silver|colors_colorful|colors_beige|colors_cyan|colors_turquoise|colors_maroon|colors_cream|colors_mint|colors_coral|colors_violet|colors_indigo|colors_bronze|colors_copper|colors_lime|colors_olive|colors_magenta',
    'home':
        'home_house|home_room|home_kitchen|home_bathroom|home_bedroom|home_living_room|home_door|home_window|home_wall|home_floor|home_roof|home_table|home_chair|home_bed|home_sofa|home_lamp|home_television|home_refrigerator|home_oven|home_washing_machine|home_garden|home_key|home_cupboard|home_mirror|home_carpet|home_curtain|home_shelf|home_clock|home_shower|home_balcony',
    'family':
        'family_family|family_mother|family_father|family_parents|family_sister|family_brother|family_grandmother|family_grandfather|family_grandparents|family_daughter|family_son|family_child|family_children|family_baby|family_aunt|family_uncle|family_cousin|family_wife|family_husband|family_relative|family_niece|family_nephew|family_twins|family_sibling|family_stepmother|family_stepfather|family_grandson|family_granddaughter|family_bride|family_groom',
    'transportation':
        'transportation_car|transportation_bus|transportation_train|transportation_bicycle|transportation_motorcycle|transportation_airplane|transportation_ship|transportation_boat|transportation_taxi|transportation_truck|transportation_subway|transportation_tram|transportation_helicopter|transportation_ambulance|transportation_fire_truck|transportation_police_car|transportation_station|transportation_airport|transportation_road|transportation_bridge|transportation_scooter|transportation_ferry|transportation_van|transportation_minibus|transportation_cable_car|transportation_rocket|transportation_canoe|transportation_traffic_light|transportation_ticket|transportation_passenger',
    'daily_routines':
        'daily_routines_wake_up|daily_routines_get_up|daily_routines_make_bed|daily_routines_brush_teeth|daily_routines_wash_face|daily_routines_take_shower|daily_routines_get_dressed|daily_routines_comb_hair|daily_routines_have_breakfast|daily_routines_go_to_school|daily_routines_start_work|daily_routines_study|daily_routines_have_lunch|daily_routines_come_home|daily_routines_do_homework|daily_routines_exercise|daily_routines_play|daily_routines_read|daily_routines_watch_tv|daily_routines_listen_to_music|daily_routines_help_at_home|daily_routines_cook|daily_routines_set_table|daily_routines_have_dinner|daily_routines_wash_dishes|daily_routines_relax|daily_routines_prepare_bag|daily_routines_put_on_pajamas|daily_routines_go_to_bed|daily_routines_sleep',
    'school':
        'school_school|school_classroom|school_teacher|school_student|school_desk|school_board|school_book|school_notebook|school_pencil|school_pen|school_eraser|school_ruler|school_sharpener|school_school_bag|school_lesson|school_homework|school_exam|school_question|school_answer|school_library|school_playground|school_computer|school_map|school_scissors|school_glue|school_paper|school_dictionary|school_break|school_principal|school_school_bus',
    'clothing':
        'clothing_shirt|clothing_t_shirt|clothing_trousers|clothing_jeans|clothing_shorts|clothing_skirt|clothing_dress|clothing_jacket|clothing_coat|clothing_sweater|clothing_hoodie|clothing_socks|clothing_shoes|clothing_boots|clothing_sandals|clothing_hat|clothing_cap|clothing_scarf|clothing_gloves|clothing_belt|clothing_tie|clothing_pajamas|clothing_swimsuit|clothing_uniform|clothing_pocket|clothing_button|clothing_zipper|clothing_sleeve|clothing_raincoat|clothing_sneakers',
    'body':
        'body_head|body_face|body_hair|body_eye|body_ear|body_nose|body_mouth|body_tooth|body_tongue|body_neck|body_shoulder|body_arm|body_elbow|body_hand|body_finger|body_chest|body_back|body_stomach|body_waist|body_leg|body_knee|body_foot|body_toe|body_skin|body_bone|body_heart|body_brain|body_blood|body_beard|body_mustache',
    'health':
        'health_health|health_doctor|health_nurse|health_hospital|health_pharmacy|health_medicine|health_patient|health_appointment|health_fever|health_cough|health_cold|health_headache|health_toothache|health_stomachache|health_sore_throat|health_pain|health_bandage|health_thermometer|health_rest|health_sleep|health_water|health_exercise|health_healthy|health_sick|health_injury|health_allergy|health_vitamin|health_mask|health_soap|health_toothbrush',
    'city_places':
        'city_places_city|city_places_street|city_places_avenue|city_places_square|city_places_park|city_places_hospital|city_places_school|city_places_library|city_places_museum|city_places_cinema|city_places_theater|city_places_restaurant|city_places_cafe|city_places_market|city_places_supermarket|city_places_bakery|city_places_bank|city_places_post_office|city_places_police_station|city_places_fire_station|city_places_bus_stop|city_places_train_station|city_places_airport|city_places_hotel|city_places_pharmacy|city_places_playground|city_places_shopping_center|city_places_mosque|city_places_church|city_places_bridge',
  };

  test('içerik paketi 18 kategoride toplam 540 kelime içerir', () {
    expect(CategoryCatalog.categories, hasLength(18));
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
      'nature_weather',
      'time_dates',
      'numbers_quantities',
      'basic_verbs',
      'common_adjectives',
      'feelings',
    ]);

    final allWords = CategoryCatalog.categories
        .expand((category) => category.words)
        .toList(growable: false);
    expect(allWords, hasLength(540));
    expect(allWords.map((word) => word.id).toSet(), hasLength(540));
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

  test('mevcut 360 kelimenin kimlikleri ve sırası korunur', () {
    var existingWordCount = 0;
    for (final entry in existingIdSnapshots.entries) {
      final category = CategoryCatalog.findById(entry.key)!;
      final expectedIds = entry.value.split('|');
      expect(
        category.words.map((word) => word.id).join('|'),
        entry.value,
        reason: entry.key,
      );
      existingWordCount += expectedIds.length;
    }
    expect(existingWordCount, 360);
  });

  test('yeni kelime kimlikleri kararlı kategori öneklerini kullanır', () {
    for (final categoryId in [
      'nature_weather',
      'time_dates',
      'numbers_quantities',
      'basic_verbs',
      'common_adjectives',
      'feelings',
    ]) {
      final category = CategoryCatalog.findById(categoryId)!;
      expect(category.isAvailable, isTrue);
      expect(
        category.words.every((word) => word.id.startsWith('${categoryId}_')),
        isTrue,
        reason: categoryId,
      );
    }
  });
}

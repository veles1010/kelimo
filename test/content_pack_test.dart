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
    'nature_weather':
        'nature_weather_nature|nature_weather_weather|nature_weather_sun|nature_weather_sky|nature_weather_cloud|nature_weather_rain|nature_weather_snow|nature_weather_wind|nature_weather_storm|nature_weather_thunder|nature_weather_lightning|nature_weather_rainbow|nature_weather_fog|nature_weather_ice|nature_weather_river|nature_weather_lake|nature_weather_sea|nature_weather_ocean|nature_weather_mountain|nature_weather_hill|nature_weather_forest|nature_weather_tree|nature_weather_flower|nature_weather_grass|nature_weather_leaf|nature_weather_rock|nature_weather_beach|nature_weather_island|nature_weather_desert|nature_weather_season',
    'time_dates':
        'time_dates_time|time_dates_second|time_dates_minute|time_dates_hour|time_dates_day|time_dates_week|time_dates_month|time_dates_year|time_dates_today|time_dates_tomorrow|time_dates_yesterday|time_dates_morning|time_dates_noon|time_dates_afternoon|time_dates_evening|time_dates_night|time_dates_midnight|time_dates_early|time_dates_late|time_dates_monday|time_dates_tuesday|time_dates_wednesday|time_dates_thursday|time_dates_friday|time_dates_saturday|time_dates_sunday|time_dates_calendar|time_dates_date|time_dates_birthday|time_dates_weekend',
    'numbers_quantities':
        'numbers_quantities_zero|numbers_quantities_one|numbers_quantities_two|numbers_quantities_three|numbers_quantities_four|numbers_quantities_five|numbers_quantities_six|numbers_quantities_seven|numbers_quantities_eight|numbers_quantities_nine|numbers_quantities_ten|numbers_quantities_eleven|numbers_quantities_twelve|numbers_quantities_thirteen|numbers_quantities_fourteen|numbers_quantities_fifteen|numbers_quantities_sixteen|numbers_quantities_seventeen|numbers_quantities_eighteen|numbers_quantities_nineteen|numbers_quantities_twenty|numbers_quantities_thirty|numbers_quantities_forty|numbers_quantities_fifty|numbers_quantities_hundred|numbers_quantities_many|numbers_quantities_few|numbers_quantities_all|numbers_quantities_none|numbers_quantities_half',
    'basic_verbs':
        'basic_verbs_be|basic_verbs_have|basic_verbs_do|basic_verbs_go|basic_verbs_come|basic_verbs_see|basic_verbs_hear|basic_verbs_say|basic_verbs_speak|basic_verbs_eat|basic_verbs_drink|basic_verbs_sleep|basic_verbs_wake|basic_verbs_sit|basic_verbs_stand|basic_verbs_walk|basic_verbs_run|basic_verbs_jump|basic_verbs_read|basic_verbs_write|basic_verbs_open|basic_verbs_close|basic_verbs_give|basic_verbs_take|basic_verbs_make|basic_verbs_play|basic_verbs_work|basic_verbs_study|basic_verbs_help|basic_verbs_wait',
    'common_adjectives':
        'common_adjectives_big|common_adjectives_small|common_adjectives_tall|common_adjectives_short|common_adjectives_long|common_adjectives_fast|common_adjectives_slow|common_adjectives_hot|common_adjectives_cold|common_adjectives_warm|common_adjectives_new|common_adjectives_old|common_adjectives_young|common_adjectives_good|common_adjectives_bad|common_adjectives_beautiful|common_adjectives_ugly|common_adjectives_easy|common_adjectives_difficult|common_adjectives_clean|common_adjectives_dirty|common_adjectives_full|common_adjectives_empty|common_adjectives_heavy|common_adjectives_light|common_adjectives_strong|common_adjectives_weak|common_adjectives_rich|common_adjectives_poor|common_adjectives_different',
    'feelings':
        'feelings_happy|feelings_sad|feelings_angry|feelings_afraid|feelings_surprised|feelings_excited|feelings_tired|feelings_bored|feelings_calm|feelings_worried|feelings_nervous|feelings_proud|feelings_shy|feelings_lonely|feelings_loved|feelings_comfortable|feelings_uncomfortable|feelings_hungry|feelings_thirsty|feelings_sleepy|feelings_sick|feelings_well|feelings_confused|feelings_curious|feelings_hopeful|feelings_disappointed|feelings_jealous|feelings_embarrassed|feelings_thankful|feelings_relaxed',
    'jobs':
        'jobs_job|jobs_worker|jobs_farmer|jobs_chef|jobs_waiter|jobs_waitress|jobs_driver|jobs_pilot|jobs_engineer|jobs_architect|jobs_mechanic|jobs_electrician|jobs_plumber|jobs_carpenter|jobs_dentist|jobs_veterinarian|jobs_police_officer|jobs_firefighter|jobs_soldier|jobs_lawyer|jobs_judge|jobs_artist|jobs_musician|jobs_actor|jobs_photographer|jobs_scientist|jobs_programmer|jobs_hairdresser|jobs_tailor|jobs_cashier',
    'shopping':
        'shopping_shopping|shopping_store|shopping_customer|shopping_seller|shopping_price|shopping_money|shopping_coin|shopping_cash|shopping_banknote|shopping_wallet|shopping_basket|shopping_trolley|shopping_receipt|shopping_change|shopping_discount|shopping_sale|shopping_cost|shopping_checkout|shopping_product|shopping_item|shopping_shopping_list|shopping_choice|shopping_cheap|shopping_expensive|shopping_buy|shopping_pay|shopping_try_on|shopping_fit|shopping_cash_register|shopping_shopping_bag',
    'restaurant':
        'restaurant_menu|restaurant_order|restaurant_server|restaurant_table_reservation|restaurant_meal|restaurant_starter|restaurant_main_course|restaurant_dessert|restaurant_drink|restaurant_glass|restaurant_plate|restaurant_bowl|restaurant_fork|restaurant_knife|restaurant_spoon|restaurant_napkin|restaurant_bill|restaurant_tip|restaurant_service|restaurant_dish|restaurant_taste|restaurant_delicious|restaurant_spicy|restaurant_sweet|restaurant_salty|restaurant_sour|restaurant_fresh|restaurant_ready|restaurant_portion|restaurant_tray',
    'travel':
        'travel_travel|travel_journey|travel_trip|travel_tourist|travel_guide|travel_route|travel_direction|travel_north|travel_south|travel_east|travel_west|travel_left|travel_right|travel_straight_ahead|travel_turn|travel_distance|travel_destination|travel_departure|travel_arrival|travel_passport|travel_visa|travel_luggage|travel_suitcase|travel_backpack|travel_platform|travel_gate|travel_border|travel_abroad|travel_local|travel_lost',
    'hotel':
        'hotel_hotel|hotel_stay|hotel_reception|hotel_receptionist|hotel_lobby|hotel_guest|hotel_room_key|hotel_key_card|hotel_single_room|hotel_double_room|hotel_suite|hotel_pillow|hotel_blanket|hotel_towel|hotel_elevator|hotel_stairs|hotel_room_service|hotel_housekeeping|hotel_check_in|hotel_check_out|hotel_booking|hotel_vacancy|hotel_available|hotel_occupied|hotel_bell|hotel_porter|hotel_wake_up_call|hotel_laundry|hotel_minibar|hotel_wifi',
    'communication':
        'communication_communication|communication_message|communication_call|communication_phone|communication_mobile_phone|communication_telephone|communication_email|communication_letter|communication_postcard|communication_conversation|communication_chat|communication_voice|communication_sound|communication_word|communication_sentence|communication_language|communication_reply|communication_ask|communication_tell|communication_explain|communication_repeat|communication_understand|communication_mean|communication_spell|communication_listen|communication_talk|communication_text|communication_online|communication_offline|communication_signal',
  };

  test('içerik paketi 30 kategoride toplam 900 kelime içerir', () {
    expect(CategoryCatalog.categories, hasLength(30));
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
      'jobs',
      'shopping',
      'restaurant',
      'travel',
      'hotel',
      'communication',
      'technology',
      'hobbies',
      'sports',
      'music',
      'movies_tv',
      'books_reading',
    ]);

    final allWords = CategoryCatalog.categories
        .expand((category) => category.words)
        .toList(growable: false);
    expect(allWords, hasLength(900));
    expect(allWords.map((word) => word.id).toSet(), hasLength(900));
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

  test('mevcut 720 kelimenin kimlikleri ve sırası korunur', () {
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
    expect(existingWordCount, 720);
  });

  test('yeni kelime kimlikleri kararlı kategori öneklerini kullanır', () {
    for (final categoryId in [
      'technology',
      'hobbies',
      'sports',
      'music',
      'movies_tv',
      'books_reading',
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

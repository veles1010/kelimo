import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/data/bathroom_personal_care_words.dart';
import 'package:kelimo/data/cleaning_chore_words.dart';
import 'package:kelimo/data/garden_words.dart';
import 'package:kelimo/data/geography_words.dart';
import 'package:kelimo/data/holiday_celebration_words.dart';
import 'package:kelimo/data/kitchen_cooking_words.dart';
import 'package:kelimo/data/basic_verb_words.dart';
import 'package:kelimo/data/book_reading_words.dart';
import 'package:kelimo/data/body_words.dart';
import 'package:kelimo/data/city_place_words.dart';
import 'package:kelimo/data/clothing_words.dart';
import 'package:kelimo/data/color_words.dart';
import 'package:kelimo/data/common_adjective_words.dart';
import 'package:kelimo/data/communication_words.dart';
import 'package:kelimo/data/daily_routine_words.dart';
import 'package:kelimo/data/family_words.dart';
import 'package:kelimo/data/feeling_words.dart';
import 'package:kelimo/data/food_words.dart';
import 'package:kelimo/data/health_words.dart';
import 'package:kelimo/data/home_words.dart';
import 'package:kelimo/data/hotel_words.dart';
import 'package:kelimo/data/hobby_words.dart';
import 'package:kelimo/data/job_words.dart';
import 'package:kelimo/data/movie_tv_words.dart';
import 'package:kelimo/data/music_words.dart';
import 'package:kelimo/data/nature_weather_words.dart';
import 'package:kelimo/data/number_quantity_words.dart';
import 'package:kelimo/data/restaurant_words.dart';
import 'package:kelimo/data/school_words.dart';
import 'package:kelimo/data/shopping_words.dart';
import 'package:kelimo/data/sport_words.dart';
import 'package:kelimo/data/technology_words.dart';
import 'package:kelimo/data/transportation_words.dart';
import 'package:kelimo/data/time_date_words.dart';
import 'package:kelimo/data/travel_words.dart';
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

  static const natureWeather = LearningCategory(
    id: 'nature_weather',
    title: 'Doğa ve Hava Durumu',
    emoji: '🌦️',
    words: natureWeatherWords,
  );

  static const timeDates = LearningCategory(
    id: 'time_dates',
    title: 'Zaman ve Tarihler',
    emoji: '🗓️',
    words: timeDateWords,
  );

  static const numbersQuantities = LearningCategory(
    id: 'numbers_quantities',
    title: 'Sayılar ve Miktarlar',
    emoji: '🔢',
    words: numberQuantityWords,
  );

  static const basicVerbs = LearningCategory(
    id: 'basic_verbs',
    title: 'Temel Fiiller',
    emoji: '🏃',
    words: basicVerbWords,
  );

  static const commonAdjectives = LearningCategory(
    id: 'common_adjectives',
    title: 'Yaygın Sıfatlar',
    emoji: '✨',
    words: commonAdjectiveWords,
  );

  static const feelings = LearningCategory(
    id: 'feelings',
    title: 'Duygular',
    emoji: '😊',
    words: feelingWords,
  );

  static const jobs = LearningCategory(
    id: 'jobs',
    title: 'Meslekler',
    emoji: '💼',
    words: jobWords,
  );

  static const shopping = LearningCategory(
    id: 'shopping',
    title: 'Alışveriş',
    emoji: '🛍️',
    words: shoppingWords,
  );

  static const restaurant = LearningCategory(
    id: 'restaurant',
    title: 'Restoran',
    emoji: '🍽️',
    words: restaurantWords,
  );

  static const travel = LearningCategory(
    id: 'travel',
    title: 'Seyahat',
    emoji: '🧭',
    words: travelWords,
  );

  static const hotel = LearningCategory(
    id: 'hotel',
    title: 'Otel',
    emoji: '🏨',
    words: hotelWords,
  );

  static const communication = LearningCategory(
    id: 'communication',
    title: 'İletişim',
    emoji: '💬',
    words: communicationWords,
  );

  static const technology = LearningCategory(
    id: 'technology',
    title: 'Teknoloji',
    emoji: '💻',
    words: technologyWords,
  );
  static const hobbies = LearningCategory(
    id: 'hobbies',
    title: 'Hobiler',
    emoji: '🎨',
    words: hobbyWords,
  );
  static const sports = LearningCategory(
    id: 'sports',
    title: 'Spor',
    emoji: '🏅',
    words: sportWords,
  );
  static const music = LearningCategory(
    id: 'music',
    title: 'Müzik',
    emoji: '🎵',
    words: musicWords,
  );
  static const moviesTv = LearningCategory(
    id: 'movies_tv',
    title: 'Film ve Televizyon',
    emoji: '🎬',
    words: movieTvWords,
  );
  static const booksReading = LearningCategory(
    id: 'books_reading',
    title: 'Kitaplar ve Okuma',
    emoji: '📚',
    words: bookReadingWords,
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
    natureWeather,
    timeDates,
    numbersQuantities,
    basicVerbs,
    commonAdjectives,
    feelings,
    jobs,
    shopping,
    restaurant,
    travel,
    hotel,
    communication,
    technology,
    hobbies,
    sports,
    music,
    moviesTv,
    booksReading,
    kitchenCooking,
    bathroomPersonalCare,
    garden,
    cleaningChores,
    geography,
    holidaysCelebrations,
  ];

  static const kitchenCooking = LearningCategory(
    id: 'kitchen_cooking',
    title: 'Mutfak ve Yemek Yapma',
    emoji: '🍳',
    words: kitchenCookingWords,
  );
  static const bathroomPersonalCare = LearningCategory(
    id: 'bathroom_personal_care',
    title: 'Banyo ve Kişisel Bakım',
    emoji: '🛁',
    words: bathroomPersonalCareWords,
  );
  static const garden = LearningCategory(
    id: 'garden',
    title: 'Bahçe',
    emoji: '🌻',
    words: gardenWords,
  );
  static const cleaningChores = LearningCategory(
    id: 'cleaning_chores',
    title: 'Temizlik ve Ev İşleri',
    emoji: '🧹',
    words: cleaningChoreWords,
  );
  static const geography = LearningCategory(
    id: 'geography',
    title: 'Coğrafya',
    emoji: '🌍',
    words: geographyWords,
  );
  static const holidaysCelebrations = LearningCategory(
    id: 'holidays_celebrations',
    title: 'Tatiller ve Kutlamalar',
    emoji: '🎉',
    words: holidayCelebrationWords,
  );

  static LearningCategory? findById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

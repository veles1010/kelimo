import 'package:kelimo/models/achievement.dart';

abstract final class AchievementCatalog {
  static const achievements = <Achievement>[
    Achievement(
      id: 'first_step',
      title: 'İlk Adım',
      description: 'İlk kelime değerlendirmeni tamamla.',
      emoji: '👣',
      target: 1,
      type: AchievementType.totalReviews,
    ),
    Achievement(
      id: 'review_master',
      title: 'Tekrar Ustası',
      description: 'Toplam 10 kelime değerlendirmesi yap.',
      emoji: '🔁',
      target: 10,
      type: AchievementType.totalReviews,
    ),
    Achievement(
      id: 'learned_10',
      title: 'Kelime Avcısı',
      description: '10 kelime öğren.',
      emoji: '🧭',
      target: 10,
      type: AchievementType.learnedWords,
    ),
    Achievement(
      id: 'learned_50',
      title: 'Kelime Ustası',
      description: '50 kelime öğren.',
      emoji: '🎓',
      target: 50,
      type: AchievementType.learnedWords,
    ),
    Achievement(
      id: 'learned_100',
      title: 'Sözlük Gibi',
      description: '100 kelime öğren.',
      emoji: '📚',
      target: 100,
      type: AchievementType.learnedWords,
    ),
    Achievement(
      id: 'favorites_5',
      title: 'Kalp Koleksiyoncusu',
      description: '5 kelimeyi favorilerine ekle.',
      emoji: '❤️',
      target: 5,
      type: AchievementType.favorites,
    ),
    Achievement(
      id: 'first_quiz',
      title: 'İlk Quiz',
      description: 'İlk quizini tamamla.',
      emoji: '📝',
      target: 1,
      type: AchievementType.completedQuizzes,
    ),
    Achievement(
      id: 'perfect_quiz',
      title: 'Kusursuz Sonuç',
      description: 'Bir quizde yüzde 100 başarı elde et.',
      emoji: '🏆',
      target: 1,
      type: AchievementType.perfectQuiz,
    ),
    Achievement(
      id: 'quiz_10',
      title: 'Quiz Tutkunu',
      description: '10 quiz tamamla.',
      emoji: '⚡',
      target: 10,
      type: AchievementType.completedQuizzes,
    ),
    Achievement(
      id: 'streak_3',
      title: 'Üç Günlük Seri',
      description: '3 günlük çalışma serisine ulaş.',
      emoji: '🔥',
      target: 3,
      type: AchievementType.streak,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Haftalık Seri',
      description: '7 günlük çalışma serisine ulaş.',
      emoji: '🔥',
      target: 7,
      type: AchievementType.streak,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Vazgeçmeyen',
      description: '30 günlük çalışma serisine ulaş.',
      emoji: '🏅',
      target: 30,
      type: AchievementType.streak,
    ),
    Achievement(
      id: 'mosaic_master',
      title: 'Kelimo Ustası',
      description: 'Gizli Mozaik’in 1080 parçasını keşfet.',
      emoji: '🖼️',
      target: 1080,
      type: AchievementType.mosaicCompletion,
    ),
  ];

  static Achievement? findById(String id) {
    for (final achievement in achievements) {
      if (achievement.id == id) return achievement;
    }
    return null;
  }
}

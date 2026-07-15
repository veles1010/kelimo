// Explicit public IDs map to a private override so legacy words can keep
// deriving their unchanged IDs from English text.
// ignore_for_file: prefer_initializing_formals

class Word {
  const Word({
    String? id,
    required this.english,
    required this.turkish,
    required this.emoji,
    required this.exampleSentence,
    required this.exampleTranslation,
  }) : _id = id;

  final String? _id;
  final String english;
  final String turkish;
  final String emoji;
  final String exampleSentence;
  final String exampleTranslation;

  String get id => _id ?? english.toLowerCase();
}

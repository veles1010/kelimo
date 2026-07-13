const _turkishUppercaseLetters = <String, String>{
  'a': 'A',
  'b': 'B',
  'c': 'C',
  'ç': 'Ç',
  'd': 'D',
  'e': 'E',
  'f': 'F',
  'g': 'G',
  'ğ': 'Ğ',
  'h': 'H',
  'ı': 'I',
  'i': 'İ',
  'j': 'J',
  'k': 'K',
  'l': 'L',
  'm': 'M',
  'n': 'N',
  'o': 'O',
  'ö': 'Ö',
  'p': 'P',
  'q': 'Q',
  'r': 'R',
  's': 'S',
  'ş': 'Ş',
  't': 'T',
  'u': 'U',
  'ü': 'Ü',
  'v': 'V',
  'w': 'W',
  'x': 'X',
  'y': 'Y',
  'z': 'Z',
};

String toTurkishUpperCase(String value) {
  final result = StringBuffer();

  for (final codeUnit in value.codeUnits) {
    final character = String.fromCharCode(codeUnit);
    result.write(_turkishUppercaseLetters[character] ?? character);
  }

  return result.toString();
}

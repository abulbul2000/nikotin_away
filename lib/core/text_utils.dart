/// Normalizes Turkish text for case/diacritic-insensitive comparisons
/// (e.g. matching a stored trigger label against a lowercase lookup key).
///
/// Converts 'İ' to ASCII 'I' *before* lowercasing — Dart's [String.toLowerCase]
/// uses default Unicode case folding, which turns 'İ' (U+0130) into 'i̇'
/// (a plain 'i' plus a combining dot above), not a plain 'i'. Doing the
/// ASCII substitution first avoids that mismatch. This was previously
/// duplicated with two different (and differently correct) implementations
/// in `BehaviorEngine` and `MentorEngine`.
String normalizeTurkishText(String value) {
  return value
      .trim()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'I')
      .replaceAll('ğ', 'g')
      .replaceAll('Ğ', 'G')
      .replaceAll('ş', 's')
      .replaceAll('Ş', 'S')
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'O')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'U')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'C')
      .toLowerCase();
}

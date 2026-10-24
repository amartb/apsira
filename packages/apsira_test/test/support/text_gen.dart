// From relay test/support/prop/text_gen.dart @ 09b28810: its generic part
// (hasLoneSurrogate and TextGens.text), which prop_core_test.dart uses. The
// domain generators (words, block ids, Markdown) stay in each app.

/// Generators for text: strings mixing ASCII, Spanish and emoji.
library;

import 'package:apsira_test/apsira_test.dart';

/// Whether [s] holds a UTF-16 surrogate that is not half of a pair.
bool hasLoneSurrogate(String s) {
  for (var i = 0; i < s.length; i++) {
    final u = s.codeUnitAt(i);
    if (u >= 0xD800 && u <= 0xDBFF) {
      final next = i + 1 < s.length ? s.codeUnitAt(i + 1) : 0;
      if (next < 0xDC00 || next > 0xDFFF) return true;
      i++;
    } else if (u >= 0xDC00 && u <= 0xDFFF) {
      return true;
    }
  }
  return false;
}

List<String> _chars(String from, String to) => [
  for (var c = from.codeUnitAt(0); c <= to.codeUnitAt(0); c++)
    String.fromCharCode(c),
];

abstract final class TextGens {
  /// Letters first, so ASCII shrinks towards `a`. No backtick and no
  /// newline: fences and lines are the Markdown generator's business.
  static final List<String> asciiAtoms = List.unmodifiable([
    ..._chars('a', 'z'),
    ..._chars('A', 'Z'),
    ..._chars('0', '9'),
    ...' .,;:!?\'"()-_/*[]#@&%+='.split(''),
  ]);

  /// Precomposed accents and Spanish punctuation, plus two decomposed forms
  /// (a base letter and a combining mark) that NFC folds into one.
  static const List<String> spanishAtoms = [
    'á', 'é', 'í', 'ó', 'ú', 'ü', 'ñ', '¿', '¡', //
    'Á', 'É', 'Í', 'Ó', 'Ú', 'Ü', 'Ñ', //
    'é', 'ñ',
  ];

  /// Emoji: single surrogate pairs first (so a string shrinks to `😀`), BMP
  /// emoji with a variation selector, a skin-tone modifier, flags, and ZWJ
  /// sequences.
  static const List<String> emojiAtoms = [
    '\u{1F600}', // grinning face
    '\u{1F389}', // party popper
    '\u{1F4DD}', // memo
    '\u{2705}', // check mark button (BMP)
    '\u{2764}\u{FE0F}', // red heart + VS16
    '\u{1F44D}\u{1F3FD}', // thumbs up + skin tone
    '\u{1F1EA}\u{1F1F8}', // flag ES
    '\u{1F1F2}\u{1F1FD}', // flag MX
    '\u{1F469}\u{200D}\u{1F4BB}', // woman technologist (ZWJ)
    '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}', // family (ZWJ)
    '\u{1F3F3}\u{FE0F}\u{200D}\u{1F308}', // rainbow flag (ZWJ)
    '\u{1F9D1}\u{1F3FD}\u{200D}\u{1F680}', // astronaut + skin tone (ZWJ)
  ];

  /// One atom: ASCII, a Spanish character or an emoji, shrinking towards
  /// ASCII. Atoms are joined, so a shrink never splits a surrogate pair.
  static final Gen<String> atom = Gens.frequency([
    (6, Gens.elementOf(asciiAtoms)),
    (2, Gens.elementOf(spanishAtoms)),
    (2, Gens.elementOf(emojiAtoms)),
  ]);

  /// A single-line string of [min]..[max] atoms (up to the case size).
  static Gen<String> text({int min = 0, int? max}) =>
      Gens.listOf(atom, min: min, max: max).map((parts) => parts.join());
}

// From relay test/support/prop/text_gen.dart @ 09b28810
/// Generators for text: strings mixing ASCII, Spanish and emoji, block IDs,
/// and Markdown fragments in Relay's syntax (headings, lists, checkboxes with
/// `^id`s, links, wiki-links, code fences, inline tags).
library;

import 'prop_core.dart';

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

  static final List<String> _lower = [
    ..._chars('a', 'z'),
    'á', 'é', 'í', 'ó', 'ú', 'ü', 'ñ', //
  ];

  /// A word of letters, Spanish ones included (no Markdown syntax).
  static final Gen<String> word = Gens.listOf(
    Gens.elementOf(_lower),
    min: 1,
    max: 10,
  ).map((cs) => cs.join());

  static final Gen<String> _words = Gens.listOf(
    word,
    min: 1,
    max: 4,
  ).map((ws) => ws.join(' '));

  /// A task-line block ID: 6 characters of `a–z0–9` (data model §6.5).
  static final Gen<String> blockId = Gens.listOf(
    Gens.elementOf([..._chars('a', 'z'), ..._chars('0', '9')]),
    min: 6,
    max: 6,
  ).map((cs) => cs.join());

  /// `#tag`, `#año`, `#proyecto/relay-2026`.
  static final Gen<String> tag = Gens.zip(
    word,
    Gens.optional(
      Gens.listOf(
        Gens.elementOf([..._lower, ..._chars('0', '9'), '-', '_']),
        min: 1,
        max: 8,
      ).map((cs) => cs.join()),
      presentWeight: 1,
    ),
  ).map((v) => v.$2 == null ? '#${v.$1}' : '#${v.$1}/${v.$2}');

  static final Gen<String> link = Gens.zip3(
    _words,
    Gens.elementOf(const ['https://example.com/', 'https://example.org/n/']),
    word,
  ).map((v) => '[${v.$1}](${v.$2}${Uri.encodeComponent(v.$3)})');

  /// `[[Note]]`, `[[Note|alias]]` or `[[Note#Heading]]`.
  static final Gen<String> wikiLink = Gens.zip3(
    _words,
    Gens.elementOf(const ['', '|', '#']),
    word,
  ).map((v) => v.$2.isEmpty ? '[[${v.$1}]]' : '[[${v.$1}${v.$2}${v.$3}]]');

  static final Gen<String> _inline = Gens.listOf(
    Gens.frequency([(6, word), (1, tag), (1, link), (1, wikiLink)]),
    min: 1,
    max: 8,
  ).map((ps) => ps.join(' '));

  static final Gen<String> _indent = Gens.elementOf(const ['', '  ', '    ']);

  static final Gen<String> _heading = Gens.zip(
    Gens.intRange(1, 6),
    _inline,
  ).map((v) => '${'#' * v.$1} ${v.$2}');

  static final Gen<String> _bullet = Gens.zip3(
    _indent,
    Gens.elementOf(const ['- ', '* ', '1. ']),
    _inline,
  ).map((v) => '${v.$1}${v.$2}${v.$3}');

  /// `- [s] text ^abc123`, statuses ' ' / x - (D-036), the ID optional.
  static final Gen<String> _task =
      Gens.zip3(
        Gens.zip(_indent, Gens.elementOf(const [' ', '/', 'x', '-'])),
        _inline,
        Gens.optional(blockId),
      ).map(
        (v) =>
            '${v.$1.$1}- [${v.$1.$2}] ${v.$2}'
            '${v.$3 == null ? '' : ' ^${v.$3}'}',
      );

  /// A fenced block; one in five is left unclosed, as typing leaves it.
  static final Gen<String> _fence = Gens.zip3(
    Gens.elementOf(const ['', 'dart', 'sql', 'md']),
    Gens.listOf(text(max: 12), max: 4),
    Gens.frequency([(4, Gens.constant(true)), (1, Gens.constant(false))]),
  ).map((v) => ['```${v.$1}', ...v.$2, if (v.$3) '```'].join('\n'));

  /// One block, shrinking towards a plain paragraph.
  static final Gen<String> block = Gens.frequency([
    (4, _inline),
    (2, _heading),
    (3, _bullet),
    (4, _task),
    (1, _fence),
    (2, Gens.constant('')),
  ]);

  /// A Markdown fragment: blocks joined by newlines.
  static Gen<String> markdown({int min = 0, int? max}) =>
      Gens.listOf(block, min: min, max: max).map((bs) => bs.join('\n'));
}

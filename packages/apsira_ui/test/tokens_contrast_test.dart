// From relay test/critical/tokens_contrast_test.dart @ 5f606e9
// RELAY's critical suite `tokens_contrast` (08 §3): every colour token pair the UX
// spec puts together meets WCAG 2.x AA in both themes (D-056, D-059, D-065,
// D-066), and so does every user-colour family (UX §2.2 "Users never pick
// raw hex values").
//
// - Text tokens on every surface they are used on: >= 4.5:1.
// - UI tokens (the checkbox `ring`, `accentFill`, every family solid) on the
//   surfaces they sit on: >= 3:1 (WCAG 1.4.11).
// - Every content-on-fill pair (`onAccent` on `accentFill`, every
//   on-container on its container, the Material ColorScheme on-pairs):
//   >= 4.5:1.
// - The status pill's leading dot (UX §2.2 "Statuses get a pill with a
//   leading dot"; the note screen's meta strip, 07 P1-06): every family's
//   solid on its own container, >= 3:1 (07 CB F-1 of unit
//   p0-unit1-pipeline-foundations; the lowest pair was 3.41:1).
//
// `border` and `line` are decorative edges, outside the matrix (assumption
// A5): a card's edge is also carried by the ground -> surface step (D-066).
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double textMinimum = 4.5;
const double uiMinimum = 3;

/// WCAG 2.x contrast ratio of two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// One foreground/background pair and the ratio it must meet.
class Pair {
  const Pair(this.name, this.foreground, this.background, this.minimum);

  final String name;
  final Color foreground;
  final Color background;
  final double minimum;
}

/// Checks every pair and returns one line per failure, so a red run names
/// every failing pair at once.
List<String> failures(List<Pair> pairs) {
  final out = <String>[];
  for (final p in pairs) {
    expect(p.foreground.a, 1.0, reason: '${p.name}: foreground must be opaque');
    expect(p.background.a, 1.0, reason: '${p.name}: background must be opaque');
    final ratio = contrastRatio(p.foreground, p.background);
    if (ratio < p.minimum) {
      out.add(
        '${p.name}: ${hex(p.foreground)} on ${hex(p.background)} is '
        '${ratio.toStringAsFixed(2)}:1, needs ${p.minimum}:1',
      );
    }
  }
  return out;
}

Map<String, Color> surfaces(ApsiraTheme t) => {
  'ground': t.ground,
  'surface': t.surface,
  'tint': t.tint,
  'panel': t.panel,
};

List<Pair> textPairs(ApsiraTheme t) => [
  for (final text in {
    'ink': t.ink,
    'ink2': t.ink2,
    'ink3': t.ink3,
    'accentText': t.accentText,
  }.entries)
    for (final s in surfaces(t).entries)
      Pair('${text.key} on ${s.key}', text.value, s.value, textMinimum),
];

List<Pair> uiPairs(ApsiraTheme t) => [
  for (final ui in {
    'ring': t.ring,
    'accentFill': t.accentFill,
    for (final f in ApsiraFamily.values) '${f.name} solid': t.family(f).solid,
  }.entries)
    for (final s in surfaces(t).entries)
      Pair('${ui.key} on ${s.key}', ui.value, s.value, uiMinimum),
];

List<Pair> fillPairs(ApsiraTheme t) => [
  Pair('onAccent on accentFill', t.onAccent, t.accentFill, textMinimum),
  Pair('onAccC on accC', t.onAccC, t.accC, textMinimum),
  for (final f in ApsiraFamily.values)
    Pair(
      '${f.name} onContainer on container',
      t.family(f).onContainer,
      t.family(f).container,
      textMinimum,
    ),
];

/// The status pill's dot: each family's solid on the pill's fill, its own
/// container (a UI mark, so 3:1).
List<Pair> statusDotPairs(ApsiraTheme t) => [
  for (final f in ApsiraFamily.values)
    Pair(
      '${f.name} solid on container (status dot)',
      t.family(f).solid,
      t.family(f).container,
      uiMinimum,
    ),
];

List<Pair> colorSchemePairs(ColorScheme c) => [
  Pair('onPrimary on primary', c.onPrimary, c.primary, textMinimum),
  Pair(
    'onPrimaryContainer on primaryContainer',
    c.onPrimaryContainer,
    c.primaryContainer,
    textMinimum,
  ),
  Pair('onSecondary on secondary', c.onSecondary, c.secondary, textMinimum),
  Pair(
    'onSecondaryContainer on secondaryContainer',
    c.onSecondaryContainer,
    c.secondaryContainer,
    textMinimum,
  ),
  Pair('onTertiary on tertiary', c.onTertiary, c.tertiary, textMinimum),
  Pair(
    'onTertiaryContainer on tertiaryContainer',
    c.onTertiaryContainer,
    c.tertiaryContainer,
    textMinimum,
  ),
  Pair('onError on error', c.onError, c.error, textMinimum),
  Pair(
    'onErrorContainer on errorContainer',
    c.onErrorContainer,
    c.errorContainer,
    textMinimum,
  ),
  Pair('onSurface on surface', c.onSurface, c.surface, textMinimum),
  Pair(
    'onSurfaceVariant on surface',
    c.onSurfaceVariant,
    c.surface,
    textMinimum,
  ),
  Pair(
    'onSurface on surfaceContainerHighest',
    c.onSurface,
    c.surfaceContainerHighest,
    textMinimum,
  ),
  Pair(
    'onInverseSurface on inverseSurface',
    c.onInverseSurface,
    c.inverseSurface,
    textMinimum,
  ),
  Pair(
    'inversePrimary on inverseSurface',
    c.inversePrimary,
    c.inverseSurface,
    textMinimum,
  ),
  Pair('outline on surface', c.outline, c.surface, uiMinimum),
];

void main() {
  for (final theme in [ApsiraTheme.light, ApsiraTheme.dark]) {
    group('tokens_contrast (${theme.brightness.name})', () {
      test('text tokens on every surface >= 4.5:1', () {
        expect(failures(textPairs(theme)), isEmpty);
      });

      test('UI tokens (ring, accentFill, family solids) >= 3:1', () {
        expect(failures(uiPairs(theme)), isEmpty);
      });

      test('content on fills and every on-container pair >= 4.5:1', () {
        expect(failures(fillPairs(theme)), isEmpty);
      });

      test('status-pill dots (family solid on its container) >= 3:1', () {
        expect(failures(statusDotPairs(theme)), isEmpty);
        expect(statusDotPairs(theme), hasLength(ApsiraFamily.values.length));
      });

      test('every user-colour family is covered', () {
        // A new family is checked automatically: the pairs iterate the enum.
        final names = uiPairs(theme).map((p) => p.name).join('\n');
        for (final f in ApsiraFamily.values) {
          expect(names, contains('${f.name} solid'));
        }
      });

      test('Material ColorScheme on-pairs >= 4.5:1, outline >= 3:1', () {
        expect(
          failures(colorSchemePairs(ApsiraThemeData.colorScheme(theme))),
          isEmpty,
        );
      });
    });
  }

  test('contrastRatio matches the WCAG reference values', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 1e-9),
    );
    expect(
      contrastRatio(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
    );
  });
}

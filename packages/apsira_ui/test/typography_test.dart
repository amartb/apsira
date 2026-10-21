// From relay test/app/theme/relay_typography_test.dart @ 5f606e9
// The typography scale: every UX §2.3 style is a named `ApsiraTypeStyle`
// whose ranges are read back from the spec table (copied as a constant).
// Archivo Expanded is never used below 20 px except for numerals and the
// wordmark (D-055). Every style names its family package-qualified, so a
// consumer app resolves the fonts this package bundles.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX §2.3's table rows, verbatim from RELAY's docs/06 at 5f606e9.
const specTable = [
  '| `display` | Archivo Expanded | 34 / 40 | 600 | Screen large titles (Friday, Tasks), list titles (Meeting: 32) |',
  '| `numeral` | Archivo Expanded, tabular | 28–68 | 500–600 | Stat tiles, the recorder timer, date pills |',
  '| `wordmark` | Archivo Expanded, +0.10–0.14 em | 20–40 | 600 | RELAY in the drawer and the intro |',
  '| `slideTitle` | Archivo Expanded | 28 / 34 | 600 | Tutorial titles |',
  '| `noteTitle` | Archivo | 30 / 36, −0.01 em | 700 | The title in the editor |',
  '| `cardTitle` | Archivo | 18 / 24 | 700 | Card headers (Today, Recent, Overdue) |',
  '| `h2` | Archivo | 21 / 28 | 700 | Body headings (H3: 18 / 24) |',
  '| `rowTitle` | Archivo | 16–17 / 22–23 | 600–700 | Note and task titles in rows |',
  '| `body` | Archivo | 16 / 25 | 400 | Editor body, slide copy (`ink2`) |',
  '| `snippet` | Archivo | 14 / 20–21 | 400 | Previews, up to 2 lines in lists, 1 on Home |',
  '| `pill` | Archivo | 12.5–13 / 16 | 600–700 | Every chip and pill |',
  '| `meta` | Archivo | 13 / 18 | 500–600 | Times, sources, counts (`ink3`) |',
];

/// UX §2.3's table rows, each split into trimmed cells.
List<List<String>> specRows() =>
    specTable.map((l) => l.split('|').map((c) => c.trim()).toList()).toList();

/// `16–17` → (16, 17); `34` → (34, 34). Accepts the spec's en dash.
(double, double) range(String s) {
  final parts = s.split('–').map((p) => double.parse(p.trim())).toList();
  return (parts.first, parts.last);
}

/// The em letter-spacing range in [cell] (`+0.10–0.14 em`, `−0.01 em`), or
/// (0, 0) when the cell has none.
(double, double) emRange(String cell) {
  final m = RegExp(r'([+−-]?)([\d.]+)(?:–([\d.]+))? em').firstMatch(cell);
  if (m == null) return (0, 0);
  final sign = m.group(1) == '−' || m.group(1) == '-' ? -1.0 : 1.0;
  final lo = double.parse(m.group(2)!) * sign;
  final hi = m.group(3) == null ? lo : double.parse(m.group(3)!) * sign;
  return (lo, hi);
}

/// One parsed spec row.
typedef Spec = ({
  String family,
  (double, double) size,
  (double, double)? line,
  (int, int) weight,
  (double, double) em,
  bool tabular,
});

Spec parse(List<String> row) {
  final font = row[2];
  final sizeCell = row[3].split(',').first;
  final sizes = sizeCell.split('/');
  final weights = range(row[4]);
  return (
    family: font.startsWith('Archivo Expanded')
        ? ApsiraFonts.archivoExpanded
        : ApsiraFonts.archivo,
    size: range(sizes[0]),
    line: sizes.length > 1 ? range(sizes[1]) : null,
    weight: (weights.$1.toInt(), weights.$2.toInt()),
    em: emRange('$font ${row[3]}'),
    tabular: font.contains('tabular'),
  );
}

void expectMatches(ApsiraTypeStyle s, Spec spec) {
  final r = 'style `${s.name}`';
  expect(s.family, spec.family, reason: '$r family');
  expect(s.size, spec.size, reason: '$r size');
  expect(s.line, spec.line, reason: '$r line height');
  expect(s.weight, spec.weight, reason: '$r weight');
  expect(s.trackingEm, spec.em, reason: '$r letter spacing');
  expect(s.tabular, spec.tabular, reason: '$r tabular figures');
}

void main() {
  group('the scale matches UX §2.3', () {
    test('every table row is a named style with its documented values', () {
      final rows = specRows();
      expect(rows, hasLength(12));
      for (final row in rows) {
        final name = RegExp(r'`(\w+)`').firstMatch(row[1])!.group(1)!;
        final style = ApsiraTypeStyle.values.byName(name);
        var spec = parse(row);
        if (style == ApsiraTypeStyle.display) {
          // "list titles (Meeting: 32)" in the Use column: the display row
          // spans 32–34 inside its one documented line box.
          final listTitle = RegExp(r'Meeting: (\d+)').firstMatch(row[5])!;
          spec = (
            family: spec.family,
            size: (double.parse(listTitle.group(1)!), spec.size.$2),
            line: spec.line,
            weight: spec.weight,
            em: spec.em,
            tabular: spec.tabular,
          );
        }
        expectMatches(style, spec);
      }
    });

    test('H3 is the documented 18 / 24 Archivo 700', () {
      final h2 = specRows().firstWhere((r) => r[1] == '`h2`');
      final m = RegExp(r'H3: (\d+) / (\d+)').firstMatch(h2[5])!;
      final px = double.parse(m.group(1)!);
      final line = double.parse(m.group(2)!);
      expectMatches(ApsiraTypeStyle.h3, (
        family: ApsiraFonts.archivo,
        size: (px, px),
        line: (line, line),
        weight: (700, 700),
        em: (0, 0),
        tabular: false,
      ));
    });

    test('there is no style beyond the table and H3', () {
      final named = {
        for (final r in specRows()) RegExp(r'`(\w+)`').firstMatch(r[1])![1],
      };
      expect(ApsiraTypeStyle.values.map((s) => s.name).toSet(), {
        ...named,
        'h3',
      });
    });
  });

  group('D-055: Archivo Expanded only at 20 px and above', () {
    test('every Expanded style but numeral and wordmark starts at 20', () {
      for (final s in ApsiraTypeStyle.values) {
        if (s.family != ApsiraFonts.archivoExpanded) continue;
        if (s == ApsiraTypeStyle.numeral || s == ApsiraTypeStyle.wordmark) {
          continue;
        }
        expect(s.size.$1, greaterThanOrEqualTo(20), reason: s.name);
      }
    });

    test('no Expanded style can be built below its documented size', () {
      for (final s in ApsiraTypeStyle.values) {
        expect(
          () => s.at(size: s.size.$1 - 1),
          throwsArgumentError,
          reason: s.name,
        );
      }
    });

    test('body text never drops below 14 px (UX §2.3)', () {
      for (final s in [ApsiraTypeStyle.body, ApsiraTypeStyle.snippet]) {
        expect(s.size.$1, greaterThanOrEqualTo(14), reason: s.name);
      }
    });
  });

  group('TextStyle', () {
    test('the base style is the lower bound of each range', () {
      for (final s in ApsiraTypeStyle.values) {
        final t = s.style;
        final px = s == ApsiraTypeStyle.display ? 34.0 : s.size.$1;
        expect(t.fontFamily, 'packages/apsira_ui/${s.family}', reason: s.name);
        expect(t.fontSize, px, reason: s.name);
        expect(t.fontWeight, FontWeight.values[s.weight.$1 ~/ 100 - 1]);
        expect(t.letterSpacing, closeTo(s.trackingEm.$1 * px, 1e-9));
        if (s.line == null) {
          expect(t.height, isNull, reason: s.name);
        } else {
          expect(t.height! * px, closeTo(s.line!.$1, 1e-9), reason: s.name);
        }
        expect(t.color, isNull, reason: 'colour comes from the tokens');
      }
    });

    test('display is 34 / 40 600 and list titles are 32 in the same box', () {
      final d = ApsiraTypography.display;
      expect((d.fontSize, d.height! * d.fontSize!), (34.0, 40.0));
      final list = ApsiraTypography.listTitle;
      expect((list.fontSize, list.height! * list.fontSize!), (32.0, 40.0));
    });

    test('line height follows the size inside a ranged row', () {
      final t = ApsiraTypeStyle.rowTitle.at(size: 17, weight: FontWeight.w700);
      expect(t.height! * 17, closeTo(23, 1e-9));
      expect(t.fontWeight, FontWeight.w700);
      final snippet = ApsiraTypeStyle.snippet.at(lineHeight: 21);
      expect(snippet.height! * 14, closeTo(21, 1e-9));
    });

    test('numerals are tabular', () {
      expect(ApsiraTypography.numeral.fontFeatures, [
        const FontFeature.tabularFigures(),
      ]);
      expect(ApsiraTypography.body.fontFeatures, isNull);
    });

    test('the wordmark tracks in em of its size', () {
      final w = ApsiraTypeStyle.wordmark.at(size: 40, trackingEm: 0.14);
      expect(w.letterSpacing, closeTo(5.6, 1e-9));
    });

    test('values outside a documented range are refused', () {
      expect(
        () => ApsiraTypeStyle.body.at(weight: FontWeight.w700),
        throwsArgumentError,
      );
      expect(() => ApsiraTypeStyle.numeral.at(size: 69), throwsArgumentError);
      expect(
        () => ApsiraTypeStyle.wordmark.at(trackingEm: 0.2),
        throwsArgumentError,
      );
      expect(
        () => ApsiraTypeStyle.snippet.at(lineHeight: 22),
        throwsArgumentError,
      );
    });
  });

  group('D-055: normal-width Archivo is variable (P0-06d)', () {
    test('Archivo styles set weight and normal width through variations', () {
      for (final s in ApsiraTypeStyle.values) {
        if (s.family != ApsiraFonts.archivo) continue;
        for (var w = s.weight.$1; w <= s.weight.$2; w += 100) {
          final t = s.at(weight: FontWeight.values[w ~/ 100 - 1]);
          // The file's default instance is wght 600: without the axis set,
          // body text would render semi-bold.
          expect(t.fontVariations, [
            FontVariation.weight(w.toDouble()),
            const FontVariation.width(ApsiraFonts.normalWidth),
          ], reason: '${s.name} $w');
          expect(t.fontWeight!.value, w, reason: '${s.name} $w');
        }
      }
    });

    test('the static Expanded cuts carry no variations', () {
      for (final s in ApsiraTypeStyle.values) {
        if (s.family != ApsiraFonts.archivoExpanded) continue;
        expect(s.style.fontVariations, isNull, reason: s.name);
      }
    });

    test('the theme roles keep the variations', () {
      final tt = ApsiraThemeData.dark.textTheme;
      expect(
        tt.bodyLarge!.fontVariations,
        ApsiraTypography.body.fontVariations,
      );
      expect(tt.titleMedium!.fontVariations, [
        const FontVariation.weight(600),
        const FontVariation.width(ApsiraFonts.normalWidth),
      ]);
    });
  });

  group('ThemeData', () {
    test('both themes default to Archivo and map the Apsira scale', () {
      for (final data in [ApsiraThemeData.light, ApsiraThemeData.dark]) {
        final tt = data.textTheme;
        expect(tt.bodyLarge!.fontFamily, ApsiraFonts.archivoQualified);
        for (final (role, style) in [
          (tt.displaySmall, ApsiraTypography.display),
          (tt.headlineSmall, ApsiraTypography.h2),
          (tt.titleLarge, ApsiraTypography.cardTitle),
          (tt.titleMedium, ApsiraTypography.rowTitle),
          (tt.bodyLarge, ApsiraTypography.body),
          (tt.bodyMedium, ApsiraTypography.snippet),
          (tt.bodySmall, ApsiraTypography.meta),
          (tt.labelLarge, ApsiraTypography.pill),
        ]) {
          expect(role!.fontFamily, style.fontFamily);
          expect(role.fontSize, style.fontSize);
          expect(role.height, style.height);
          expect(role.fontWeight, style.fontWeight);
        }
        // Material still colours text from the scheme (onSurface = ink).
        expect(tt.bodyLarge!.color, data.colorScheme.onSurface);
      }
    });
  });
  group('ApsiraFonts names', () {
    test('the qualified names are the bare names under packages/apsira_ui', () {
      expect(
        ApsiraFonts.archivoExpandedQualified,
        'packages/apsira_ui/${ApsiraFonts.archivoExpanded}',
      );
      expect(
        ApsiraFonts.archivoQualified,
        'packages/apsira_ui/${ApsiraFonts.archivo}',
      );
      expect(
        ApsiraFonts.monoQualified,
        'packages/apsira_ui/${ApsiraFonts.mono}',
      );
      expect(ApsiraFonts.package, 'apsira_ui');
    });
  });
}

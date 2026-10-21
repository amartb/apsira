// From relay test/app/theme/relay_theme_test.dart @ 5f606e9
// ApsiraTheme holds every UX §2.2 colour token in light and dark. The
// expected values are tabled here, copied from RELAY's docs/06 §2.2 at
// 5f606e9 (RELAY checked the table against that document; the package
// carries the table as the test's own constant).
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX §2.2 "Surfaces and text" and "Brand", as (light, dark) ARGB values.
const Map<String, (int, int)> expectedTokens = {
  'ground': (0xFFE3E9E5, 0xFF0A0E0C),
  'surface': (0xFFFFFFFF, 0xFF18201C),
  'border': (0xFFD2DBD6, 0xFF2C3833),
  'tint': (0xFFEDF1EE, 0xFF232D28),
  'panel': (0xFFE3E9E5, 0xFF101613),
  'ink': (0xFF101513, 0xFFF1F4F2),
  'ink2': (0xFF3F4A45, 0xFFC3CCC7),
  'ink3': (0xFF5E6964, 0xFF97A39D),
  'line': (0xFFE3E9E5, 0xFF2A3430),
  'lineOnTint': (0xFFDCE3DF, 0xFF303B36),
  // D-097: light ring #8C9690 -> #7A847E (3:1 on tint and ground).
  'ring': (0xFF7A847E, 0xFF6E7A74),
  // rgba(16,21,19,.40) and rgba(0,0,0,.65).
  'scrim': (0x66101513, 0xA6000000),
  'accentFill': (0xFF007A4C, 0xFF1FB377),
  'onAccent': (0xFFFFFFFF, 0xFF06140E),
  'accentText': (0xFF006B43, 0xFF4CD39A),
  'accC': (0xFFD2F0E1, 0xFF10352A),
  'onAccC': (0xFF00452B, 0xFF9DEBC6),
};

/// UX §2.2 "Semantic tonal pairs": (solid, container, onContainer), light
/// then dark.
const Map<ApsiraFamily, ((int, int, int), (int, int, int))> expectedFamilies = {
  ApsiraFamily.redOrange: (
    (0xFFD4380D, 0xFFFFE4DA, 0xFF8A2205),
    (0xFFFF7A4D, 0xFF3B1A10, 0xFFFFB59C),
  ),
  // D-097: light amber solid #C77700 -> #BA7000 (3:1 on ground).
  ApsiraFamily.amber: (
    (0xFFBA7000, 0xFFFFEFC7, 0xFF6B4200),
    (0xFFF5B83D, 0xFF3A2A0B, 0xFFFFD98A),
  ),
  ApsiraFamily.blue: (
    (0xFF2F6BDB, 0xFFDDE8FF, 0xFF183F8F),
    (0xFF7AA2FF, 0xFF16264A, 0xFFB9CDFF),
  ),
  ApsiraFamily.pink: (
    (0xFFC2417A, 0xFFFFE0EC, 0xFF7A1846),
    (0xFFFF7EB0, 0xFF3D1426, 0xFFFFB8D2),
  ),
  ApsiraFamily.green: (
    (0xFF007A4C, 0xFFD2F0E1, 0xFF00452B),
    (0xFF1FB377, 0xFF10352A, 0xFF9DEBC6),
  ),
  ApsiraFamily.neutral: (
    (0xFF6B7671, 0xFFECEFED, 0xFF4A5550),
    (0xFFA9B4AE, 0xFF232C28, 0xFFC3CCC7),
  ),
};

Map<String, int> argb(Map<String, Color> colors) =>
    colors.map((k, v) => MapEntry(k, v.toARGB32()));

(int, int, int) familyArgb(ApsiraFamilyColors f) =>
    (f.solid.toARGB32(), f.container.toARGB32(), f.onContainer.toARGB32());

void main() {
  group('ApsiraTheme tokens (UX §2.2)', () {
    test('light holds every documented value', () {
      expect(argb(ApsiraTheme.light.colors), {
        for (final e in expectedTokens.entries) e.key: e.value.$1,
      });
    });

    test('dark holds every documented value', () {
      expect(argb(ApsiraTheme.dark.colors), {
        for (final e in expectedTokens.entries) e.key: e.value.$2,
      });
    });

    test('every family in both themes holds its documented values', () {
      for (final f in ApsiraFamily.values) {
        expect(
          familyArgb(ApsiraTheme.light.family(f)),
          expectedFamilies[f]!.$1,
          reason: '${f.name} light',
        );
        expect(
          familyArgb(ApsiraTheme.dark.family(f)),
          expectedFamilies[f]!.$2,
          reason: '${f.name} dark',
        );
      }
    });

    test('green is the brand pair (accentFill, accC, onAccC)', () {
      for (final t in [ApsiraTheme.light, ApsiraTheme.dark]) {
        final g = t.family(ApsiraFamily.green);
        expect(g.solid, t.accentFill);
        expect(g.container, t.accC);
        expect(g.onContainer, t.onAccC);
      }
    });

    test('light has the documented card shadow; dark has none', () {
      expect(ApsiraTheme.light.shadow, const [
        BoxShadow(
          color: Color.fromRGBO(16, 21, 19, 0.06),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
        BoxShadow(
          color: Color.fromRGBO(16, 21, 19, 0.22),
          offset: Offset(0, 8),
          blurRadius: 20,
          spreadRadius: -12,
        ),
      ]);
      expect(ApsiraTheme.dark.shadow, isEmpty);
    });

    test('brightness matches each theme', () {
      expect(ApsiraTheme.light.brightness, Brightness.light);
      expect(ApsiraTheme.dark.brightness, Brightness.dark);
    });
  });

  group('ThemeExtension contract', () {
    test('copyWith replaces only the given token', () {
      const red = Color(0xFFFF0000);
      final copy = ApsiraTheme.light.copyWith(ring: red);
      expect(copy.ring, red);
      final rest = argb(copy.colors)..remove('ring');
      final original = argb(ApsiraTheme.light.colors)..remove('ring');
      expect(rest, original);
      expect(copy.brightness, Brightness.light);
      expect(copy.shadow, ApsiraTheme.light.shadow);
    });

    test('copyWith with no arguments keeps every value', () {
      final copy = ApsiraTheme.dark.copyWith();
      expect(argb(copy.colors), argb(ApsiraTheme.dark.colors));
      for (final f in ApsiraFamily.values) {
        expect(
          familyArgb(copy.family(f)),
          familyArgb(ApsiraTheme.dark.family(f)),
        );
      }
    });

    test('lerp ends at each theme and interpolates between them', () {
      const a = ApsiraTheme.light;
      const b = ApsiraTheme.dark;
      expect(argb(a.lerp(b, 0).colors), argb(a.colors));
      expect(argb(a.lerp(b, 1).colors), argb(b.colors));
      final mid = a.lerp(b, 0.5);
      expect(mid.ground, Color.lerp(a.ground, b.ground, 0.5));
      expect(
        mid.family(ApsiraFamily.blue).solid,
        Color.lerp(
          a.family(ApsiraFamily.blue).solid,
          b.family(ApsiraFamily.blue).solid,
          0.5,
        ),
      );
      expect(
        familyArgb(a.lerp(b, 1).family(ApsiraFamily.amber)),
        familyArgb(b.family(ApsiraFamily.amber)),
      );
      expect(a.lerp(b, 1).shadow, isEmpty);
      expect(a.lerp(b, 0.4).brightness, Brightness.light);
      expect(a.lerp(b, 0.6).brightness, Brightness.dark);
    });

    test('lerp with a foreign extension returns this', () {
      expect(
        identical(ApsiraTheme.light.lerp(null, 0.5), ApsiraTheme.light),
        isTrue,
      );
    });
  });

  group('Material 3 ColorScheme mapping', () {
    for (final t in [ApsiraTheme.light, ApsiraTheme.dark]) {
      test('${t.brightness.name}: explicit token mapping', () {
        final c = ApsiraThemeData.colorScheme(t);
        final other = t.brightness == Brightness.light
            ? ApsiraTheme.dark
            : ApsiraTheme.light;
        final red = t.family(ApsiraFamily.redOrange);
        final blue = t.family(ApsiraFamily.blue);
        final onSolid = t.brightness == Brightness.light ? t.surface : t.ground;
        final mapping = <String, (Color, Color)>{
          'primary': (c.primary, t.accentFill),
          'onPrimary': (c.onPrimary, t.onAccent),
          'primaryContainer': (c.primaryContainer, t.accC),
          'onPrimaryContainer': (c.onPrimaryContainer, t.onAccC),
          'secondary': (c.secondary, t.accentText),
          'onSecondary': (c.onSecondary, t.onAccent),
          'secondaryContainer': (c.secondaryContainer, t.accC),
          'onSecondaryContainer': (c.onSecondaryContainer, t.onAccC),
          'tertiary': (c.tertiary, blue.solid),
          'onTertiary': (c.onTertiary, onSolid),
          'tertiaryContainer': (c.tertiaryContainer, blue.container),
          'onTertiaryContainer': (c.onTertiaryContainer, blue.onContainer),
          'error': (c.error, red.solid),
          'onError': (c.onError, onSolid),
          'errorContainer': (c.errorContainer, red.container),
          'onErrorContainer': (c.onErrorContainer, red.onContainer),
          'surface': (c.surface, t.surface),
          'onSurface': (c.onSurface, t.ink),
          'onSurfaceVariant': (c.onSurfaceVariant, t.ink2),
          'surfaceDim': (c.surfaceDim, t.ground),
          'surfaceBright': (c.surfaceBright, t.surface),
          'surfaceContainerLowest': (c.surfaceContainerLowest, t.surface),
          'surfaceContainerLow': (c.surfaceContainerLow, t.surface),
          'surfaceContainer': (c.surfaceContainer, t.surface),
          'surfaceContainerHigh': (c.surfaceContainerHigh, t.surface),
          'surfaceContainerHighest': (c.surfaceContainerHighest, t.tint),
          'outline': (c.outline, t.ring),
          'outlineVariant': (c.outlineVariant, t.border),
          'scrim': (c.scrim, t.scrim),
          'inverseSurface': (c.inverseSurface, t.ink),
          'onInverseSurface': (c.onInverseSurface, t.surface),
          'inversePrimary': (c.inversePrimary, other.accentText),
          'surfaceTint': (c.surfaceTint, const Color(0x00000000)),
        };
        for (final e in mapping.entries) {
          expect(e.value.$1, e.value.$2, reason: e.key);
        }
        expect(c.brightness, t.brightness);
      });

      test('${t.brightness.name}: ThemeData carries the tokens', () {
        final data = ApsiraThemeData.build(t);
        expect(data.brightness, t.brightness);
        expect(data.useMaterial3, isTrue);
        expect(data.scaffoldBackgroundColor, t.ground);
        expect(data.dividerColor, t.line);
        expect(identical(data.extension<ApsiraTheme>(), t), isTrue);
      });
    }

    test('light and dark ThemeData are the two token sets', () {
      expect(
        identical(
          ApsiraThemeData.light.extension<ApsiraTheme>(),
          ApsiraTheme.light,
        ),
        isTrue,
      );
      expect(
        identical(
          ApsiraThemeData.dark.extension<ApsiraTheme>(),
          ApsiraTheme.dark,
        ),
        isTrue,
      );
    });
  });

  testWidgets('ApsiraTheme.of reads the tokens from the ambient Theme', (
    tester,
  ) async {
    late ApsiraTheme found;
    await tester.pumpWidget(
      Theme(
        data: ApsiraThemeData.dark,
        child: Builder(
          builder: (context) {
            found = ApsiraTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(identical(found, ApsiraTheme.dark), isTrue);
  });

  // D-066: every surface has its 1 px border, the Material pickers too
  // (final F-2). RELAY opened them through its value editors; the package
  // opens Flutter's own showDatePicker and showTimePicker.
  group('picker dialogs are bordered surfaces (D-066)', () {
    Future<void> open(
      WidgetTester tester,
      ThemeData theme,
      Future<void> Function(BuildContext) pick,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => pick(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    void expectBordered(WidgetTester tester, ApsiraTheme t) {
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.side.color, t.border);
      expect(shape.side.width, 1);
      expect(shape.borderRadius, BorderRadius.circular(ApsiraRadii.groupCard));
      expect(dialog.backgroundColor, t.surface);
    }

    for (final (name, theme, tokens) in [
      ('dark', ApsiraThemeData.dark, ApsiraTheme.dark),
      ('light', ApsiraThemeData.light, ApsiraTheme.light),
    ]) {
      testWidgets('the date picker in $name', (tester) async {
        await open(
          tester,
          theme,
          (c) => showDatePicker(
            context: c,
            initialDate: DateTime(2026, 10, 19),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          ),
        );
        expectBordered(tester, tokens);
      });

      testWidgets('the time picker in $name', (tester) async {
        await open(
          tester,
          theme,
          (c) => showTimePicker(
            context: c,
            initialTime: const TimeOfDay(hour: 9, minute: 30),
          ),
        );
        expectBordered(tester, tokens);
      });
    }
  });
}

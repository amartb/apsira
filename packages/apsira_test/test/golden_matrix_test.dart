// From relay test/support/golden/relay_golden_test.dart @ 09b28810 and lyceum
// test/support/golden/lyceum_golden_test.dart @ 9f4ff27: the matrix and its
// file names, and one probe rendered through it. Update the probe goldens
// with `flutter test --update-goldens test/golden_matrix_test.dart` after a
// deliberate change, and say so in the commit.
import 'package:apsira_test/apsira_test.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the golden matrix', () {
    test('is 8 variants: EN/ES x dark/light x 100/200 %', () {
      expect(goldenVariants, hasLength(8));
      expect(goldenVariants.map((v) => v.name), [
        'en.dark.100',
        'en.dark.200',
        'en.light.100',
        'en.light.200',
        'es.dark.100',
        'es.dark.200',
        'es.light.100',
        'es.light.200',
      ]);
    });

    test('names each file <screen>.<locale>.<theme>.<scale>.png', () {
      const v = GoldenVariant(Locale('es'), Brightness.light, 2);
      expect(v.goldenFile('probe'), 'goldens/probe.es.light.200.png');
    });

    test('a theme named apart from its brightness keeps its own name', () {
      // VIATICUM's matrix is dark and its room variant.
      final variants = goldenVariantsOf(
        themeName: (b) => b == Brightness.dark ? 'dark' : 'room',
      );
      expect(variants.map((v) => v.name), contains('es.room.200'));
      expect(variants, hasLength(8));
    });

    testWidgets('a variant renders in its theme, locale and Android scaling', (
      tester,
    ) async {
      const v = GoldenVariant(Locale('en'), Brightness.light, 2);
      await pumpGolden(tester, v, const Text('Probe'));
      final context = tester.element(find.text('Probe'));
      expect(Theme.of(context).brightness, Brightness.light);
      expect(MediaQuery.textScalerOf(context), AndroidFontScaler(2));
      expect(tester.view.physicalSize, goldenScreen);
    });

    testWidgets('a linear scaler is kept where the app asks for one', (
      tester,
    ) async {
      // RELAY's goldens scale text linearly.
      const v = GoldenVariant(Locale('en'), Brightness.dark, 2);
      await pumpGolden(
        tester,
        v,
        const Text('Probe'),
        scaler: TextScaler.linear,
      );
      final context = tester.element(find.text('Probe'));
      expect(MediaQuery.textScalerOf(context), const TextScaler.linear(2));
    });
  });

  goldenMatrix(
    'probe',
    _Probe.new,
    host: const LayoutHost(),
    size: const Size(240, 120),
  );
}

/// A one-widget probe: a filled card with a title and the variant's name,
/// in both of apsira_ui's text families.
class _Probe extends StatelessWidget {
  const _Probe(this.variant);

  final GoldenVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Apsira', style: text.titleLarge),
                Text(variant.name, style: text.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

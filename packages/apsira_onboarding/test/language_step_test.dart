// From relay test/features/first_open/first_open_screen_test.dart @
// 09b28810 (the language step) and viaticum
// test/features/first_open/first_open_screen_test.dart @ 78d38e0 (group
// "the language step"), with relay first_open_flow_test.dart's
// preselection (D-APK-017): "Choose your language / Elige tu idioma",
// English and Español, the selected one marked; Continue goes on in it.
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:apsira_test/apsira_test.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/host.dart';

final _calls = <String>[];

Widget _step(AppLanguage selected, {List<AppLanguage>? options}) => Scaffold(
  body: options == null
      ? LanguageStep(
          selected: selected,
          onSelected: (l) => _calls.add(l.name),
          onContinue: () => _calls.add('continue'),
        )
      : LanguageStep(
          selected: selected,
          options: options,
          onSelected: (l) => _calls.add(l.name),
          onContinue: () => _calls.add('continue'),
        ),
);

void main() {
  setUp(_calls.clear);

  testWidgets('the title and English and Español; Follow phone is a '
      'Settings choice', (tester) async {
    await pumpHome(tester, _step(AppLanguage.english));
    expect(find.text('Choose your language / Elige tu idioma'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text(en.languageFollowPhone), findsNothing);
    expect(byKey('firstOpen/language/english'), findsOneWidget);
    expect(byKey('firstOpen/language/spanish'), findsOneWidget);
  });

  testWidgets('the selected one is marked, read as one of a group', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester, _step(AppLanguage.spanish));
    for (final language in [AppLanguage.english, AppLanguage.spanish]) {
      expect(
        tester.getSemantics(byKey('firstOpen/language/${language.name}')),
        isSemantics(
          isSelected: language == AppLanguage.spanish,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
        reason: language.name,
      );
    }
    final option = tester.widget<Material>(
      find
          .descendant(
            of: byKey('firstOpen/language/spanish'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(option.color, ApsiraTheme.dark.accC);
    semantics.dispose();
  });

  testWidgets('a tap selects; Continue goes on', (tester) async {
    await pumpHome(tester, _step(AppLanguage.english));
    await tester.tap(byKey('firstOpen/language/spanish'));
    await tester.tap(byKey('firstOpen/language/continue'));
    expect(_calls, ['spanish', 'continue']);
  });

  testWidgets('Continue is Continuar in Spanish', (tester) async {
    await pumpHome(
      tester,
      _step(AppLanguage.spanish),
      locale: const Locale('es'),
    );
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Choose your language / Elige tu idioma'), findsOneWidget);
  });

  testWidgets('an app may offer other options, Follow phone among them', (
    tester,
  ) async {
    await pumpHome(
      tester,
      _step(AppLanguage.followPhone, options: AppLanguage.values),
    );
    expect(find.text(en.languageFollowPhone), findsOneWidget);
    await tester.tap(byKey('firstOpen/language/followPhone'));
    expect(_calls, ['followPhone']);
  });

  group('preselect', () {
    for (final (phone, preselected) in [
      (const Locale('en'), AppLanguage.english),
      (const Locale('es', 'ES'), AppLanguage.spanish),
      (const Locale('es', 'MX'), AppLanguage.spanish),
      (const Locale('fr'), AppLanguage.english),
    ]) {
      test('a $phone phone preselects ${preselected.name}', () {
        expect(
          LanguageStep.preselect(stored: AppLanguage.followPhone, phone: phone),
          preselected,
        );
      });
    }

    test("a stored language is preselected over the phone's", () {
      expect(
        LanguageStep.preselect(
          stored: AppLanguage.english,
          phone: const Locale('es'),
        ),
        AppLanguage.english,
      );
      expect(
        LanguageStep.preselect(
          stored: AppLanguage.spanish,
          phone: const Locale('en'),
        ),
        AppLanguage.spanish,
      );
    });
  });

  testWidgets('is sound at large text, in English and Spanish', (tester) async {
    await expectLayoutSound(
      tester,
      () => _step(AppLanguage.spanish),
      host: host,
    );
  });
}

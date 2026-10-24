import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [LanguageStore] that records each write, or throws when [fail] is set.
class _Store implements LanguageStore {
  final List<AppLanguage> writes = [];
  bool fail = false;

  @override
  Future<void> write(AppLanguage value) async {
    if (fail) throw StateError('disk full');
    writes.add(value);
  }
}

void main() {
  group('AppLanguage', () {
    test('locales in display order', () {
      expect(AppLanguage.values, [
        AppLanguage.english,
        AppLanguage.spanish,
        AppLanguage.followPhone,
      ]);
      expect(AppLanguage.english.locale, const Locale('en'));
      expect(AppLanguage.spanish.locale, const Locale('es'));
      expect(AppLanguage.followPhone.locale, isNull);
    });

    test('storageValue round-trips through fromStorage', () {
      expect(AppLanguage.english.storageValue, 'en');
      expect(AppLanguage.spanish.storageValue, 'es');
      expect(AppLanguage.followPhone.storageValue, isNull);
      for (final language in AppLanguage.values) {
        expect(AppLanguage.fromStorage(language.storageValue), language);
      }
    });

    test('anything unknown follows the phone', () {
      expect(AppLanguage.fromStorage('fr'), AppLanguage.followPhone);
      expect(AppLanguage.fromStorage(''), AppLanguage.followPhone);
      expect(AppLanguage.fromStorage(42), AppLanguage.followPhone);
    });

    test('label per language', () {
      final en = ApsiraL10nEn();
      final es = ApsiraL10nEs();
      expect(AppLanguage.english.label(en), 'English');
      expect(AppLanguage.spanish.label(en), 'Español');
      expect(AppLanguage.followPhone.label(en), 'Follow phone');
      expect(AppLanguage.english.label(es), 'English');
      expect(AppLanguage.spanish.label(es), 'Español');
      expect(AppLanguage.followPhone.label(es), 'Seguir el teléfono');
    });
  });

  group('AppLanguageSetting', () {
    late _Store store;
    late ProviderContainer container;

    ProviderContainer make(AppLanguage initial) => ProviderContainer(
      overrides: [
        languageStoreProvider.overrideWithValue(store),
        initialAppLanguageProvider.overrideWithValue(initial),
      ],
    );

    setUp(() => store = _Store());
    tearDown(() => container.dispose());

    test('follows the phone without an override', () {
      container = ProviderContainer(
        overrides: [languageStoreProvider.overrideWithValue(store)],
      );
      expect(container.read(appLanguageProvider), AppLanguage.followPhone);
    });

    test('starts from the initial override', () {
      container = make(AppLanguage.spanish);
      expect(container.read(appLanguageProvider), AppLanguage.spanish);
    });

    test('setLanguage sets the state and writes the store', () async {
      container = make(AppLanguage.followPhone);
      await container
          .read(appLanguageProvider.notifier)
          .setLanguage(AppLanguage.english);
      expect(container.read(appLanguageProvider), AppLanguage.english);
      expect(store.writes, [AppLanguage.english]);
    });

    test('a failed write restores the previous choice and rethrows', () async {
      container = make(AppLanguage.spanish);
      store.fail = true;
      final seen = <AppLanguage>[];
      container.listen(appLanguageProvider, (_, next) => seen.add(next));
      await expectLater(
        container
            .read(appLanguageProvider.notifier)
            .setLanguage(AppLanguage.english),
        throwsA(isA<StateError>()),
      );
      expect(container.read(appLanguageProvider), AppLanguage.spanish);
      expect(seen, [AppLanguage.english, AppLanguage.spanish]);
      expect(store.writes, isEmpty);
    });

    test('the store must be provided by the app', () {
      container = ProviderContainer();
      expect(
        () => container.read(languageStoreProvider),
        throwsA(
          predicate((e) => e.toString().contains('languageStoreProvider')),
        ),
      );
    });
  });
}

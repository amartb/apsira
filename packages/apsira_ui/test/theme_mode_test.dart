// The theme-mode setting (D-APK-013): RELAY's options and storage names
// (relay lib/app/theme/theme_mode_provider.dart @ 09b28810) behind a
// hand-written Notifier that writes through the app's ThemeModeStore and,
// as AppLanguageSetting does, restores the previous mode when a write fails.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every write; throws [error] instead when given.
class _Store implements ThemeModeStore {
  _Store([this.error]);

  final Object? error;
  final writes = <ThemeMode>[];

  @override
  Future<void> write(ThemeMode mode) async {
    if (error case final error?) throw error;
    writes.add(mode);
  }
}

ProviderContainer _container(_Store store, {ThemeMode? initial}) {
  final c = ProviderContainer(
    overrides: [
      themeModeStoreProvider.overrideWithValue(store),
      if (initial != null) initialThemeModeProvider.overrideWithValue(initial),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('options and storage names (RELAY)', () {
    test('Dark, Light, Follow system, in that order', () {
      expect(themeModeOptions, [
        ThemeMode.dark,
        ThemeMode.light,
        ThemeMode.system,
      ]);
    });

    test('each mode is stored as its name', () {
      expect(themeModeStorageName(ThemeMode.dark), 'dark');
      expect(themeModeStorageName(ThemeMode.light), 'light');
      expect(themeModeStorageName(ThemeMode.system), 'system');
    });

    test('a stored name reads back; absent or unknown reads as dark', () {
      expect(themeModeFromStorage('light'), ThemeMode.light);
      expect(themeModeFromStorage('system'), ThemeMode.system);
      expect(themeModeFromStorage('dark'), ThemeMode.dark);
      expect(themeModeFromStorage(null), ThemeMode.dark);
      expect(themeModeFromStorage('x'), ThemeMode.dark);
      expect(themeModeFromStorage(1), ThemeMode.dark);
      for (final mode in themeModeOptions) {
        expect(themeModeFromStorage(themeModeStorageName(mode)), mode);
      }
    });
  });

  group('ThemeModeSetting', () {
    test('opens dark by default (D-064)', () {
      final c = _container(_Store());
      expect(c.read(themeModeProvider), ThemeMode.dark);
    });

    test('opens at the app\'s stored mode (the initial override)', () {
      final c = _container(_Store(), initial: ThemeMode.light);
      expect(c.read(themeModeProvider), ThemeMode.light);
    });

    test('setMode changes the mode and writes it', () async {
      final store = _Store();
      final c = _container(store);
      await c.read(themeModeProvider.notifier).setMode(ThemeMode.system);
      expect(c.read(themeModeProvider), ThemeMode.system);
      expect(store.writes, [ThemeMode.system]);
    });

    test('a failed write restores the previous mode and rethrows', () async {
      final error = StateError('disk full');
      final c = _container(_Store(error), initial: ThemeMode.light);
      await expectLater(
        c.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
        throwsA(same(error)),
      );
      expect(c.read(themeModeProvider), ThemeMode.light);
    });

    test('without a store override it fails loudly, naming the provider', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        () => c.read(themeModeStoreProvider),
        throwsA(
          predicate((e) => e.toString().contains('themeModeStoreProvider')),
        ),
      );
    });
  });
}

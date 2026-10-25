// From relay lib/app/theme/theme_mode_provider.dart @ 09b28810: the options
// and the storage names. The Notifier is hand-written (no codegen, D-APK-001;
// Riverpod, ruling R-1) and writes through the app's ThemeModeStore, with
// AppLanguageSetting's failure rule (D-APK-013).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The modes Settings → Appearance offers, in display order: Dark (the
/// default), Light and Follow system (D-064).
const themeModeOptions = [ThemeMode.dark, ThemeMode.light, ThemeMode.system];

/// [mode]'s stored name: `"dark"`, `"light"` or `"system"`.
String themeModeStorageName(ThemeMode mode) => mode.name;

/// The mode stored as [value]; dark (the default, D-064) for an absent value
/// or anything that is not one of [themeModeOptions]' names.
ThemeMode themeModeFromStorage(Object? value) {
  for (final mode in themeModeOptions) {
    if (mode.name == value) return mode;
  }
  return ThemeMode.dark;
}

/// Where an app keeps the theme mode, under its own key (RELAY
/// `theme_mode`); the package never chooses a key.
abstract interface class ThemeModeStore {
  /// Stores [mode], as [themeModeStorageName] names it or in the app's own
  /// format.
  Future<void> write(ThemeMode mode);
}

/// The app's [ThemeModeStore]; every app overrides it in its `ProviderScope`.
final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => throw UnimplementedError('override themeModeStoreProvider'),
);

/// The mode the app opens in: the stored one, read before `runApp` and
/// given as an override. Dark until the user chooses (D-064).
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.dark);

/// The theme-mode setting the root `MaterialApp` reads.
class ThemeModeSetting extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  /// Chooses one of [themeModeOptions] and stores it. When the write fails
  /// the previous mode comes back and the error is rethrown, so the screen
  /// never shows a choice that was not kept.
  Future<void> setMode(ThemeMode mode) async {
    final previous = state;
    state = mode;
    try {
      await ref.read(themeModeStoreProvider).write(mode);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

/// The current [ThemeMode].
final themeModeProvider = NotifierProvider<ThemeModeSetting, ThemeMode>(
  ThemeModeSetting.new,
);

// From relay lib/app/l10n/app_locale_provider.dart @ 09b28810 (the enum,
// storageValue and fromStorage) and viaticum lib/app/l10n/app_language.dart
// @ 78d38e0 (the Notifier). Changes (D-APK-012): label reads ApsiraL10n;
// RELAY's settingKey stays in RELAY, as each app keeps its own key in its
// LanguageStore; the setting writes through that store and restores the
// previous choice when the write fails.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'apsira_l10n.dart';

/// The UI languages an Apsira app offers, in display order: English,
/// Español and Follow phone.
enum AppLanguage {
  english(Locale('en')),
  spanish(Locale('es')),
  followPhone(null);

  const AppLanguage(this.locale);

  /// The locale to force on `MaterialApp.locale`; `null` follows the
  /// phone's language, falling back to English when the phone's language
  /// is neither English nor Spanish.
  final Locale? locale;

  /// The stored value: the language code, or null to follow the phone.
  String? get storageValue => locale?.languageCode;

  /// The option stored as [value]; Follow phone for null or anything that
  /// is not a language offered here.
  static AppLanguage fromStorage(Object? value) {
    for (final language in values) {
      if (language.locale != null && language.storageValue == value) {
        return language;
      }
    }
    return followPhone;
  }

  /// This option's name, as shown in the language pickers.
  String label(ApsiraL10n l10n) => switch (this) {
    english => l10n.languageEnglish,
    spanish => l10n.languageSpanish,
    followPhone => l10n.languageFollowPhone,
  };
}

/// Where an app stores the language choice, under its own key (RELAY
/// `settings.locale_override`, VIATICUM `ui.language`, LYCEUM `locale`).
abstract interface class LanguageStore {
  /// Stores [value]; throws when the write fails.
  Future<void> write(AppLanguage value);
}

/// The app's [LanguageStore]; every app overrides it.
final languageStoreProvider = Provider<LanguageStore>(
  (ref) => throw UnimplementedError('override languageStoreProvider'),
);

/// The stored choice the app read at start; Follow phone until it is
/// overridden.
final initialAppLanguageProvider = Provider<AppLanguage>(
  (ref) => AppLanguage.followPhone,
);

/// The language setting. The app follows the phone's language until the
/// user chooses one. Changing it re-renders the app in place: the root
/// `MaterialApp` watches [appLanguageProvider], so no restart is needed.
class AppLanguageSetting extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => ref.watch(initialAppLanguageProvider);

  /// Chooses [language] and stores it. When the write fails, the previous
  /// choice is restored and the error rethrown.
  Future<void> setLanguage(AppLanguage language) async {
    final previous = state;
    state = language;
    try {
      await ref.read(languageStoreProvider).write(language);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

/// The language in force; see [AppLanguageSetting].
final appLanguageProvider = NotifierProvider<AppLanguageSetting, AppLanguage>(
  AppLanguageSetting.new,
);

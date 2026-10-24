# apsira_l10n

The strings the shared Apsira widgets show, in English and Spanish, and the app language
setting (D-APK-012). The kit, onboarding and lock read their text here; an app's own text
stays in its own ARBs.

## Consuming

Pin by the shared tag, the same ref for every apsira package (D-APK-007, `../README.md`):

```yaml
dependencies:
  apsira_l10n: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.3.0, path: packages/apsira_l10n } }
```

`package:apsira_l10n/apsira_l10n.dart` is the public surface. It depends on `flutter` and
`flutter_riverpod` ^3.1.0 only: no `intl`, no `flutter_localizations`, no generated code
(D-APK-001).

```dart
MaterialApp(
  locale: ref.watch(appLanguageProvider).locale,
  localizationsDelegates: [...AppLocalizations.localizationsDelegates, ApsiraL10n.delegate],
  supportedLocales: AppLocalizations.supportedLocales,
);
Text(ApsiraL10n.of(context).commonCancel);
```

- `ApsiraL10n.of(context)` throws a `FlutterError` naming `ApsiraL10n.delegate` when the app
  did not add it; a shared widget never falls back to English silently.
- `en` and `es` are written here (`ApsiraL10nEn`, `ApsiraL10nEs`); the delegate loads English
  for any other language. The app's own `supportedLocales` decide the locales it offers.
- Three keys take arguments: `tourProgress(current, total)`, `lockPromptTitle(app)` and
  `lockAfterMinutes(n)` (singular for 1, written in Dart).
- The key table, each wording and its source app are D-APK-012's. A new shared string is a
  key added in both languages with its source, in a new decision.

## The language setting

`AppLanguage` is `english`, `spanish` and `followPhone` (locale `null`: the phone's language,
English when it is neither). `storageValue` is `'en'`, `'es'` or `null`, and
`AppLanguage.fromStorage` reads it back; anything else is `followPhone`. `label(l10n)` is the
name the pickers show.

Each app keeps its own storage key behind a `LanguageStore` (RELAY
`settings.locale_override`, VIATICUM `ui.language`, LYCEUM `locale`):

```dart
ProviderScope(
  overrides: [
    languageStoreProvider.overrideWithValue(MyLanguageStore(settings)),
    initialAppLanguageProvider.overrideWithValue(AppLanguage.fromStorage(stored)),
  ],
  child: const MyApp(),
);
await ref.read(appLanguageProvider.notifier).setLanguage(AppLanguage.spanish);
```

`setLanguage` sets the choice at once, so the app re-renders in place, then awaits the
store. When the write fails it restores the previous choice and rethrows; the caller shows
the failure. Reading `languageStoreProvider` without an override throws.

## Tests

`flutter test`: the key table row by row in both languages (`test/keys_test.dart`), the
delegate (`es`, `en`, `fr` to English, the missing-delegate error) and the setting.

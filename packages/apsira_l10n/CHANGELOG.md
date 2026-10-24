# apsira_l10n changelog

One section per release, naming any migration a consumer must make. Every package shares
one tag, `apsira-vX.Y.Z` (D-APK-007).

## 0.4.0 — 2026-10-24

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.4.0`.

## 0.3.0 — 2026-10-24

First release (D-APK-012): `ApsiraL10n` with its delegate and 54 keys in English and
Spanish (hand-written `ApsiraL10nEn` and `ApsiraL10nEs`, no gen-l10n), RELAY `09b28810`'s
`AppLanguage` and VIATICUM `78d38e0`'s `AppLanguageSetting` with a `LanguageStore` port.
Dependencies `flutter` and `flutter_riverpod` ^3.1.0.

**Migration for every app.** Add `ApsiraL10n.delegate` to `localizationsDelegates`.
Override `languageStoreProvider` with a store over the app's own key (RELAY
`settings.locale_override`, VIATICUM `ui.language`, LYCEUM `locale`) and
`initialAppLanguageProvider` with the stored value read at start. Delete the app's
`AppLanguage` and its setting, and change `label(AppLocalizations)` calls to
`label(ApsiraL10n.of(context))`. Each ARB key the app drops onto an `ApsiraL10n` key, and
any Spanish wording that changes with it, is a line in the app's decision log (D-APK-012's
app-phrase rule).

- **RELAY:** `appLocaleProvider` becomes `appLanguageProvider`; `setLanguage` now writes
  through the store (the settings service's sync becomes the store), so the router's
  first-open write goes.
- **VIATICUM:** `setLanguage` is now a `Future` that writes through the store.
- **LYCEUM:** its two-value `AppLanguage` (`en`, `es`; null for the phone) becomes the
  three-value enum: `fromCode(code)` is `fromStorage(code)`, a stored null is
  `followPhone`, and `code` is `storageValue`.

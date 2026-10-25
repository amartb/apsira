# Changelog

## 0.4.0 — 2026-10-24

Migration: move every apsira `ref:` to `apsira-v0.4.0`. Additive only; no default moves.

- **`LockController.lockNow()`** (D-APK-016, F3): locks at once with the prompt due while the
  lock is on and the app is shown; an unavailable device leaves the app open (never a
  lock-out). LYCEUM's "Lock now" calls it.
- **`LockCover.icon`** and **`LockShield.coverIcon`**: the app's lock glyph at the cover's size
  in `accentText`; `null` keeps Material's `lock_outline`.

## 0.3.0 — 2026-10-24

First release (D-APK-016): RELAY's app lock @ `09b28810` as one Flutter plugin
(`pluginClass: ApsiraLockPlugin`), unchanged in behaviour: off by default, 5 minutes, 0 =
at once, a backwards clock locks, never a lock-out, the 2 s settings bound. Dependencies
`apsira_core`, `apsira_l10n`, `apsira_ui`, `flutter_riverpod ^3.1.0`, `local_auth ^3.0.2`,
`local_auth_android ^2.3.0` (ruling R-1); FLAG_SECURE is the package's own Kotlin on
`apsira_lock/screen_privacy`. The README maps each symbol to the app files it replaces.

Migration for every app: `MainActivity` is a `FlutterFragmentActivity`, the manifest
declares `USE_BIOMETRIC`, `ApsiraL10n.delegate` is installed; bind
`authenticatorProvider`, `screenPrivacyProvider`, `lockClockProvider`, `lockLogProvider`
and `lockSettingsStoreProvider`; put `LockShield` in `MaterialApp.builder`.

- RELAY: its store reads and merges the `lock` row (unchanged); delete the lock files the
  README lists and `flutter_windowmanager_plus`; its KAIROS exemption passes `isExempt`,
  `exemptChanges` and `promptHeld`, and calls `recents.leaveExempt()` where it called
  `enterRelay()`; a restore invalidates `lockSettingsProvider`.
- LYCEUM: its store keeps `app_lock_enabled` and `auto_lock_minutes` and adds
  `app_lock_hide_in_recents` (off); its authenticator, prompt and lock screen are replaced.
- VIATICUM: gains `local_auth` and the lock, off by default; supersedes its D-036.

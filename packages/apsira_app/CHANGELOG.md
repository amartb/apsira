# Changelog

## 0.3.0 — 2026-10-24

Its `apsira_core` and `apsira_ui` dependencies move to `ref: apsira-v0.3.0`. Migration:
move every apsira `ref:` to `apsira-v0.3.0`.

- `AboutPage` draws its rows as list tiles in cards unless the app passes `rowBuilder` (the
  version and licences rows, as `AboutRow`) and `sectionBuilder` (the brand and rows
  sections): LYCEUM keeps its kit's rows and cards. Without them it looks as in 0.2.0.

## 0.2.0 — 2026-10-24

First release (D-APK-011): the app shell RELAY, VIATICUM and LYCEUM each carried, as one
Flutter plugin (`pluginClass: ApsiraAppPlugin`). Dependencies `flutter`, `apsira_core` and
`apsira_ui`; no third-party package. The README maps each symbol to its source and to the
app files it replaces.

- `ErrorHandlers`, `FileLogSink` (file name and directory the app's; `stackHash=` lines),
  `SystemClock`, `ZoneChannel`, `PendingPort`: RELAY @ `09b28810`, with VIATICUM's stack
  hash and `Result` stubs @ `78d38e0`.
- `startRedirect` with `StartPhase` and `StartRoutes`: RELAY's and LYCEUM's redirects in
  one pure function, with the app's routes as its targets.
- `RestartableRoot`, `StartupFailureApp`, `AboutPage`, `ZoneModule.kt`: LYCEUM @ `9f4ff27`,
  every string a parameter.
- `InstallFlag`: VIATICUM's `FirstOpenService` file logic, the path verbatim.
- `testing.dart`: `MemoryLogSink`.
- `clock.dart`: `SystemClock` alone, with no Flutter library, for plain Dart processes
  (RELAY's kill-during-typing child); the barrel exports it too.

Migration for every app:

- Delete the files the README lists. `FileLogSink.open(clock, directory:
  getApplicationSupportDirectory, name: '<app>')`.
- The zone channel is `apsira_app/zone`, registered by the plugin: delete
  `ZoneModule.register(…)` from `MainActivity.configureFlutterEngine`.

Migration for RELAY: `StartPhase.home` → `StartPhase.ready`; `_redirect` →
`startRedirect(phase, path, routes: StartRoutes(home: …, firstOpen: …, safeMode: …))`
(no `pending` route: nothing moves while the gate waits). The zone-change receiver
(`ZoneChangeReceiver`, `enqueueResync` and the manifest `<receiver>`) is deleted with the
rest of `ZoneModule.kt`: `apsira_jobs` holds it (D-APK-011; its CHANGELOG has the steps).

Migration for VIATICUM: `FirstOpenService` keeps its API over
`InstallFlag(directory: …, path: 'first_open/done.json')`, so installs keep their flag.
`SystemClock.nowUtc()` is now truncated to milliseconds. The zone-change receiver goes to
`apsira_jobs`, as for RELAY.

Migration for LYCEUM: `StartPhase.onboarding` → `firstOpen`, `open` → `ready`, with
`StartRoutes(home: …, pending: start, firstOpen: onboarding, locked: unlock)`.
`readZoneId()` → `ZoneChannel().zoneId()` with its errors caught to `null`.
`StartupFailureApp(title: …, message: …, theme: LyceumTheme.dark, localizationsDelegates:
AppLocalizations.localizationsDelegates, supportedLocales: …)`. `AboutPage` takes the mark,
the tagline and the tour and privacy rows.

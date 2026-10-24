# apsira_app

The app shell every Apsira app shares: what RELAY, VIATICUM and LYCEUM each carried in
`lib/app/` and `lib/data/platform/`, as one Flutter plugin (D-APK-011). Its dependencies
are `flutter`, `apsira_core` and `apsira_ui`, in the git form at the shared tag with the
committed `pubspec_overrides.yaml` (D-APK-007); no third-party package. The app passes its
storage directory in (`getApplicationSupportDirectory`), so the package does not need
`path_provider`. Every visible string is a parameter, until `apsira_l10n` (D-APK-008).

```yaml
dependencies:
  apsira_app: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.2.0, path: packages/apsira_app } }
```

## What it holds, and what each app deletes

Sources: RELAY `09b28810`, VIATICUM `78d38e0`, LYCEUM `9f4ff27`. Each `lib/src` file
names its source in its header. "Replaces" lists the app files (or the parts of them) the
adoption lane deletes; paths are under the app's root.

| Symbol | Source | Replaces in RELAY | in VIATICUM | in LYCEUM |
|---|---|---|---|---|
| `ErrorHandlers.install(Log, {releaseMode, presentError})`, `uninstall()` | R `lib/app/error_handlers.dart` | `lib/app/error_handlers.dart` | `lib/app/error_handlers.dart` | `lib/app/error_handlers.dart` |
| `FileLogSink.open(Clock, {directory, name, maxBytes, maxFiles})`, `files()` | R `lib/data/platform/file_log_sink.dart`; V's `stackHash=` line | `lib/data/platform/file_log_sink.dart` (`name: 'relay'`) | the same (`'viaticum'`) | the same (`'lyceum'`) |
| `StartPhase { pending, firstOpen, locked, safeMode, ready }`, `StartRoutes`, `startRedirect(phase, location, {routes})` | R `lib/app/router.dart` `_redirect`; L `lib/app/router.dart` `startRedirect` | `_redirect` in `lib/app/router.dart`; the `StartPhase` enum in `lib/features/shell/state/start_gate.dart` (`home` → `ready`) | nothing: `firstOpenRedirect` keeps its `?replay=1` rule | `StartPhase` and `startRedirect` in `lib/app/router.dart` (`onboarding` → `firstOpen`, `open` → `ready`) |
| `RestartableRoot`, `RestartController.restart({open, whileStopped})` | L `lib/app/restartable_root.dart` | — | — | `lib/app/restartable_root.dart` |
| `StartupFailureApp({title, message, theme, localizationsDelegates, supportedLocales, icon})` | L `lib/app/bootstrap.dart` | — | — | `StartupFailureApp` in `lib/app/bootstrap.dart` |
| `SystemClock` (`refreshZone`, `useZone`, `forgetZone`) | R `lib/data/platform/system_clock.dart` | `lib/data/platform/system_clock.dart` | `lib/data/platform/system_clock.dart` | `lib/data/platform/system_clock.dart` |
| `ZoneChannel` on `apsira_app/zone`, `zoneId()` | R `lib/data/platform/zone_channel.dart` | `lib/data/platform/zone_channel.dart` | `lib/data/platform/zone_channel.dart` | `readZoneId` in `lib/data/platform/zone_channel.dart` |
| `ZoneModule.kt`, `ApsiraAppPlugin.kt` (Android) | L `ZoneModule.kt` (the channel half of R's) | `ZoneModule.kt` and its `register` line in `MainActivity.kt`; its receiver half is `apsira_jobs`' `ZoneResync.kt` (D-APK-011) | the same | `ZoneModule.kt` and its line in `MainActivity.kt` |
| `PendingPort` (`pending()`, `pendingResult()`, `portPending`) | R `lib/data/platform/pending_ports.dart`; V's `Result` stubs | the base class in `lib/data/platform/pending_ports.dart` (its stubs stay) | the same | the same |
| `InstallFlag({directory, path})`, `isSet()`, `set()` | V `lib/app/services/first_open_service.dart` | — (its flag is in `app_meta`) | the file logic of `FirstOpenService` (`path: 'first_open/done.json'`) | — |
| `AboutPage({title, versionLabel, licencesLabel, appName, version, developedByLabel, apsiraLabsLabel, tagline, mark, rows, rowBuilder, sectionBuilder})`, `AboutRow`, `AboutRowKind`, `AboutSection` | L `lib/features/settings/ui/about_page.dart` | — | — | `lib/features/settings/ui/about_page.dart` (its tour and privacy rows passed as `rows`; its `EntityRow`, `GroupCard` and `LyceumCard` through the builders) |
| `MemoryLogSink` (`testing.dart`) | R `test/app/error_handlers_test.dart` | the tests' memory sinks | the same | the same |

## Behaviour notes

- **`AboutPage` draws its own rows and cards in Material by default** (list tiles, two
  `Card`s). `rowBuilder` draws the version and licences rows from an `AboutRow` (its
  `kind`, `title`, `value`, `onTap`) and `sectionBuilder` the brand and rows sections
  around their children, so an app keeps its kit's look: LYCEUM's icon-box rows in its
  group card.
- **The zone channel is on the UI engine only**, as RELAY's `MainActivity` registers it.
  `ApsiraAppPlugin` is `ActivityAware`: it sets the handler in `onAttachedToActivity` and
  clears it in `onDetachedFromActivity`. A background engine attaches to no activity, so it
  never gets the channel; it takes the zone from its job's input (`SystemClock.useZone`).
  A configuration change keeps the handler.
- `ZoneChannel.zoneId()` throws: `StateError` for no ID, `MissingPluginException` without
  the module (RELAY's). LYCEUM's `readZoneId` returned `null` instead; its adoption catches.
- `SystemClock.nowUtc()` is truncated to whole milliseconds (RELAY's, the `Clock` contract);
  VIATICUM's was not.
- A stub's `pending()` message is `portPending: <port>: the platform implementation lands
  with <task>`, which RELAY's and LYCEUM's tests (`contains` the port and the task) and
  VIATICUM's (`startsWith('portPending')`) all accept (D-APK-011).
- `InstallFlag.set()` writes `{"done":true}` to `<path>.tmp`, flushes and renames; a flag
  already there is kept byte for byte; a leftover `.tmp` alone reads as unset.
- `StartupFailureApp` reads its strings through the app's delegates, so it follows the
  phone's language: `title: (context) => AppLocalizations.of(context).appName`.

## Checks

From this directory: `flutter analyze` and `flutter test` (the `app` gate). The tests
check the Kotlin's source; `example/` compiles it. That app depends on this package by path
(its `pubspec_overrides.yaml` resolves `apsira_core` and `apsira_ui` from their
directories) and reads the zone into `SystemClock` at start; its debug build compiles
`ApsiraAppPlugin.kt` and `ZoneModule.kt`. `tool/check.sh` runs the example's
analyze and smoke test; the build is run by hand, under a build lease, from `example/`:
`flutter build apk --debug && rm -rf build`.

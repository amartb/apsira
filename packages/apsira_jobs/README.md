# apsira_jobs

Periodic background jobs for the Apsira apps that run them: the `BackgroundJobs` port and
its `JobConstraints`, the WorkManager adapter with one scheduling policy, its test fake, and
the Android receiver that queues the reminder resync on a zone change. Extracted from
VIATICUM `78d38e0` and RELAY `09b28810` (D-APK-011); every file names its source.

**Consumers: RELAY and VIATICUM only.** LYCEUM does not depend on this package: its
reminders run on exact notification alarms without WorkManager (LYCEUM D-034), which is why
the adapter is not in `apsira_app` (D-APK-011, ruling N1-a).

## Consuming

Pin by the shared tag, the same ref for every apsira package (D-APK-007, `../README.md`):

```yaml
dependencies:
  apsira_jobs: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.4.0, path: packages/apsira_jobs } }
```

`package:apsira_jobs/apsira_jobs.dart` is the public surface; `package:apsira_jobs/testing.dart`
holds `FakeBackgroundJobs`. It depends on `flutter` and `workmanager: ^0.10.10` (the pin
both apps already have), and on no apsira package.

## The policy

```dart
final jobs = WorkManagerBackgroundJobs(callbackDispatcher); // the app's entry point
await jobs.schedulePeriodic('backup', every: const Duration(days: 1),
    constraints: const JobConstraints(batteryNotLow: true, storageNotLow: true));
// the user moved the time of day: start afresh, first run at the new time
await jobs.schedulePeriodic('backup', every: const Duration(days: 1),
    firstRunIn: untilNewTime, replace: true);
```

- Scheduling a job that is already scheduled keeps it as it is, its next run included
  (WorkManager's `keep`), so scheduling at every start never moves a run.
- `replace: true` cancels it and enqueues it afresh, with its first run `firstRunIn` from
  now (`replace` + `initialDelay`): the way a changed time of day takes effect.
- WorkManager's `update` is never used: it applies a new first-run delay from the old
  enqueue time, which pulled RELAY's next run earlier at every start.
- No network constraint, never charging; `batteryNotLow`, `storageNotLow` and
  `deviceIdle` map to WorkManager's constraints and all default to false (RELAY's
  defaults). A job that did not run is retried with exponential backoff from 30 minutes.
- The dispatcher is handed to the plugin once, before the first schedule or cancel; a
  failed `initialize` is retried by the next call.

`FakeBackgroundJobs` follows the same keep/replace rule. It answers `scheduled()`,
`constraintsOf`, `firstRunInOf` and `replaced`, and `runNow(name)` runs a registered handler.
A handler returns `true` when the job ran and `false` when WorkManager would retry it.

## The zone resync receiver

`ZoneChangeReceiver` and `enqueueResync` live here, in
`android/src/main/kotlin/com/apsiralabs/apsira_jobs/ZoneResync.kt`. They are RELAY's and
VIATICUM's identical code with the package renamed (D-APK-011).
The package manifest declares the receiver, unexported, for `TIMEZONE_CHANGED`,
`TIME_SET`, `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`. On each broadcast it enqueues the
one-time job `reminderResync` (`reminderResyncJob`) through workmanager's own
`BackgroundWorker`, with the device's zone in the job's input under `zoneId`
(`zoneIdInputKey`). The app's background dispatcher maps that job to its resync. The app
deletes its own copy and its manifest `<receiver>`; the `<app>/zone` method channel is
`apsira_app`'s.

The Android build adds no artifact to either APK. It names the `workmanager_android`
project and `androidx.work:work-runtime:2.11.2`, the version `workmanager_android` 0.10.9
pins. Both are already in each app's closure. `ApsiraJobsPlugin` registers nothing: the
Flutter tool builds a plugin's Android half only when the pubspec names a plugin class. A
Dart test pins the job name, the input key and the manifest.

## Checks

From this directory: `flutter analyze` and `flutter test`. The Kotlin compiles only inside
an app's build, so `example/` is that app: it depends on this package by path and schedules
one job through `WorkManagerBackgroundJobs` at start, and its debug build compiles
`ApsiraJobsPlugin.kt` and `ZoneResync.kt` against `workmanager_android`'s `androidx.work`.
`tool/check.sh` runs the example's analyze and smoke test; the build is run by
hand, under a build lease, from `example/`:

```sh
flutter build apk --debug && rm -rf build
```

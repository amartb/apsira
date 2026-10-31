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
  apsira_jobs: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.6.0, path: packages/apsira_jobs } }
```

`package:apsira_jobs/apsira_jobs.dart` is the public surface; `package:apsira_jobs/testing.dart`
holds `FakeBackgroundJobs` and `alarmManagerBackupExclusions`. It depends on `flutter`,
`workmanager: ^0.10.10` and `android_alarm_manager_plus: ^5.1.2` (the pins both apps
already have), and on `apsira_notify` at the shared tag (D-APK-022), whose closure
`pubspec_overrides.yaml` resolves here.

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
pins. Both are already in each app's closure. `ApsiraJobsPlugin` answers one channel,
`apsira_jobs/alarms` (`persistentAlarmIds`, below); the Flutter tool builds a plugin's
Android half only when the pubspec names a plugin class. A Dart test pins the job name, the
input key and the manifest.

## The run-job receiver

`RunJobReceiver` (`RunJobReceiver.kt`) queues one named Dart job when the app's own code
asks: `apsira_link`'s `AppLinkProvider` sends it an explicit in-app broadcast (extra `job`,
the app's `com.apsiralabs.apsira_link.BACKUP_JOB` meta-data) when APSIRA calls `backup_now`
(contract `app-link.md` §5.3). It goes through `ZoneResync.enqueueOnce(context, job,
payload)`, the resync's mechanism for any job: unique by the job's name, `APPEND_OR_REPLACE`;
`enqueueResync` is unchanged. The package manifest declares it unexported with no intent
filter, so nothing outside the app reaches it; an app without `apsira_link` never sends it.
The packages share no code: `test/run_job_names_test.dart` and `apsira_link`'s
`provider_names_test.dart` pin the class name and the extra to the same values.

## The alarm-manager scheduler

`AlarmManagerScheduler(onFire, {alarmClock, canScheduleExact, settings})` is the
`AlarmScheduler` of `apsira_notify`'s per-install registry (D-APK-022) on
`android_alarm_manager_plus`: one exact alarm per `RegisteredAlarm`, under its platform id,
waking, allowed while idle, re-armed by the plugin after a reboot; `schedule` answers false
when the platform refuses; `cancel` is the only call that prunes the plugin's reboot list;
`pendingPlatformIds` reads that list (`persistent_alarm_ids` in the plugin's
SharedPreferences file) through `ApsiraJobsPlugin.kt`, so `AlarmSync` cancels the ids a
restored or transferred list brought (D-APK-022).
It lives here, not in `apsira_notify`, so LYCEUM's APK never carries the plugin (ruling R-1,
Q1-c). `AlarmSync` drives it; the app never calls it directly.

```dart
@pragma('vm:entry-point')
Future<void> reminderAlarmFired(int platformId, Map<String, dynamic> params) async {
  final firedUtc = DateTime.now().toUtc();
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await onAlarmFired(platformId: platformId, params: params, firedUtc: firedUtc,
      registry: AlarmRegistry(getApplicationSupportDirectory),
      deliver: (alarm) => notifier.show(notificationFor(alarm)));
}
```

`onAlarmFired` records the fire first (the next resync never arms it again at that
instant), then delivers, then cancels the platform alarm; each step runs whatever the one
before did, and params that are not an alarm's are a `FormatException` before anything.
An alarm id keeps its platform id while it stays registered, so ids may serve several fires
(a snooze re-arms the same id): when the registry holds the fired platform id at another
instant once `deliver` is done (a +10 min tapped, or a resync that armed the next fire, while
this one delivered), the cancel is left out, since that re-arm already replaced the fired
alarm on the plugin's reboot list (D-APK-022, F6).

**Consumer requirement:** the plugin's SharedPreferences file is per-install, like the
registry: `data_extraction_rules.xml` (both sections, and `full_backup_content`) holds
`<exclude domain="sharedpref"
path="dev.fluttercommunity.plus.android_alarm_manager_plugin.xml"/>`. The adoption checks
it with `apsira_notify`'s `expectExcludedFromDeviceBackup(…, excluded:
[...alarmBackupExclusions, ...alarmManagerBackupExclusions])`, the second list from
`package:apsira_jobs/testing.dart`. The scheduler reaches the vendored
`flutter_local_notifications` through `apsira_notify`, so `android/app` enables Java library
desugaring as `apsira_notify`'s README says (`example/` does).

| Symbol | Source | Replaces in RELAY | in VIATICUM |
|---|---|---|---|
| `AlarmManagerScheduler` | R `lib/data/platform/alarm_manager_scheduler.dart` | that file | its `AlarmManagerScheduler` |
| `alarmManagerBackupExclusions` (`testing.dart`) | the plugin's `AlarmService.java` | — | — |
| `onAlarmFired`, `alarmParams`, `alarmFromParams` | V `lib/data/platform/alarm_manager_scheduler.dart` | the fire entry's bookkeeping in `bootstrap.dart` | the same functions |

## Checks

From this directory: `flutter analyze` and `flutter test` (with `test/alarms/`: RELAY's and
VIATICUM's scheduler cases against the plugin's channel, the fire entry, and KP-A10 on the
plugin's reboot list). The Kotlin compiles only inside
an app's build, so `example/` is that app: it depends on this package by path and schedules
one job through `WorkManagerBackgroundJobs` at start, and its debug build compiles
`ApsiraJobsPlugin.kt`, `ZoneResync.kt` and `RunJobReceiver.kt` against `workmanager_android`'s `androidx.work`.
`tool/check.sh` runs the example's analyze and smoke test; the build is run by
hand, under a build lease, from `example/`:

```sh
flutter build apk --debug && rm -rf build
```

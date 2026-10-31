# apsira_jobs changelog

One section per release, naming any migration a consumer must make. Every package shares
one tag, `apsira-vX.Y.Z` (D-APK-007).

## 0.6.0 — 2026-10-31

Migration: move every apsira `ref:` to `apsira-v0.6.0`. Additive; nothing else moves.

- **`RunJobReceiver`** (D-APK-026's T2 addendum): a receiver declared in the package
  manifest, `exported="false"` and with no intent filter, so it is merged into every
  consumer's manifest and reached only by the app's own code. `apsira_link`'s
  `AppLinkProvider` sends it an explicit in-app broadcast (extra `job`, the app's
  `BACKUP_JOB` meta-data) when APSIRA calls `backup_now`; without that meta-data it never
  runs.
- **`ZoneResync.enqueueOnce(context, job, payload)`**: queues one named Dart job, unique by
  its name (`APPEND_OR_REPLACE`); `enqueueResync` is unchanged.

## 0.5.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.5.0`.

## 0.4.0 — 2026-10-24

Adds `AlarmManagerScheduler` (D-APK-022, ruling R-1 Q1-c), `apsira_notify`'s
`AlarmScheduler` on `android_alarm_manager_plus ^5.1.2`: RELAY's adapter (exact, waking,
allowed while idle, re-armed after a reboot, the alarm-clock fallback) under the
registry's platform ids, with VIATICUM's fire entry `onAlarmFired` (record, deliver,
cancel) and `alarmParams`/`alarmFromParams`. Depends on `apsira_notify` at the shared tag.
`pendingPlatformIds` reads the plugin's reboot list (`persistent_alarm_ids`) through
`ApsiraJobsPlugin`'s channel `apsira_jobs/alarms`, so `AlarmSync` cancels the ids a restore
brought; `testing.dart` adds `alarmManagerBackupExclusions`, the plugin's prefs file.
`onAlarmFired` leaves its final cancel out when the registry holds the fired platform id at
another instant once delivery is done (a snooze or the id's next fire armed meanwhile), so
alarm ids may serve several fires (F6, D-APK-022).

Migration: move every apsira `ref:` to `apsira-v0.4.0`. RELAY and VIATICUM delete their
`lib/data/platform/alarm_manager_scheduler.dart` and bind this one (VIATICUM passes its
`exactAlarmsAllowed` as `canScheduleExact`); their fire entry calls `onAlarmFired` with an
`AlarmRegistry` over app storage. Both exclude
`dev.fluttercommunity.plus.android_alarm_manager_plugin.xml` (domain `sharedpref`) from
Android's backup, checked with `alarmManagerBackupExclusions`.

## 0.3.0 — 2026-10-24

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.3.0`.

## 0.2.0 — 2026-10-24

First release (D-APK-011): VIATICUM `78d38e0`'s `BackgroundJobs` port and WorkManager
adapter (`keep`, or `replace` with `initialDelay`; never `update`), RELAY `09b28810`'s
`JobConstraints` (with `deviceIdle`, every default false) and `reminderResyncJob`, the
`FakeBackgroundJobs` in `testing.dart`, and the zone resync receiver. For RELAY and
VIATICUM only; LYCEUM does not depend on it (LYCEUM D-034).

**Receiver: branch 1.** `ZoneChangeReceiver` and `enqueueResync` moved here
(`ZoneResync.kt` plus the package manifest's `<receiver>`), because `workmanager_android`
0.10.9's `BackgroundWorker` and `PAYLOAD_PREFIX` are public. Its `androidx.work` is an
`implementation` dependency (`work-runtime:2.11.2`), which this package names at that
version, adding nothing to either APK.

**Migration for RELAY.**
- `core/ports/background_jobs.dart` and `data/platform/workmanager_background_jobs.dart`
  give way to `package:apsira_jobs/apsira_jobs.dart`. `runBackgroundJobs` and
  `handleBackgroundTask` stay in the app; they read `zoneIdInputKey`.
- `update` becomes keep/replace. Every call site that reschedules after a changed time
  of day passes `replace: true, firstRunIn: <delay to the new time>`.
- Tests: `jobs.scheduled[name]` records become `(await jobs.scheduled())[name]` and
  `jobs.constraintsOf(name)`; `run(name)` becomes `runNow(name)`.
- `ZoneModule.kt`'s channel half is `apsira_app`'s. Delete `ZoneChangeReceiver`,
  `enqueueResync` and the manifest `<receiver>`; the app's `work-runtime` line may go.

**Migration for VIATICUM.**
- The port, `JobConstraints` and adapter give way to this package. Every call site that
  relied on VIATICUM's defaults passes
  `JobConstraints(batteryNotLow: true, storageNotLow: true)` explicitly.
- `FakeBackgroundJobs` handlers return `Future<bool>`. Its clock-timed `runs()`
  (`RecordedBackgroundJobs`, `JobRun`) stay in VIATICUM, for instance by extending the fake.
- The receiver, as for RELAY: delete it and its `<receiver>`; the `work-runtime` line may go.

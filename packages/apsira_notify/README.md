# apsira_notify

The notifications every Apsira app shares: RELAY's notifier (D-APK-021, ruling C4 of
D-APK-010) as one Flutter plugin. System notifications on the app's own channels, with at
most three actions and a lock-screen public version, the permission flow with a
per-install asked flag, and the settings screens through the package's own Kotlin.

Dependencies: `apsira_app` and `apsira_core` (the git form at the shared tag, with the
committed `pubspec_overrides.yaml`, D-APK-007) and RELAY's patched
`flutter_local_notifications` 22.3.2, vendored in
`../third_party/flutter_local_notifications` (its `RELAY_PATCH.md`) and named in the same
git form, and `timezone` (the alarm scheduler's `TZDateTime`). There is no `app_settings`
(ruling R-2, Q4-c).

```yaml
dependencies:
  apsira_notify: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.4.0, path: packages/apsira_notify } }
```

An app drops its own dependency on `flutter_local_notifications`. One that still imports
the plugin directly (an alarm adapter) names the vendored copy in the same form, since pub
refuses two sources of one package:

```yaml
  flutter_local_notifications: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.4.0, path: packages/third_party/flutter_local_notifications } }
```

## Consumer requirements

- The manifest declares `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`.
- `android/app` enables Java library desugaring (`isCoreLibraryDesugaringEnabled = true`
  and `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`), which the
  plugin needs.
- A status-bar icon drawable, passed as `statusIcon`.

`example/` meets all three; `test/example_android_test.dart` checks them.

## Channels are the app's

`NotificationChannelSpec(id, name, {importance, description, silent, category,
privateOnLockScreen})`. The package holds no channel id: Android keys a user's settings
for a channel by its id, so an app passes the ids its installs already have, and never
changes one.

| App | Specs |
|---|---|
| RELAY | `relay_reminders` (high, `reminder`, private), `relay_recording` (low), `relay_backups` (default), `relay_calendar` (high, `event`, private) |
| VIATICUM | `alerts` (default), `quiet` (low, `silent`); no visibility (A-8) |
| LYCEUM | its `AppConstants.notificationChannelId` (default, private) |

`ensureChannels(specs)` creates them (safe on every start; two specs with one id are an
`ArgumentError`). Posting on a spec that was never created creates it with that spec's
settings. `toJson` and `fromJson` carry a spec to an alarm's background engine.

## Binding it

```dart
final notifier = LocalNotifier(
  statusIcon: 'ic_stat_relay',
  onBackground: onBackgroundNotificationResponse, // top-level, @pragma('vm:entry-point')
  log: log,
);
await notifier.ensureChannels(const [remindersSpec, backupsSpec]);
await notifier.show(AppNotification(
  notificationId: notificationIdFor(reminderId),
  title: title, body: body, channel: remindersSpec, payload: reminderId,
  publicTitle: 'Reminder · 18:55',
  actions: const [
    NotificationAction(actionId: 'done', label: 'Done'),
    NotificationAction(actionId: 'snooze10', label: '+10 min'),
    NotificationAction(actionId: 'snooze', label: 'Snooze…', opensApp: true),
  ],
));
```

- **Actions:** at most `AppNotification.maxActions` (3); one that runs in the background
  dismisses the notification, one that `opensApp` leaves it. A tap on the body leaves it
  too, unless `dismissOnTap` (VIATICUM's notifications, which have no actions).
- **Responses:** taps and app-opening actions while the app runs arrive on `responses`
  (`LocalNotifier.responseOf` reads the background entry's `Object`); `launchResponse()`
  answers the tap that started the process once, then null.
- **Ids:** `notificationIdFor(key)`, RELAY's 31-bit FNV-1a; VIATICUM's ASCII ids keep
  their value.
- `LocalNotifier.detailsOf(notification)` is how a notification is posted, for an alarm
  adapter that schedules through the plugin.

## Permission

`NotificationPermissionFlow(notifier, {required InstallFlag asked, exactAlarmsAllowed})`:
`access()` asks nothing; `askFor(explain: …)` shows the app's explanation first, and its
yes leads to Android's prompt the first time (the flag written before it) and to the
app's notification settings once the flag is set. The flag is per install (C1) at the
app's own path (VIATICUM `reminders/permission_asked.json`). `ReminderAccess` is
`allowed`, `notificationsDenied` or `exactAlarmsDenied`.

## Settings

`SystemSettings` (`ChannelSystemSettings` on the channel `apsira_notify/settings`,
`NotifySettingsModule.kt`): `openNotificationSettings()`,
`openBatteryOptimisationSettings()` and `openAppDetails()`, the intents `app_settings`
started, falling back to the app-details page. No activity is a `PlatformException`
(`noActivity`); anywhere but Android an `UnsupportedError`.

## Alarms: the per-install registry

D-APK-022. The alarms this install armed are a file under app storage, never the database,
so a restored database never re-arms a stale alarm and another phone's alarms never ring
here.

| Path under app storage | What | Written by |
|---|---|---|
| `AlarmRegistry.defaultPath` = `alarms/registry.json` | `{nextPlatformId, alarms[], pendingCancels[]}`, VIATICUM 1.0.0's format | the app's engine, whole (`.tmp`, flush, rename) |
| `alarms/fired.jsonl` (`AlarmRegistry.firedName`) | one line per fire | the alarm's engine, appended (`markFired`) |
| `SnoozeStore.defaultPath` = `alarms/snoozes.json` | the snoozes made from a notification | whole, like the registry |

```dart
final registry = AlarmRegistry(getApplicationSupportDirectory);
final sync = AlarmSync(scheduler, registry,
    snoozes: SnoozeStore(getApplicationSupportDirectory),
    lateGrace: Duration.zero); // LYCEUM's notification alarms; null on the alarm manager
final report = await sync.resync(wanted: wantedAlarms, now: clock.nowUtc());
```

- **`resync({wanted, now})`** applies the snoozes (one stands in for its alarm's time while
  the alarm is wanted and the snooze is ahead; the rest are pruned), leaves out what fired
  at that instant and, with `lateGrace`, what is older, takes the window (`planAlarms`:
  `reminderWindowSize` = 100 nearest), cancels every registry entry outside it, every
  pending code and every **stranger** (an id the plugin holds pending,
  `AlarmScheduler.pendingPlatformIds`, that the registry never handed out: a list a
  restore or a transfer copied, which the plugin re-arms after a reboot) before it
  unregisters them, then registers the whole window and calls `schedule` for **every**
  alarm in it. The plugin's list is read before the registry, so an alarm another engine
  arms meanwhile is never a stranger. A copied or stale registry costs a no-op cancel,
  never an unarmed alarm. `AlarmSyncReport` counts `scheduled`, `cancelled`, `refused` and
  `strangers`. The plugin's list belongs to `AlarmSync`: the app arms nothing through that
  plugin by itself.
- **`snooze(alarm, until: …)`** writes the snooze and arms it at once (the +10 min action);
  Done is the app dropping the alarm from `wanted` (and `SnoozeStore.clear`).
- **`ScheduledAlarm(alarmId, atUtc, content)`**: `content` is the fire's (VIATICUM's
  `channel`, `title`, `body`), stored in the registry, never logged; `alarmId`, `atUtcMs`
  and `platformId` are the registry's own keys.
- **Platform ids** come from the registry: kept by an alarm id while it stays registered,
  never handed out twice. RELAY's old request codes go to `addPendingCancels` once.
- **Adapters:** `FlnAlarmScheduler(notificationOf: …, ready: …)` here (LYCEUM's
  `zonedSchedule`, `exactAllowWhileIdle`, a past time skipped, the notification under the
  platform id; its `cancel` leaves a notification already showing), and
  `AlarmManagerScheduler` in `apsira_jobs` (RELAY, VIATICUM).

**Consumer requirement:** `data_extraction_rules.xml` excludes `alarms/` (or both paths)
and the plugin's scheduled list (`<exclude domain="sharedpref"
path="scheduled_notifications.xml"/>`, `flnScheduledNotifications`) in `<cloud-backup>`
and `<device-transfer>`, and `full_backup_content` too when the app has one. The adoption
runs `expectExcludedFromDeviceBackup(rules, fullBackupContent: …, paths: [the app's C1
files], excluded: [...alarmBackupExclusions, …])` from `testing.dart` on the app's own
files; `BackupPath.file`, `.sharedPref`, `.root` and `.database` name a path in each domain
(LYCEUM's `.migrating` marker is `BackupPath.root('app_flutter/lyceum.sqlite.migrating')`),
and an app on `AlarmManagerScheduler` adds `apsira_jobs`' `alarmManagerBackupExclusions`.
The check reads the `file`, `sharedpref`, `root` and `database` domains, where a `root`
folder covers the domains under it.

## What it holds, and what each app deletes

Sources: RELAY `09b28810`, VIATICUM `78d38e0`, LYCEUM `9f4ff27`; each file names its
source in its header. Paths are under the app's root; the adoption lane confirms them.

| Symbol | Source | Replaces in RELAY | in VIATICUM | in LYCEUM |
|---|---|---|---|---|
| `Notifier`, `AppNotification`, `NotificationAction`, `NotificationResponse` | R `lib/core/ports/notifier.dart` | that file | `lib/core/ports/notifier.dart` | `lib/core/ports/notifier.dart` (its `schedule` goes to the alarm registry, D-APK-022) |
| `NotificationChannelSpec`, `NotificationImportance`, `NotificationCategory` | R `NotificationChannel` and the channel ids of `local_notifier.dart`; V `ChannelLabels` | the enum and the ids | `NotificationChannel`, `ChannelLabels` | `AppConstants`' channel name and id |
| `LocalNotifier` | R `lib/data/platform/local_notifier.dart`; V `ensureChannels`, `quiet` | that file | `lib/data/platform/local_notifier.dart` | the show path of `lib/data/platform/notification_service.dart` |
| `notificationIdFor` | R `lib/domain/reminders/window.dart` | that function | `notificationIntId` | — |
| `NotificationPermissionFlow`, `ReminderAccess` | R `lib/app/services/notification_permission_service.dart`; V's asked flag | `access`, `askForReminder` (the late-delivery card stays) | `ask`, `asked` (its due stream stays) | — |
| `SystemSettings`, `ChannelSystemSettings`, `ApsiraNotifyPlugin.kt`, `NotifySettingsModule.kt` | R's `app_settings` calls | `app_settings` (the notifier, the battery card, the recorder's `openAppDetails`) | — | — |
| `FakeNotifier`, `FakeSystemSettings` (`testing.dart`) | R `test/fakes/fake_notifier.dart` | that file | `test/fakes/fake_notifier.dart` | `test/fakes/fake_notifier.dart` |
| `AlarmScheduler`, `ScheduledAlarm`, `RegisteredAlarm`, `FiredAlarm` | R and V `lib/core/ports/alarm_scheduler.dart` | that file | that file | — |
| `AlarmRegistry` | V `AlarmStore` in `lib/data/platform/alarm_manager_scheduler.dart` | `registered_alarms` (schema v12) | `AlarmStore`, `AlarmRegistry` | the ids of `isPlannedAlertId` |
| `SnoozeStore` | new (R-4) | — | — | — |
| `AlarmSync`, `AlarmSyncReport` | V `lib/app/services/reminder_sync_service.dart` (its diff and queue) | the alarm half of its reminder sync | the alarm half of `ReminderSyncService` | the cancel-and-schedule loop of `lib/app/services/reminder_service.dart` |
| `reminderWindowSize`, `nearestFires`, `planAlarms` | R `lib/domain/reminders/window.dart` | those and `requestCodeFor` | `nearestAlarms`, `planWindow` | the window of `plannedAlerts` |
| `FlnAlarmScheduler` | L `lib/data/platform/notification_service.dart` | — | — | `schedule`, `cancel`, `scheduledIds` |
| `FakeAlarmScheduler`, `expectExcludedFromDeviceBackup`, `BackupPath`, `alarmBackupExclusions` (`testing.dart`) | R and V `test/fakes/fake_alarm_scheduler.dart`; V's rules check | that fake | that fake and the check | — |
| `../third_party/flutter_local_notifications` | R `packages/flutter_local_notifications` | the copy and its override | the published 22.3.2 | the published 21.0.0 |

## Checks

From this directory: `flutter analyze` and `flutter test` (the `notify` gate): the crash
matrices (KP-N1…N3, `test/alarms/` KP-A1…A10), RELAY's notifier, permission and `fln_public_version_test.dart`,
VIATICUM's channel and tap cases, the settings channel against a mock; the registry (a
VIATICUM 1.0.0 `registry.json` fixture), the snooze store, RELAY's window, the sync,
`FlnAlarmScheduler` against the plugin's channel, and the backup-rules check on VIATICUM's
and RELAY's real `data_extraction_rules.xml`. Mocked channels
cannot see a mismatch between the Dart, Kotlin and Java halves, so `example/`'s debug build
compiles them: run by hand, under a build lease, from `example/`:
`flutter build apk --debug && rm -rf build`.

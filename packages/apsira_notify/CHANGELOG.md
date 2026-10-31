# Changelog

## 0.6.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.6.0`.

## 0.5.0 — 2026-10-31

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.5.0`.

## 0.4.0 — 2026-10-24

First release (D-APK-021): RELAY's notifier @ `09b28810` as one Flutter plugin
(`pluginClass: ApsiraNotifyPlugin`), on RELAY's patched `flutter_local_notifications`
22.3.2, now vendored in `packages/third_party/flutter_local_notifications`. Channels are the
app's specs; at most three actions; the lock-screen public version; `launchResponse` once
per process; the permission flow with a per-install asked flag; the notification, battery
and app-details settings through the package's own Kotlin on `apsira_notify/settings`. The
README maps each symbol to the app files it replaces.

The per-install alarm registry (D-APK-022): VIATICUM's `alarms/registry.json` (its format
read unchanged) as `AlarmRegistry`, a per-install `SnoozeStore` (`alarms/snoozes.json`),
`AlarmSync` (every wanted alarm armed again, the registry deciding only what to cancel;
write-ahead both ways), RELAY's window, the `AlarmScheduler` port with platform ids from
the registry, `FlnAlarmScheduler`, and in `testing.dart` `FakeAlarmScheduler` and
`expectExcludedFromDeviceBackup`. Adds `timezone ^0.11.2`. The port's
`pendingPlatformIds` answers the plugin's own persisted list, and `resync` cancels every id
on it that the registry never handed out (`AlarmSyncReport.strangers`); the backup-rules
check reads the `file`, `sharedpref`, `root` and `database` domains (`BackupPath`,
`excluded:`), and `alarmBackupExclusions` adds the plugin's `scheduled_notifications.xml`.

Migration for every app: drop the app's own `flutter_local_notifications` dependency (a
direct import names the vendored copy in the git form); declare `POST_NOTIFICATIONS` and
enable Java library desugaring; pass the app's channel ids, unchanged, as
`NotificationChannelSpec`s; build `NotificationPermissionFlow` with the app's asked-flag
path.

- RELAY: its four channels as specs; deletes `core/ports/notifier.dart`,
  `data/platform/local_notifier.dart`, the vendored copy and its override; drops
  `app_settings` (the recorder uses `openAppDetails()`, the battery card
  `openBatteryOptimisationSettings()`); asks once per install, then the settings.
- VIATICUM: `alerts` and `quiet` as specs, `dismissOnTap: true`; String ids through
  `notificationIdFor`; taps read from `responses`, ignoring those without a payload; no
  actions and no public version (A-8).
- LYCEUM: from the plugin's 21.0.0 to the vendored 22.3.2; its channel id kept; Done ·
  +10 min · Snooze… and the public version in its adoption (R-4).

Migration for the alarm registry, every app: exclude `alarms/` and
`<exclude domain="sharedpref" path="scheduled_notifications.xml"/>` from `<cloud-backup>`
and `<device-transfer>` (and `full_backup_content`), checked with
`expectExcludedFromDeviceBackup(…, excluded: alarmBackupExclusions)`; pass the wanted
alarms to `AlarmSync.resync`; arm nothing through the scheduling plugin outside it.

- RELAY: schema v12 drops `registered_alarms`; its request codes go to
  `addPendingCancels` once; `AlarmManagerScheduler` from `apsira_jobs`; adds the exclusion.
- VIATICUM: its registry and fire record carry over unchanged; `AlarmManagerScheduler` and
  `onAlarmFired` from `apsira_jobs`, its channel and texts as `content`.
- LYCEUM: `FlnAlarmScheduler` with `lateGrace: Duration.zero`, ids from the registry (its
  planned-alert ids cancelled once), snoozes in `SnoozeStore`; adds the exclusion.

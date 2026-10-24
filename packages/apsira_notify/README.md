# apsira_notify

The notifications every Apsira app shares: RELAY's notifier (D-APK-021, ruling C4 of
D-APK-010) as one Flutter plugin. System notifications on the app's own channels, with at
most three actions and a lock-screen public version, the permission flow with a
per-install asked flag, and the settings screens through the package's own Kotlin.

Dependencies: `apsira_app` and `apsira_core` (the git form at the shared tag, with the
committed `pubspec_overrides.yaml`, D-APK-007) and RELAY's patched
`flutter_local_notifications` 22.3.2, vendored in
`../third_party/flutter_local_notifications` (its `RELAY_PATCH.md`) and named in the same
git form. There is no `app_settings` (ruling R-2, Q4-c).

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
| `../third_party/flutter_local_notifications` | R `packages/flutter_local_notifications` | the copy and its override | the published 22.3.2 | the published 21.0.0 |

## Checks

From this directory: `flutter analyze` and `flutter test` (the `notify` gate): the crash
matrix (KP-N1…N3), RELAY's notifier, permission and `fln_public_version_test.dart`,
VIATICUM's channel and tap cases, the settings channel against a mock. Mocked channels
cannot see a mismatch between the Dart, Kotlin and Java halves, so `example/`'s debug build
compiles them: run by hand, under a build lease, from `example/`:
`flutter build apk --debug && rm -rf build`.

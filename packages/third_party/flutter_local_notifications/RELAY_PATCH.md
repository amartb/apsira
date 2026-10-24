# RELAY PATCH — flutter_local_notifications 22.3.2 with a lock-screen public version

Relay vendors `flutter_local_notifications` 22.3.2 here and patches it so a
notification can carry Android's *public version*
(`NotificationCompat.Builder.setPublicVersion`), which the published plugin
does not expose. Ruling R-10 (2026-10-23), decision D-217
(`docs/02-decision-log.md`), architecture §7.2, `docs/dependencies.md`.

## Why

A reminder is posted with private visibility (R-8, D-215): a locked phone hides
its content. Without a public version Android shows only Relay's name and the
time. With one, it shows "Recordatorio · 18:55" ("Reminder · 18:55"): no task
text, no note title. Relay's `LocalNotifier` sets it from
`AppNotification.publicTitle` for the Reminders and Calendar channels.

## What is here

- `pubspec.yaml`, `LICENSE`, `lib/` and `android/`, copied unchanged from
  `~/.pub-cache/hosted/pub.dev/flutter_local_notifications-22.3.2`, then
  patched. `ios/`, `macos/`, `example/` and `test/` are left out: Relay is
  Android only (D-002).
- The app's `pubspec.yaml` points at this directory with
  `dependency_overrides: flutter_local_notifications: path:
  packages/flutter_local_notifications`, so `pubspec.lock` records the source
  as `path`.
- `analysis_options.yaml` excludes `packages/**`: the plugin's code keeps its
  own style. `dart format` still covers it.
- `RELAY_PATCH.diff` is the whole patch against the pristine 22.3.2: four
  files, every edit marked `// RELAY PATCH (R-10, D-217)`.

## The diff

| File | Change |
|---|---|
| `lib/src/platform_specifics/android/notification_details.dart` | a new class, `AndroidNotificationPublicVersion({String? title, String? body})`, and `AndroidNotificationDetails.publicVersion`, an optional field that defaults to null |
| `lib/src/platform_specifics/android/method_channel_mappers.dart` | `toMap()` adds `publicVersionTitle` and `publicVersionBody`, but only when `publicVersion` is set. Without it the map is the published plugin's |
| `android/.../models/NotificationDetails.java` | the two keys are read into `publicVersionTitle` and `publicVersionBody` (Strings; Gson keeps them for scheduled notifications) |
| `android/.../FlutterLocalNotificationsPlugin.java` | `createNotification` calls `setPublicVersion(context, details, builder)` after `setVisibility`. With a title or a body, that builds a second `NotificationCompat.Builder` on the same channel, with that title and text, the same priority, small icon (`setSmallIcon`), colour and `when`, and passes its `build()` to `builder.setPublicVersion` |

The patch adds no dependency, no permission, no manifest entry and no network
code.

## Proof

- Dart: `test/data/platform/fln_public_version_test.dart` (the plugin's own
  test style, through the method channel) and the `LocalNotifier`, reminder
  and calendar tests that check `publicTitle`.
- Java: compiled only by the APK build (`tool/build_apk.sh`). The session
  checked it with `javac` against `android-36` and `androidx.core` 1.13.1.
  The device check is a locked phone showing "Recordatorio · HH:MM".

## Re-applying it on an upgrade

1. Read the new version's changelog. If upstream now exposes a public
   version, drop this directory and the override, and use upstream's.
2. Otherwise copy the new version's `pubspec.yaml`, `LICENSE`, `lib/` and
   `android/` over this directory, keeping `RELAY_PATCH.md` and
   `RELAY_PATCH.diff`.
3. Run `patch -p1 < RELAY_PATCH.diff` here. If a hunk is refused, apply it by
   hand from the table above (the anchors are `visibility` in each file), then
   regenerate the diff against the pristine copy with `diff -u`.
4. Update the version in this file, `docs/dependencies.md` and the allowlist
   reason; run `flutter pub get`, `dart run tool/privacy/deps_check.dart`,
   the tests above and `tool/build_apk.sh`.

## In apsira (D-APK-021)

This directory moved unchanged from RELAY's `packages/flutter_local_notifications` (at
`09b28810`) to `packages/third_party/flutter_local_notifications` in the apsira
repository, decision D-APK-021, so `apsira_notify` and every app share one patched copy;
this section is the only addition. Read the paths above against it:

- `apsira_notify` (and any app that imports the plugin directly) names it in the git form
  at the shared tag, `path: packages/third_party/flutter_local_notifications`; inside the
  repository `pubspec_overrides.yaml` points at `../third_party/flutter_local_notifications`.
  Apps drop their own override.
- `tool/check.sh` requires that form, carries the override in the transitive closure, and
  leaves `third_party/` out of `format` and the package loops: the plugin keeps its style.
- The Dart proof is `packages/apsira_notify/test/fln_public_version_test.dart`; the Java
  is compiled by `packages/apsira_notify/example`'s debug build.
- On an upgrade, step 4's files are `packages/apsira_notify/README.md` and the CHANGELOG,
  and the checks are `apsira_notify`'s tests and its example's debug build.

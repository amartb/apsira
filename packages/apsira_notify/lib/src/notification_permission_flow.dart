// From relay lib/app/services/notification_permission_service.dart @
// 09b28810 (ReminderAccess, the explanation before Android's prompt), with
// viaticum lib/app/services/notification_permission_service.dart @ 78d38e0's
// per-install asked flag (D-APK-010 C1, D-APK-021).
import 'package:apsira_app/apsira_app.dart';

import 'notifier.dart';

/// Whether reminders can alert, and why not.
enum ReminderAccess {
  allowed,

  /// `POST_NOTIFICATIONS` is not granted (asked and refused, or not yet).
  notificationsDenied,

  /// The system does not allow exact alarms.
  exactAlarmsDenied;

  bool get isAllowed => this == allowed;
}

/// The only code that asks for the notification permission.
///
/// - [access] says what reminders can do now and asks nothing.
/// - [askFor], for a reminder being set: without the permission, the app's
///   explanation shows first, and only its yes goes further. The first time
///   on this install that is Android's prompt, and the [asked] flag is
///   written before it; once the flag is set, the yes opens the app's
///   notification settings instead, since Android stops showing its prompt
///   after two refusals. A refusal keeps the reminder (nothing is lost):
///   reminders then show as off, with a Fix that opens the settings.
///
/// The flag is a per-install file (C1): a restore neither sets nor clears it,
/// so a restored phone asks again. Each app passes its own path (VIATICUM's
/// `reminders/permission_asked.json`).
final class NotificationPermissionFlow {
  /// [exactAlarmsAllowed] answers whether exact alarms may be set (the app's
  /// alarm scheduler); without it they count as allowed.
  NotificationPermissionFlow(
    this._notifier, {
    required this._asked,
    this._exactAlarmsAllowed,
  });

  final Notifier _notifier;
  final InstallFlag _asked;
  final Future<bool> Function()? _exactAlarmsAllowed;

  /// Whether Android's prompt was shown on this install: the next [askFor]
  /// leads to the settings, so the app may word its explanation for that.
  Future<bool> asked() => _asked.isSet();

  /// Whether reminders can alert now; asks nothing.
  Future<ReminderAccess> access() async {
    if (!await _notifier.permissionGranted()) {
      return ReminderAccess.notificationsDenied;
    }
    return _exact();
  }

  /// For a reminder being set (see the class comment). [explain] shows the
  /// app's explanation and answers true for its yes. The answer is what
  /// reminders can do after it; the caller keeps the reminder either way.
  Future<ReminderAccess> askFor({
    required Future<bool> Function() explain,
  }) async {
    if (!await _notifier.permissionGranted()) {
      if (await _asked.isSet()) {
        if (await explain()) await _notifier.openNotificationSettings();
        return ReminderAccess.notificationsDenied;
      }
      if (!await explain()) return ReminderAccess.notificationsDenied;
      await _asked.set();
      if (!await _notifier.requestPermission()) {
        return ReminderAccess.notificationsDenied;
      }
    }
    return _exact();
  }

  Future<ReminderAccess> _exact() async {
    final allowed = _exactAlarmsAllowed;
    if (allowed == null || await allowed()) return ReminderAccess.allowed;
    return ReminderAccess.exactAlarmsDenied;
  }

  /// The Fix of reminders that are off: the app's notification settings.
  Future<void> openNotificationSettings() =>
      _notifier.openNotificationSettings();
}

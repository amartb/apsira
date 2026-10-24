/// The notifications every Apsira app shares (D-APK-021): the [Notifier]
/// port and its [LocalNotifier] adapter on the patched
/// `flutter_local_notifications`, the app's own [NotificationChannelSpec]s,
/// [notificationIdFor], the [NotificationPermissionFlow] with its per-install
/// asked flag, and the [SystemSettings] screens through the package's own
/// Kotlin ([ChannelSystemSettings]).
///
/// Test fakes are in `package:apsira_notify/testing.dart`.
library;

export 'src/local_notifier.dart';
export 'src/notification_id.dart';
export 'src/notification_permission_flow.dart';
export 'src/notifier.dart';
export 'src/system_settings.dart';

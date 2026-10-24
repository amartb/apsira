/// Test fakes for the `apsira_notify` ports: a recording [FakeNotifier] that
/// lets tests tap its notifications, a counting [FakeSystemSettings], a
/// recording [FakeAlarmScheduler], and [expectExcludedFromDeviceBackup], the
/// check of an app's Android backup rules against [alarmInstallPaths].
/// For tests only; app code takes the real implementations.
library;

export 'src/alarms/testing/testing.dart';
export 'testing/fake_notifier.dart';
export 'testing/fake_system_settings.dart';

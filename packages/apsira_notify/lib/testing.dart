/// Test fakes for the `apsira_notify` ports: a recording [FakeNotifier] that
/// lets tests tap its notifications, and a counting [FakeSystemSettings].
/// For tests only; app code takes the real implementations.
library;

export 'testing/fake_notifier.dart';
export 'testing/fake_system_settings.dart';

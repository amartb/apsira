/// Test fakes for the `apsira_lock` ports: a scripted [FakeAuthenticator],
/// a recording [FakeScreenPrivacy] and an in-memory [FakeLockSettingsStore].
/// For tests only; app code takes the real implementations.
library;

export 'testing/fake_authenticator.dart';
export 'testing/fake_lock_settings_store.dart';
export 'testing/fake_screen_privacy.dart';

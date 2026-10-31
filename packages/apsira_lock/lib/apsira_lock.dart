/// The app lock every Apsira app shares (D-APK-016): the [Authenticator]
/// port and its `local_auth` adapter, hide in recent apps ([ScreenPrivacy],
/// FLAG_SECURE through the package's own Kotlin, and [RecentsPrivacy]),
/// [LockSettings] with the app's [LockSettingsStore], [LockController], the
/// [LockCover], the [LockShield] and the [LockSettingsSection].
///
/// Test fakes are in `package:apsira_lock/testing.dart`.
library;

export 'src/authenticator.dart';
export 'src/local_auth_authenticator.dart';
export 'src/lock_controller.dart';
export 'src/lock_cover.dart';
export 'src/lock_policy.dart';
export 'src/lock_settings.dart';
export 'src/lock_settings_section.dart';
export 'src/lock_shield.dart';
export 'src/recents_privacy.dart';
export 'src/screen_privacy.dart';

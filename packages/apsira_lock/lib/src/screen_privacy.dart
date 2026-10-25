// From relay lib/core/ports/screen_privacy.dart and
// lib/data/platform/screen_privacy.dart @ 09b28810, on the package's own
// channel in place of flutter_windowmanager_plus (D-APK-016, ruling R-1 Q3).
import 'package:flutter/services.dart';

/// "Hide in recent apps": whether the app's content may show in the recents
/// switcher and in screenshots.
abstract interface class ScreenPrivacy {
  /// Hides the content when [hidden] is true, shows it again when false.
  /// Hiding it also blocks screenshots of the app itself, the trade-off the
  /// setting explains. Throws when the platform cannot apply it; the caller
  /// logs that and carries on, since it never stops the app.
  Future<void> setHidden(bool hidden);
}

/// The [ScreenPrivacy] on the package's Kotlin (`ScreenPrivacyModule.kt`):
/// on Android it sets `FLAG_SECURE` on the activity's window to hide the
/// content, and clears it to show it again. With the flag set the recents
/// switcher shows a blank card and the system refuses screenshots and
/// screen recordings of the app. The plugin keeps the last state asked for
/// and sets it on every activity it attaches to, so it holds across a
/// recreated activity until it is cleared.
///
/// Platform errors (no activity attached) are not caught: the caller logs
/// them. Anywhere but Android there is no plugin, which is an
/// [UnsupportedError] here.
final class FlagSecureScreenPrivacy implements ScreenPrivacy {
  const FlagSecureScreenPrivacy();

  /// The channel the Kotlin half answers on.
  static const channelName = 'apsira_lock/screen_privacy';

  static const _channel = MethodChannel(channelName);

  @override
  Future<void> setHidden(bool hidden) async {
    try {
      await _channel.invokeMethod<void>('setHidden', hidden);
    } on MissingPluginException {
      throw UnsupportedError('FLAG_SECURE is Android only');
    }
  }
}

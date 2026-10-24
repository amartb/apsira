// From relay lib/data/platform/local_auth_authenticator.dart @ 09b28810,
// unchanged but for imports.
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import 'authenticator.dart';

/// The [Authenticator] on `local_auth`: the
/// system's BiometricPrompt, with a biometric or the device credential (PIN,
/// pattern or password), never biometric only. The prompt's title and hint
/// come from the [AuthPrompt] as `AndroidAuthMessages`, so they are in the
/// app's language, not the plugin's English defaults. The cancel
/// label is passed too, but `local_auth_android` shows it only on
/// biometric-only prompts; with the device credential allowed Android draws
/// its own "use PIN" choice instead.
///
/// Every platform error becomes an [AuthOutcome]; nothing here throws, so
/// the app lock can always decide (an unavailable or erroring prompt
/// never engages the lock). Lockouts after too many attempts are `failed`,
/// not `unavailable`, so they keep a lock that is already on.
final class LocalAuthAuthenticator implements Authenticator {
  /// [plugin] is `local_auth`'s unless a test replaces it.
  LocalAuthAuthenticator([LocalAuthentication? plugin])
    : _plugin = plugin ?? LocalAuthentication();

  final LocalAuthentication _plugin;

  /// True only when the device has an enrolled biometric or a screen lock
  /// (`isDeviceSupported`); false when the plugin cannot answer.
  @override
  Future<bool> isAvailable() async {
    try {
      return await _plugin.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthOutcome> authenticate(AuthPrompt prompt) async {
    try {
      final passed = await _plugin.authenticate(
        localizedReason: prompt.reason,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: prompt.title,
            signInHint: prompt.hint,
            cancelButton: prompt.cancel,
          ),
        ],
        biometricOnly: false,
      );
      return passed ? AuthOutcome.passed : AuthOutcome.failed;
    } on LocalAuthException catch (e) {
      return outcomeOf(e.code);
    } catch (_) {
      return AuthOutcome.unavailable;
    }
  }

  /// The outcome of a prompt that ended with [code]. A code added in a later
  /// `local_auth` is `unavailable`, which never locks the user out.
  static AuthOutcome outcomeOf(LocalAuthExceptionCode code) => switch (code) {
    LocalAuthExceptionCode.userCanceled ||
    LocalAuthExceptionCode.systemCanceled ||
    LocalAuthExceptionCode.timeout ||
    LocalAuthExceptionCode.userRequestedFallback ||
    LocalAuthExceptionCode.authInProgress => AuthOutcome.cancelled,
    LocalAuthExceptionCode.temporaryLockout ||
    LocalAuthExceptionCode.biometricLockout => AuthOutcome.failed,
    _ => AuthOutcome.unavailable,
  };
}

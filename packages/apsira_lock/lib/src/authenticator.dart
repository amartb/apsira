// From relay lib/core/ports/authenticator.dart @ 09b28810, with
// AuthPrompt.of in place of relay lib/features/lock/state/lock_controller.dart's
// `authPromptOf` (the strings are ApsiraL10n's, the reason the app's).
import 'package:apsira_l10n/apsira_l10n.dart';

/// The biometric or device-credential prompt for the app lock (D-APK-016).
abstract interface class Authenticator {
  /// Whether the device has a biometric or a screen lock to prompt with.
  Future<bool> isAvailable();

  /// Shows the system prompt with [prompt]'s text, already localised by the
  /// caller.
  Future<AuthOutcome> authenticate(AuthPrompt prompt);
}

enum AuthOutcome { passed, failed, cancelled, unavailable }

/// What the system prompt says, in the user's language: the platform's own
/// defaults are English only.
final class AuthPrompt {
  const AuthPrompt({
    required this.reason,
    required this.title,
    required this.hint,
    required this.cancel,
  });

  /// The prompt in [l10n]'s language: the title names [appName], the hint and
  /// the cancel label are the shared ones, and [reason] is the app's own text
  /// (what unlocking shows).
  ///
  /// `cancel` is passed but not shown: `local_auth_android` sets the cancel
  /// label (BiometricPrompt's negative button) only on biometric-only
  /// prompts, and the lock allows the device credential, where Android draws
  /// its own "use PIN" choice and no cancel button. Back still cancels.
  factory AuthPrompt.of(
    ApsiraL10n l10n, {
    required String appName,
    required String reason,
  }) => AuthPrompt(
    reason: reason,
    title: l10n.lockPromptTitle(appName),
    hint: l10n.lockPromptHint,
    cancel: l10n.commonCancel,
  );

  /// Why the app asks: the prompt's description.
  final String reason;

  /// The prompt's title.
  final String title;

  /// The line under the title.
  final String hint;

  /// The button that closes the prompt without unlocking, where the
  /// platform shows one: on Android only on biometric-only prompts, so not
  /// on the app lock's, which allow the device credential.
  final String cancel;

  @override
  bool operator ==(Object other) =>
      other is AuthPrompt &&
      other.reason == reason &&
      other.title == title &&
      other.hint == hint &&
      other.cancel == cancel;

  @override
  int get hashCode => Object.hash(reason, title, hint, cancel);

  @override
  String toString() => 'AuthPrompt($title)';
}

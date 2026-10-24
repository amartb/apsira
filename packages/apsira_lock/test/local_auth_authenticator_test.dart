// From relay test/data/platform/local_auth_authenticator_test.dart @ 09b28810,
// unchanged but for names: the prompt's strings come from ApsiraL10n and the
// app's own reason (AuthPrompt.of); the MainActivity check is the example's
// (example_android_test.dart).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// A scripted `local_auth` plugin: each member returns or throws what the
/// test sets, and [authenticate] records the options it was called with.
final class _Plugin implements LocalAuthentication {
  Object? supported = true;
  Object? result = true;
  String? reason;
  bool? biometricOnly;
  List<AuthMessages>? messages;

  Future<T> _answer<T>(Object? scripted) async {
    if (scripted is T) return scripted;
    throw scripted!;
  }

  @override
  Future<bool> isDeviceSupported() => _answer<bool>(supported);

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) {
    reason = localizedReason;
    messages = authMessages.toList();
    this.biometricOnly = biometricOnly;
    return _answer<bool>(result);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not scripted');
}

const _prompt = AuthPrompt(
  reason: 'Unlock Relay',
  title: 'Title',
  hint: 'Hint',
  cancel: 'Cancel',
);

LocalAuthException _code(LocalAuthExceptionCode code) =>
    LocalAuthException(code: code);

void main() {
  late _Plugin plugin;
  late Authenticator authenticator;

  setUp(() {
    plugin = _Plugin();
    authenticator = LocalAuthAuthenticator(plugin);
  });

  group('AuthPrompt.of', () {
    test('title, hint and cancel are ApsiraL10n\'s; the reason is the '
        'app\'s', () {
      expect(
        AuthPrompt.of(
          const ApsiraL10nEs(),
          appName: 'Relay',
          reason: 'Desbloquea Relay para ver tus notas y tareas.',
        ),
        const AuthPrompt(
          reason: 'Desbloquea Relay para ver tus notas y tareas.',
          title: 'Desbloquear Relay',
          hint: 'Confirma que eres tú',
          cancel: 'Cancelar',
        ),
      );
      expect(
        AuthPrompt.of(const ApsiraL10nEn(), appName: 'Relay', reason: 'r'),
        const AuthPrompt(
          reason: 'r',
          title: 'Unlock Relay',
          hint: "Confirm it's you",
          cancel: 'Cancel',
        ),
      );
    });
  });

  group('isAvailable', () {
    test('is true when the device has a biometric or a screen lock', () async {
      plugin.supported = true;
      expect(await authenticator.isAvailable(), isTrue);
    });

    test('is false when it has neither', () async {
      plugin.supported = false;
      expect(await authenticator.isAvailable(), isFalse);
    });

    for (final error in <Object>[
      _code(LocalAuthExceptionCode.uiUnavailable),
      PlatformException(code: 'error'),
      MissingPluginException(),
      StateError('anything'),
    ]) {
      test('is false, never throws, on ${error.runtimeType}', () async {
        plugin.supported = error;
        expect(await authenticator.isAvailable(), isFalse);
      });
    }
  });

  group('authenticate', () {
    test('prompts with the caller\'s reason, biometric or device credential '
        '(biometricOnly false, D-019)', () async {
      await authenticator.authenticate(_prompt);
      expect(plugin.reason, 'Unlock Relay');
      expect(plugin.biometricOnly, isFalse);
    });

    test('the Spanish prompt reaches BiometricPrompt as AndroidAuthMessages '
        '(D-030)', () async {
      await authenticator.authenticate(
        AuthPrompt.of(
          const ApsiraL10nEs(),
          appName: 'Relay',
          reason: 'Desbloquea Relay para ver tus notas y tareas.',
        ),
      );
      expect(plugin.reason, 'Desbloquea Relay para ver tus notas y tareas.');
      final android = plugin.messages!.whereType<AndroidAuthMessages>().single;
      expect(android.signInTitle, 'Desbloquear Relay');
      expect(android.signInHint, 'Confirma que eres tú');
      expect(android.cancelButton, 'Cancelar');
    });

    test('a passed prompt is passed', () async {
      plugin.result = true;
      expect(await authenticator.authenticate(_prompt), AuthOutcome.passed);
    });

    test('a failed challenge is failed', () async {
      plugin.result = false;
      expect(await authenticator.authenticate(_prompt), AuthOutcome.failed);
    });

    const expected = {
      LocalAuthExceptionCode.userCanceled: AuthOutcome.cancelled,
      LocalAuthExceptionCode.systemCanceled: AuthOutcome.cancelled,
      LocalAuthExceptionCode.timeout: AuthOutcome.cancelled,
      LocalAuthExceptionCode.userRequestedFallback: AuthOutcome.cancelled,
      LocalAuthExceptionCode.authInProgress: AuthOutcome.cancelled,
      LocalAuthExceptionCode.temporaryLockout: AuthOutcome.failed,
      LocalAuthExceptionCode.biometricLockout: AuthOutcome.failed,
      LocalAuthExceptionCode.noCredentialsSet: AuthOutcome.unavailable,
      LocalAuthExceptionCode.noBiometricsEnrolled: AuthOutcome.unavailable,
      LocalAuthExceptionCode.noBiometricHardware: AuthOutcome.unavailable,
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          AuthOutcome.unavailable,
      LocalAuthExceptionCode.uiUnavailable: AuthOutcome.unavailable,
      LocalAuthExceptionCode.deviceError: AuthOutcome.unavailable,
      LocalAuthExceptionCode.unknownError: AuthOutcome.unavailable,
    };

    test('the mapping covers every LocalAuthExceptionCode', () {
      expect(expected.keys.toSet(), LocalAuthExceptionCode.values.toSet());
    });

    for (final MapEntry(key: code, value: outcome) in expected.entries) {
      test('${code.name} is ${outcome.name}', () async {
        plugin.result = _code(code);
        expect(await authenticator.authenticate(_prompt), outcome);
      });
    }

    for (final error in <Object>[
      PlatformException(code: 'error'),
      MissingPluginException(),
      StateError('anything'),
    ]) {
      test('${error.runtimeType} is unavailable, never thrown', () async {
        plugin.result = error;
        expect(
          await authenticator.authenticate(_prompt),
          AuthOutcome.unavailable,
        );
      });
    }
  });
}

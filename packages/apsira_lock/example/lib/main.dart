// A minimal consumer of apsira_lock, bound as an Apsira app binds it: the
// local_auth prompt, FLAG_SECURE through the package's channel, the app's
// clock, and a store of its own (here in memory: the lock is off at every
// start until it is turned on in the rows below). Its debug build is the
// proof that the package's Android half compiles (AC-11.6).
import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

void main() {
  runApp(
    ProviderScope(
      overrides: [
        authenticatorProvider.overrideWithValue(LocalAuthAuthenticator()),
        screenPrivacyProvider.overrideWithValue(
          const FlagSecureScreenPrivacy(),
        ),
        lockClockProvider.overrideWithValue(const SystemClock()),
        lockLogProvider.overrideWithValue(Log([], debugEnabled: false)),
        lockSettingsStoreProvider.overrideWithValue(MemoryLockSettingsStore()),
      ],
      child: const ExampleApp(),
    ),
  );
}

/// The lock's settings for the example's life only.
final class MemoryLockSettingsStore implements LockSettingsStore {
  Map<String, Object?>? _row;

  @override
  Future<LockSettings> read() async => LockSettings.fromJson(_row);

  @override
  Future<void> write(LockSettings settings) async =>
      _row = settings.mergeInto(_row);
}

/// The example app: the shield over a screen with the lock's Settings rows.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  /// What a test binds in place of the device's ports.
  static List<Override> overridesFor({
    required Authenticator authenticator,
    required ScreenPrivacy screenPrivacy,
    required Clock clock,
    required LockSettingsStore store,
  }) => [
    authenticatorProvider.overrideWithValue(authenticator),
    screenPrivacyProvider.overrideWithValue(screenPrivacy),
    lockClockProvider.overrideWithValue(clock),
    lockLogProvider.overrideWithValue(Log([], debugEnabled: false)),
    lockSettingsStoreProvider.overrideWithValue(store),
  ];

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'apsira_lock example',
    theme: ApsiraThemeData.light,
    darkTheme: ApsiraThemeData.dark,
    themeMode: ThemeMode.dark,
    localizationsDelegates: const [ApsiraL10n.delegate],
    supportedLocales: ApsiraL10n.supportedLocales,
    builder: (context, child) => LockShield(
      appTitle: 'Example',
      promptReason: (_) => 'Unlock the example.',
      child: child!,
    ),
    home: const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(child: LockSettingsSection()),
      ),
    ),
  );
}

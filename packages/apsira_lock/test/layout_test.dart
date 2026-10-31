// AC-11.4: the cover (with its retry and Unlock), the shield while locked and
// the Settings rows lay out soundly in English and Spanish from 100 % to
// 200 % text, both themes and both phone sizes (apsira_test's
// expectLayoutSound).
import 'package:apsira_core/testing.dart';
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:apsira_test/apsira_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lock_test_support.dart';

const host = LayoutHost(
  localizationsDelegates: [
    ApsiraL10n.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: ApsiraL10n.supportedLocales,
);

void main() {
  testWidgets('the cover with its retry and Unlock: EN/ES × 100–200 %', (
    tester,
  ) async {
    await expectLayoutSound(
      tester,
      () => LockCover(appTitle: 'Viaticum', onUnlock: () {}, showRetry: true),
      host: host,
    );
  });

  testWidgets('the shield while locked: EN/ES × 100–200 %', (tester) async {
    await expectLayoutSound(
      tester,
      () => ProviderScope(
        overrides: lockOverrides(
          store: settingsOf(const LockSettings(enabled: true)),
          authenticator: FakeAuthenticator(script: [AuthOutcome.cancelled]),
          clock: FakeClock(t0),
          sink: MemorySink(),
        ),
        child: LockShield(
          appTitle: 'Viaticum',
          promptReason: (_) => 'Unlock Viaticum to see your trips.',
          child: const Scaffold(body: Text('content')),
        ),
      ),
      host: host,
    );
  });

  testWidgets('the Settings rows, lock on, with a note: EN/ES × 100–200 %', (
    tester,
  ) async {
    await expectLayoutSound(
      tester,
      () => ProviderScope(
        overrides: [
          lockSettingsStoreProvider.overrideWithValue(
            settingsOf(const LockSettings(enabled: true, timeoutMinutes: 15)),
          ),
        ],
        child: const Scaffold(
          body: SingleChildScrollView(
            child: LockSettingsSection(
              note:
                  'The calendar opens without the lock and shows task and '
                  'note titles.',
            ),
          ),
        ),
      ),
      host: host,
    );
  });

  testWidgets('the mandatory Settings rows: EN/ES × 100–200 %', (tester) async {
    await expectLayoutSound(
      tester,
      () => ProviderScope(
        overrides: [
          lockPolicyProvider.overrideWithValue(LockPolicy.mandatory),
          lockSettingsStoreProvider.overrideWithValue(
            settingsOf(const LockSettings(enabled: true, timeoutMinutes: 1)),
          ),
        ],
        child: const Scaffold(
          body: SingleChildScrollView(child: LockSettingsSection()),
        ),
      ),
      host: host,
    );
  });

  testWidgets('the cover with a long notice and Unlock: EN/ES × 100–200 %', (
    tester,
  ) async {
    await expectLayoutSound(
      tester,
      () => Builder(
        builder: (context) => LockCover(
          appTitle: 'APSIRA',
          onUnlock: () {},
          notice: _longNotice(context),
        ),
      ),
      host: host,
    );
  });

  testWidgets('the mandatory shield that cannot prompt: EN/ES × 100–200 %', (
    tester,
  ) async {
    await expectLayoutSound(
      tester,
      () => ProviderScope(
        overrides: lockOverrides(
          store: settingsOf(const LockSettings(enabled: true)),
          authenticator: FakeAuthenticator(available: false),
          clock: FakeClock(t0),
          sink: MemorySink(),
          policy: LockPolicy.mandatory.copyWith(
            cannotPromptMessage: _longNotice,
          ),
        ),
        child: LockShield(
          appTitle: 'APSIRA',
          promptReason: (_) => 'Unlock APSIRA to see your vault.',
          child: const Scaffold(body: Text('content')),
        ),
      ),
      host: host,
    );
  });
}

/// The app's line for a device with no screen lock, long, in the language
/// at [context].
String _longNotice(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'es'
    ? 'Este teléfono no tiene bloqueo de pantalla. Configura un PIN, un '
          'patrón o una contraseña en los ajustes de seguridad del teléfono '
          'y vuelve a intentarlo para abrir APSIRA.'
    : 'This phone has no screen lock. Set a PIN, pattern or password in the '
          'phone\'s security settings, then try again to open APSIRA.';

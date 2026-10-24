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
}

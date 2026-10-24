// The lock's settings record (D-APK-016, AC-11.3): RELAY's `lock` row
// (relay lib/features/lock/README.md @ 09b28810) byte for byte, missing or
// mistyped fields read as their defaults, the fields of a later version kept
// on a write (relay lib/features/lock/ui/lock_settings_section.dart's
// updateLockSettings), and lockSettingsProvider over the app's store.
import 'dart:convert';

import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the row', () {
    test('the defaults encode as RELAY\'s row, byte for byte', () {
      expect(
        jsonEncode(LockSettings.defaults.toJson()),
        '{"enabled":false,"timeoutMinutes":5,"hideInRecents":false}',
      );
    });

    for (final row in [
      '{"enabled":false,"timeoutMinutes":5,"hideInRecents":false}',
      '{"enabled":true,"timeoutMinutes":0,"hideInRecents":true}',
      '{"enabled":true,"timeoutMinutes":30,"hideInRecents":false}',
      '{"enabled":false,"timeoutMinutes":7,"hideInRecents":true}',
    ]) {
      test('round-trips $row', () {
        expect(
          jsonEncode(LockSettings.fromJson(jsonDecode(row)).toJson()),
          row,
        );
      });
    }

    test('a missing field is its default', () {
      expect(LockSettings.fromJson(<String, Object?>{}), LockSettings.defaults);
      expect(
        LockSettings.fromJson({'enabled': true}),
        const LockSettings(enabled: true),
      );
      expect(
        LockSettings.fromJson({'hideInRecents': true}),
        const LockSettings(hideInRecents: true),
      );
    });

    test('a later version\'s fields are kept on a write', () {
      expect(
        const LockSettings(hideInRecents: true).mergeInto({
          'enabled': false,
          'timeoutMinutes': 15,
          'pin': {'later': 1},
        }),
        {
          'enabled': false,
          'timeoutMinutes': 5,
          'hideInRecents': true,
          'pin': {'later': 1},
        },
      );
      expect(
        LockSettings.defaults.mergeInto(null),
        LockSettings.defaults.toJson(),
      );
    });

    test('the timeouts Settings offers: Immediately to 30 minutes', () {
      expect(lockTimeoutOptions, [0, 1, 5, 15, 30]);
    });

    test('copyWith changes only what it is given', () {
      expect(
        LockSettings.defaults.copyWith(enabled: true),
        const LockSettings(enabled: true),
      );
      expect(
        const LockSettings(enabled: true).copyWith(timeoutMinutes: 0),
        const LockSettings(enabled: true, timeoutMinutes: 0),
      );
      expect(
        LockSettings.defaults.copyWith(hideInRecents: true),
        const LockSettings(hideInRecents: true),
      );
    });
  });

  group('lockSettingsProvider', () {
    ProviderContainer start(FakeLockSettingsStore store) {
      final c = ProviderContainer(
        overrides: [lockSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(c.dispose);
      c.listen(lockSettingsProvider, (_, _) {});
      return c;
    }

    test('reads the row through the store', () async {
      final c = start(FakeLockSettingsStore(row: {'enabled': true}));
      expect(
        await c.read(lockSettingsProvider.future),
        const LockSettings(enabled: true),
      );
    });

    test('no row: the defaults', () async {
      final c = start(FakeLockSettingsStore());
      expect(await c.read(lockSettingsProvider.future), LockSettings.defaults);
    });

    test(
      'update reads the row again, writes the change and follows it',
      () async {
        final store = FakeLockSettingsStore(row: {'pin': 1});
        final c = start(store);
        await c.read(lockSettingsProvider.future);
        store.row = {'timeoutMinutes': 15, 'pin': 1};
        await c
            .read(lockSettingsProvider.notifier)
            .change((s) => s.copyWith(enabled: true));
        expect(store.writes, [
          const LockSettings(enabled: true, timeoutMinutes: 15),
        ]);
        expect(store.row, {
          'timeoutMinutes': 15,
          'pin': 1,
          'enabled': true,
          'hideInRecents': false,
        });
        expect(
          c.read(lockSettingsProvider).value,
          const LockSettings(enabled: true, timeoutMinutes: 15),
        );
      },
    );

    test('a failed write rethrows and keeps what was read', () async {
      final store = FakeLockSettingsStore(writeError: StateError('full'));
      final c = start(store);
      await c.read(lockSettingsProvider.future);
      await expectLater(
        c
            .read(lockSettingsProvider.notifier)
            .change((s) => s.copyWith(enabled: true)),
        throwsStateError,
      );
      expect(c.read(lockSettingsProvider).value, LockSettings.defaults);
    });

    test('a read that fails is an error, never retried', () async {
      final store = FakeLockSettingsStore(readError: StateError('closed'));
      final c = start(store);
      await expectLater(c.read(lockSettingsProvider.future), throwsStateError);
      await pumpEventQueue();
      expect(c.read(lockSettingsProvider).hasError, isTrue);
      expect(store.reads, 1);
    });
  });
}

// From relay test/features/lock/lock_settings_section_test.dart @ 09b28810,
// unchanged but for names (D-APK-016): the rows write through
// lockSettingsProvider into the app's store (FakeLockSettingsStore here, in
// place of RELAY's database), which keeps the fields it does not know; the
// strings are ApsiraL10n's. The note is RELAY's KAIROS note
// (relay lib/app/router.dart's `_LockRowsWithCalendarNote`).
//
// The lock rows of Settings → Privacy & security: App lock with its timeout,
// and Hide in recent apps; the switches draw the `accentFill` track when on
// and a `ring` outline when off.
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_lock/apsira_lock.dart';
import 'package:apsira_lock/testing.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _en = ApsiraL10nEn();

void main() {
  late FakeLockSettingsStore store;

  setUp(() => store = FakeLockSettingsStore());

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    String? note,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [lockSettingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? ApsiraThemeData.dark
              : ApsiraThemeData.light,
          localizationsDelegates: const [ApsiraL10n.delegate],
          supportedLocales: ApsiraL10n.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: LockSettingsSection(note: note)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Switch switchOf(WidgetTester tester, String key) => tester.widget<Switch>(
    find.descendant(
      of: find.byKey(ValueKey('lock/settings/$key')),
      matching: find.byType(Switch),
    ),
  );

  testWidgets('with no row: the lock off, no timeout row, recents shown', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(_en.lockSettingsTitle), findsOneWidget);
    expect(find.text(_en.lockSettingsSubline), findsOneWidget);
    expect(find.text(_en.lockHideInRecents), findsOneWidget);
    expect(find.text(_en.lockHideInRecentsSubline), findsOneWidget);
    expect(switchOf(tester, 'enabled').value, isFalse);
    expect(switchOf(tester, 'hideInRecents').value, isFalse);
    expect(find.text(_en.lockAfter), findsNothing);
  });

  testWidgets('the dividers stay inside the card: inset from the text '
      'column to the card\'s side padding', (tester) async {
    await pump(tester);
    for (final divider in tester.widgetList<Divider>(find.byType(Divider))) {
      expect(divider.endIndent, ApsiraSpacing.cardSide);
    }
    expect(find.byType(Divider), findsWidgets);
  });

  testWidgets('turning the lock on writes the row and shows the timeout, '
      '5 minutes by default', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('lock/settings/enabled')));
    await tester.pumpAndSettle();
    expect(store.row, {
      'enabled': true,
      'timeoutMinutes': 5,
      'hideInRecents': false,
    });
    expect(switchOf(tester, 'enabled').value, isTrue);
    expect(find.text(_en.lockAfter), findsOneWidget);
    expect(find.text(_en.lockAfterMinutes(5)), findsOneWidget);
  });

  testWidgets('the timeout menu offers Immediately to 30 minutes and stores '
      'the choice', (tester) async {
    store.row = {'enabled': true};
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('lock/settings/timeout')));
    await tester.pumpAndSettle();
    for (final label in [
      _en.lockImmediately,
      _en.lockAfterMinutes(1),
      _en.lockAfterMinutes(15),
      _en.lockAfterMinutes(30),
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text(_en.lockImmediately));
    await tester.pumpAndSettle();
    expect(store.row, {
      'enabled': true,
      'timeoutMinutes': 0,
      'hideInRecents': false,
    });
    expect(find.text(_en.lockImmediately), findsOneWidget);
  });

  testWidgets('a stored timeout outside the list is offered too', (
    tester,
  ) async {
    store.row = {'enabled': true, 'timeoutMinutes': 7};
    await pump(tester);
    expect(find.text(_en.lockAfterMinutes(7)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lock/settings/timeout')));
    await tester.pumpAndSettle();
    expect(find.text(_en.lockAfterMinutes(7)), findsNWidgets(2));
  });

  testWidgets('hide in recents is stored, and unknown fields are kept', (
    tester,
  ) async {
    store.row = {
      'enabled': false,
      'timeoutMinutes': 15,
      'pin': {'later': 1},
    };
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('lock/settings/hideInRecents')));
    await tester.pumpAndSettle();
    expect(store.row, {
      'enabled': false,
      'timeoutMinutes': 15,
      'hideInRecents': true,
      'pin': {'later': 1},
    });
    expect(switchOf(tester, 'hideInRecents').value, isTrue);
  });

  testWidgets('the switches wait for the read', (tester) async {
    store.holdReads();
    await pump(tester);
    expect(switchOf(tester, 'enabled').onChanged, isNull);
    store.releaseReads();
    await tester.pumpAndSettle();
    expect(switchOf(tester, 'enabled').onChanged, isNotNull);
  });

  testWidgets('the app\'s note shows under the rows', (tester) async {
    await pump(tester, note: 'The calendar opens without the lock.');
    expect(find.byKey(const ValueKey('lock/settings/note')), findsOneWidget);
    expect(find.text('The calendar opens without the lock.'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('switches use accentFill when on and ring when off '
        '(${brightness.name})', (tester) async {
      store.row = {'enabled': true};
      await pump(tester, brightness: brightness);
      final t = brightness == Brightness.dark
          ? ApsiraTheme.dark
          : ApsiraTheme.light;
      final on = switchOf(tester, 'enabled');
      final off = switchOf(tester, 'hideInRecents');
      expect(on.value, isTrue);
      expect(on.activeTrackColor, t.accentFill);
      expect(
        on.trackOutlineColor!.resolve({WidgetState.selected}),
        t.accentFill,
      );
      expect(off.value, isFalse);
      expect(off.trackOutlineColor!.resolve({}), t.ring);
      expect(off.inactiveThumbColor, t.ring);
    });
  }
}

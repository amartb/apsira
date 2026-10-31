import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/backups.dart';
import 'package:apsira_link/requests.dart';
import 'package:apsira_link/testing/fake_app_link_requests.dart';
import 'package:apsira_link/testing/fake_apsira_backup_target.dart';
import 'package:apsira_link_example/main.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The example hands a backup over through ApsiraBackupTarget and takes
// APSIRA's restore offer through its own confirmation (contract app-link.md
// §5.1, §5.4; D-034), against the fakes; APSIRA absent is "unavailable" and
// nothing throws (§1).
final _now = DateTime.utc(2026, 10, 31, 9, 30);
String _hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

late FakeApsiraBackupTarget _target;
late FakeAppLinkRequests _requests;

Future<void> _start(WidgetTester tester) async {
  await tester.pumpWidget(
    ExampleApp(
      link: _target.link,
      target: _target,
      requests: _requests,
      clock: FakeClock(_now),
    ),
  );
  await tester.pumpAndSettle();
}

/// A backup APSIRA holds and has shipped home: the offer for it.
Future<RestoreOffer> _shipped() async {
  await _target.write(_target.folder, 'old.bin', Stream.value(examplePayload));
  final snapshot = _target.backups.ship('old.bin');
  return RestoreOffer(
    name: 'old.bin',
    snapshot: snapshot,
    madeUtc: _now,
    sizeBytes: examplePayload.length,
    reason: RestoreReason.user,
  );
}

void main() {
  setUp(() {
    _target = FakeApsiraBackupTarget(
      appPackage: 'com.apsiralabs.apsira_link_example',
      clock: FakeClock(_now),
    );
    _requests = FakeAppLinkRequests();
  });

  testWidgets('a backup handed over lands queued with its SHA-256', (
    tester,
  ) async {
    await _start(tester);
    await tester.tap(find.text('Back up to APSIRA'));
    await tester.pumpAndSettle();
    expect(find.text('backup: queued (4096 bytes)'), findsOneWidget);
    final entry = (await _target.backups.backupList()).valueOrNull!.single;
    expect(entry.state, LinkBackupState.queued);
    expect(entry.sizeBytes, 4096);
    expect(_hex(_target.backups.bytesOf(entry.name)!), _hex(examplePayload));
  });

  testWidgets('a waiting offer reaches the confirmation at start', (
    tester,
  ) async {
    _requests.offer(await _shipped());
    await _start(tester);
    expect(find.text('Restore from APSIRA?'), findsOneWidget);
    expect(_requests.pending, isNull);
  });

  testWidgets('yes restores the same bytes through the target', (tester) async {
    final offer = await _shipped();
    await _start(tester);
    _requests.offer(offer);
    await tester.pumpAndSettle();
    expect(find.text('Restore from APSIRA?'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('restored 4096 bytes'), findsOneWidget);
    expect(find.text('sha256 ${_hex(examplePayload)}'), findsOneWidget);
    expect(_target.backups.calls, contains('restore_open'));
  });

  testWidgets('no restores nothing', (tester) async {
    _requests.offer(await _shipped());
    await _start(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Restore from APSIRA?'), findsNothing);
    expect(find.textContaining('restored'), findsNothing);
    expect(_target.backups.calls, isNot(contains('restore_open')));
  });

  testWidgets('APSIRA absent: the button says unavailable, nothing throws', (
    tester,
  ) async {
    _target.link.helloResult = Err(
      LinkUnavailable(LinkUnavailableReason.notInstalled),
    );
    _target.backups.unavailable = LinkUnavailableReason.notInstalled;
    await _start(tester);
    expect(find.text('Back up to APSIRA: unavailable'), findsOneWidget);
    await tester.tap(find.text('Back up to APSIRA: unavailable'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('unavailable: not_installed'), findsOneWidget);
    expect(_target.backups.calls, isEmpty);
  });

  testWidgets('APSIRA gone after the start: the backup says unavailable', (
    tester,
  ) async {
    await _start(tester);
    _target.backups.unavailable = LinkUnavailableReason.noAnswer;
    await tester.tap(find.text('Back up to APSIRA'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('backup: unavailable'), findsOneWidget);
  });

  testWidgets('a restore APSIRA cannot serve says unavailable', (tester) async {
    final offer = await _shipped();
    _target.backups.away = true;
    _requests.offer(offer);
    await _start(tester);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('restore: unavailable'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

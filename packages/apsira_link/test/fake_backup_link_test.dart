import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/backups.dart';
import 'package:apsira_link/testing/fake_backup_link.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';

// FakeApsiraBackupLink (K2-02b) keeps contract app-link.md §5.2's rules: the
// stated SHA-256 checked on commit, a shipped backup never deleted (D-008),
// a shipped restore away from home `away`, the queue cap `storage_full`.
String _hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

final _made = DateTime.utc(2026, 10, 31, 9, 30);

/// Hands [bytes] over as [name] (begin, write, commit), as an app does.
Future<Result<LinkBackupState, LinkFailure>> _backUp(
  ApsiraBackupLink link,
  String name,
  List<int> bytes, {
  String? statedSha256,
  int? statedSize,
}) async {
  final begun = await link.backupBegin(name, size: bytes.length);
  final ticket = begun.valueOrNull;
  if (ticket == null) return Err(begun.failureOrNull!);
  final written = await link.backupWrite(ticket, Stream.value(bytes));
  if (written case Err(:final failure)) return Err(failure);
  return link.backupCommit(
    ticket.ticket,
    sha256: statedSha256 ?? _hex(bytes),
    size: statedSize ?? bytes.length,
  );
}

Future<List<int>> _restore(
  ApsiraBackupLink link, {
  String? name,
  String? snapshot,
}) async {
  final open = (await link.restoreOpen(
    name: name,
    snapshot: snapshot,
  )).valueOrNull!;
  return open.bytes.expand((b) => b).toList();
}

void main() {
  late FakeApsiraBackupLink link;

  setUp(() => link = FakeApsiraBackupLink(clock: FakeClock(_made)));

  test('a committed backup is queued, listed and restorable', () async {
    expect(
      await _backUp(link, 'a.zip', [1, 2, 3]),
      const Ok<LinkBackupState, LinkFailure>(LinkBackupState.queued),
    );
    expect((await link.backupList()).valueOrNull, [
      LinkBackupEntry(
        name: 'a.zip',
        sizeBytes: 3,
        madeUtc: _made,
        state: LinkBackupState.queued,
      ),
    ]);
    expect(link.bytesOf('a.zip'), [1, 2, 3]);
    expect(await _restore(link, name: 'a.zip'), [1, 2, 3]);
  });

  group('commit checks the stated SHA-256 and size', () {
    test(
      'a wrong SHA-256 is checksum_mismatch and the write discarded',
      () async {
        expect(
          await _backUp(link, 'a.zip', [1, 2, 3], statedSha256: _hex([9])),
          Err<LinkBackupState, LinkFailure>(
            LinkCallFailed(LinkErrorCode.checksumMismatch),
          ),
        );
        expect((await link.backupList()).valueOrNull, isEmpty);
      },
    );

    test('a wrong size is checksum_mismatch', () async {
      expect(
        await _backUp(link, 'a.zip', [1, 2, 3], statedSize: 4),
        Err<LinkBackupState, LinkFailure>(
          LinkCallFailed(LinkErrorCode.checksumMismatch),
        ),
      );
    });

    test('an upper-case SHA-256 is the same digest', () async {
      expect(
        await _backUp(link, 'a.zip', [
          1,
          2,
          3,
        ], statedSha256: _hex([1, 2, 3]).toUpperCase()),
        const Ok<LinkBackupState, LinkFailure>(LinkBackupState.queued),
      );
    });

    test('an unknown ticket is not_found; a ticket commits once', () async {
      expect(
        await link.backupCommit('nope', sha256: _hex([]), size: 0),
        Err<LinkBackupState, LinkFailure>(
          LinkCallFailed(LinkErrorCode.notFound),
        ),
      );
      final ticket = (await link.backupBegin('a.zip')).valueOrNull!;
      await link.backupWrite(ticket, Stream.value([1]));
      await link.backupCommit(ticket.ticket, sha256: _hex([1]), size: 1);
      expect(
        await link.backupCommit(ticket.ticket, sha256: _hex([1]), size: 1),
        Err<LinkBackupState, LinkFailure>(
          LinkCallFailed(LinkErrorCode.notFound),
        ),
      );
    });

    test('a failing source discards the write', () async {
      final ticket = (await link.backupBegin('a.zip')).valueOrNull!;
      expect(
        await link.backupWrite(ticket, Stream.error(StateError('disk'))),
        Err<LinkWritten, LinkFailure>(
          LinkUnavailable(LinkUnavailableReason.unknownError),
        ),
      );
      expect(
        await link.backupCommit(ticket.ticket, sha256: _hex([]), size: 0),
        Err<LinkBackupState, LinkFailure>(
          LinkCallFailed(LinkErrorCode.notFound),
        ),
      );
    });
  });

  group('a shipped backup is never deleted (D-008)', () {
    test('delete removes a queued copy', () async {
      await _backUp(link, 'a.zip', [1]);
      expect(await link.backupDelete('a.zip'), isA<Ok<void, LinkFailure>>());
      expect((await link.backupList()).valueOrNull, isEmpty);
    });

    test('delete of a shipped backup succeeds and keeps it', () async {
      await _backUp(link, 'a.zip', [1]);
      final snapshot = link.ship('a.zip');
      expect(await link.backupDelete('a.zip'), isA<Ok<void, LinkFailure>>());
      final entry = (await link.backupList()).valueOrNull!.single;
      expect(entry.state, LinkBackupState.shipped);
      expect(entry.snapshot, snapshot);
      expect(await _restore(link, snapshot: snapshot), [1]);
    });

    test('delete of an unknown name is not_found', () async {
      expect(
        await link.backupDelete('nope.zip'),
        Err<void, LinkFailure>(LinkCallFailed(LinkErrorCode.notFound)),
      );
    });

    test('ship gives each shipped backup its own snapshot id', () async {
      await _backUp(link, 'a.zip', [1]);
      await _backUp(link, 'b.zip', [2]);
      final a = link.ship('a.zip');
      final b = link.ship('b.zip', snapshot: 'snap-hub-7');
      expect(a, isNot(b));
      expect(b, 'snap-hub-7');
      expect(() => link.ship('nope.zip'), throwsStateError);
    });
  });

  group('restore_open', () {
    test('a shipped backup needs the hub: away while away', () async {
      await _backUp(link, 'a.zip', [1, 2]);
      final snapshot = link.ship('a.zip');
      link.away = true;
      expect(
        await link.restoreOpen(snapshot: snapshot),
        Err<LinkRestoreStream, LinkFailure>(LinkCallFailed(LinkErrorCode.away)),
      );
      expect(
        await link.restoreOpen(name: 'a.zip'),
        Err<LinkRestoreStream, LinkFailure>(LinkCallFailed(LinkErrorCode.away)),
      );
      link.away = false;
      expect(await _restore(link, snapshot: snapshot), [1, 2]);
    });

    test('a queued backup restores away from home', () async {
      await _backUp(link, 'a.zip', [3]);
      link.away = true;
      expect(await _restore(link, name: 'a.zip'), [3]);
    });

    test('states its SHA-256 and size', () async {
      await _backUp(link, 'a.zip', [4, 5]);
      final open = (await link.restoreOpen(name: 'a.zip')).valueOrNull!;
      expect(open.sha256, _hex([4, 5]));
      expect(open.size, 2);
    });

    test('an unknown name or snapshot is not_found', () async {
      expect(
        await link.restoreOpen(name: 'nope.zip'),
        Err<LinkRestoreStream, LinkFailure>(
          LinkCallFailed(LinkErrorCode.notFound),
        ),
      );
      expect(
        await link.restoreOpen(snapshot: 'snap-0'),
        Err<LinkRestoreStream, LinkFailure>(
          LinkCallFailed(LinkErrorCode.notFound),
        ),
      );
    });

    test('needs exactly one of name and snapshot', () {
      expect(() => link.restoreOpen(), throwsArgumentError);
      expect(
        () => link.restoreOpen(name: 'a', snapshot: 'b'),
        throwsArgumentError,
      );
    });
  });

  group('the queue cap', () {
    test('backup_space is the cap less the queued bytes', () async {
      link = FakeApsiraBackupLink(clock: FakeClock(_made), queueCap: 10);
      expect(await link.backupSpace(), const Ok<int, LinkFailure>(10));
      await _backUp(link, 'a.zip', [1, 2, 3]);
      expect(await link.backupSpace(), const Ok<int, LinkFailure>(7));
      link.ship('a.zip');
      expect(await link.backupSpace(), const Ok<int, LinkFailure>(10));
    });

    test('a backup past the cap is storage_full, at begin or commit', () async {
      link = FakeApsiraBackupLink(clock: FakeClock(_made), queueCap: 4);
      await _backUp(link, 'a.zip', [1, 2, 3]);
      expect(
        await link.backupBegin('b.zip', size: 2),
        Err<LinkBackupTicket, LinkFailure>(
          LinkCallFailed(LinkErrorCode.storageFull),
        ),
      );
      final ticket = (await link.backupBegin('b.zip')).valueOrNull!;
      await link.backupWrite(ticket, Stream.value([1, 2]));
      expect(
        await link.backupCommit(ticket.ticket, sha256: _hex([1, 2]), size: 2),
        Err<LinkBackupState, LinkFailure>(
          LinkCallFailed(LinkErrorCode.storageFull),
        ),
      );
      expect((await link.backupList()).valueOrNull!.map((e) => e.name), [
        'a.zip',
      ]);
    });

    test('a shipped copy does not count toward the cap', () async {
      link = FakeApsiraBackupLink(clock: FakeClock(_made), queueCap: 4);
      await _backUp(link, 'a.zip', [1, 2, 3]);
      link.ship('a.zip');
      expect(
        await _backUp(link, 'b.zip', [1, 2, 3, 4]),
        const Ok<LinkBackupState, LinkFailure>(LinkBackupState.queued),
      );
    });
  });

  group('backup_rename, within the queue', () {
    test('renames a queued backup', () async {
      await _backUp(link, 'a.tmp', [1]);
      expect(
        await link.backupRename('a.tmp', 'a.zip'),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.renamed),
      );
      expect((await link.backupList()).valueOrNull!.single.name, 'a.zip');
      expect(link.bytesOf('a.zip'), [1]);
    });

    test('a taken target is exists; nothing moves', () async {
      await _backUp(link, 'a.tmp', [1]);
      await _backUp(link, 'a.zip', [2]);
      expect(
        await link.backupRename('a.tmp', 'a.zip'),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.exists),
      );
      expect(link.bytesOf('a.zip'), [2]);
    });

    test('an unknown or shipped source is missing', () async {
      expect(
        await link.backupRename('nope', 'a.zip'),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.missing),
      );
      await _backUp(link, 'b.zip', [1]);
      link.ship('b.zip');
      expect(
        await link.backupRename('b.zip', 'c.zip'),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.missing),
      );
    });
  });

  group('failures', () {
    test('unavailable fails every call', () async {
      link.unavailable = LinkUnavailableReason.notInstalled;
      final failure = LinkUnavailable(LinkUnavailableReason.notInstalled);
      expect((await link.backupSpace()).failureOrNull, failure);
      expect((await link.backupBegin('a')).failureOrNull, failure);
      expect(
        (await link.backupWrite(
          const LinkBackupTicket(ticket: 't', handle: 1),
          Stream.value([1]),
        )).failureOrNull,
        failure,
      );
      expect(
        (await link.backupCommit('t', sha256: 'x', size: 1)).failureOrNull,
        failure,
      );
      expect((await link.backupRename('a', 'b')).failureOrNull, failure);
      expect((await link.backupList()).failureOrNull, failure);
      expect((await link.backupDelete('a')).failureOrNull, failure);
      expect((await link.restoreOpen(name: 'a')).failureOrNull, failure);
    });

    test('a test may set the failure one method answers', () async {
      link.failures[LinkBackupMethod.commit.wire] = LinkCallFailed(
        LinkErrorCode.busy,
      );
      expect(
        await _backUp(link, 'a.zip', [1]),
        Err<LinkBackupState, LinkFailure>(LinkCallFailed(LinkErrorCode.busy)),
      );
      expect((await link.backupList()).valueOrNull, isEmpty);
    });

    test('every call is recorded', () async {
      await _backUp(link, 'a.zip', [1]);
      await link.backupList();
      await link.backupDelete('a.zip');
      expect(link.calls, [
        'backup_begin',
        FakeApsiraBackupLink.writeCall,
        'backup_commit',
        'backup_list',
        'backup_delete',
      ]);
    });
  });
}

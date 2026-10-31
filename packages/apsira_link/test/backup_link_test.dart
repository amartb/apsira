import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/backups.dart';
import 'package:flutter_test/flutter_test.dart';

// The replies of contract app-link.md §5.2 (K2-02b): each Bundle parsed into
// its value; a reply that is not the contract's is unknown_error; a
// malformed `backup_list` entry is dropped.
const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Err<T, LinkFailure> _unknown<T>() =>
    Err(LinkUnavailable(LinkUnavailableReason.unknownError));

Map<String, Object?> _entry({
  Object? name = 'notes-2026-10-31.zip',
  Object? size = 4096,
  Object? madeUtc = '2026-10-31T09:30:00Z',
  Object? state = 'queued',
  Object? snapshot,
}) => {
  'name': name,
  'size': size,
  'made_utc': madeUtc,
  'state': state,
  'snapshot': ?snapshot,
};

void main() {
  test('the method names of contract §5.2', () {
    expect(LinkBackupMethod.values.map((m) => m.wire), [
      'backup_space',
      'backup_begin',
      'backup_commit',
      'backup_rename',
      'backup_list',
      'backup_delete',
      'restore_open',
    ]);
  });

  test('the backup states and their wire names', () {
    expect(LinkBackupState.fromWire('queued'), LinkBackupState.queued);
    expect(LinkBackupState.fromWire('shipped'), LinkBackupState.shipped);
    expect(LinkBackupState.fromWire('sealed'), isNull);
    expect(LinkBackupState.queued.wire, 'queued');
    expect(LinkBackupState.shipped.wire, 'shipped');
  });

  group('backup_space', () {
    test('free_bytes is the queue\'s free bytes', () {
      expect(
        linkFreeBytesFromReply({'free_bytes': 1 << 33}),
        const Ok<int, LinkFailure>(1 << 33),
      );
      expect(
        linkFreeBytesFromReply({'free_bytes': 0}),
        const Ok<int, LinkFailure>(0),
      );
    });

    test('missing, negative or mistyped is unknown_error', () {
      for (final fields in <Map<Object?, Object?>>[
        {},
        {'free_bytes': -1},
        {'free_bytes': '12'},
        {'free_bytes': 1.5},
      ]) {
        expect(
          linkFreeBytesFromReply(fields),
          _unknown<int>(),
          reason: '$fields',
        );
      }
    });
  });

  group('backup_begin', () {
    test('the ticket and the write end', () {
      expect(
        LinkBackupTicket.fromReply({
          'ticket': 't-1',
          'fd': {'stream': 7},
        }),
        const Ok<LinkBackupTicket, LinkFailure>(
          LinkBackupTicket(ticket: 't-1', handle: 7),
        ),
      );
    });

    test('a missing ticket or write end is unknown_error', () {
      for (final fields in <Map<Object?, Object?>>[
        {
          'fd': {'stream': 7},
        },
        {
          'ticket': '',
          'fd': {'stream': 7},
        },
        {
          'ticket': 3,
          'fd': {'stream': 7},
        },
        {'ticket': 't-1'},
        {'ticket': 't-1', 'fd': 7},
        {
          'ticket': 't-1',
          'fd': {'stream': '7'},
        },
      ]) {
        expect(
          LinkBackupTicket.fromReply(fields),
          _unknown<LinkBackupTicket>(),
          reason: '$fields',
        );
      }
    });
  });

  group('backup_commit', () {
    test('state queued', () {
      expect(
        LinkBackupState.fromCommitReply({'state': 'queued'}),
        const Ok<LinkBackupState, LinkFailure>(LinkBackupState.queued),
      );
    });

    test('a missing or unknown state is unknown_error', () {
      for (final fields in <Map<Object?, Object?>>[
        {},
        {'state': 'sealed'},
        {'state': 1},
      ]) {
        expect(
          LinkBackupState.fromCommitReply(fields),
          _unknown<LinkBackupState>(),
          reason: '$fields',
        );
      }
    });
  });

  group('backup_rename', () {
    test('no field is renamed; exists and missing are outcomes', () {
      expect(
        LinkRenameOutcome.fromReply({}),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.renamed),
      );
      expect(
        LinkRenameOutcome.fromReply({'exists': true}),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.exists),
      );
      expect(
        LinkRenameOutcome.fromReply({'missing': true}),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.missing),
      );
      expect(
        LinkRenameOutcome.fromReply({'exists': false, 'missing': false}),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.renamed),
      );
    });

    test('both, or a mistyped flag, is unknown_error', () {
      for (final fields in <Map<Object?, Object?>>[
        {'exists': true, 'missing': true},
        {'exists': 'true'},
        {'missing': 1},
      ]) {
        expect(
          LinkRenameOutcome.fromReply(fields),
          _unknown<LinkRenameOutcome>(),
          reason: '$fields',
        );
      }
    });
  });

  group('backup_list', () {
    test('queued and shipped entries, in APSIRA\'s order', () {
      final reply = LinkBackupEntry.listFromReply({
        'entries': [
          _entry(),
          _entry(
            name: 'notes-2026-10-30.zip',
            size: 0,
            madeUtc: '2026-10-30T09:30:00.250Z',
            state: 'shipped',
            snapshot: 'snap-41',
          ),
        ],
      });
      expect((reply as Ok<List<LinkBackupEntry>, LinkFailure>).value, [
        LinkBackupEntry(
          name: 'notes-2026-10-31.zip',
          sizeBytes: 4096,
          madeUtc: DateTime.utc(2026, 10, 31, 9, 30),
          state: LinkBackupState.queued,
        ),
        LinkBackupEntry(
          name: 'notes-2026-10-30.zip',
          sizeBytes: 0,
          madeUtc: DateTime.utc(2026, 10, 30, 9, 30, 0, 250),
          state: LinkBackupState.shipped,
          snapshot: 'snap-41',
        ),
      ]);
    });

    test('an empty list is no backups', () {
      expect(
        LinkBackupEntry.listFromReply({'entries': <Object?>[]}).valueOrNull,
        isEmpty,
      );
    });

    test('a queued entry has no snapshot even when one is sent', () {
      final entries = LinkBackupEntry.listFromReply({
        'entries': [_entry(snapshot: 'snap-1')],
      }).valueOrNull!;
      expect(entries.single.snapshot, isNull);
    });

    test('an entry with a malformed field is dropped, the rest kept', () {
      final malformed = <Object?>[
        'not a map',
        null,
        _entry(name: null),
        _entry(name: ''),
        _entry(name: 7),
        _entry(size: -1),
        _entry(size: '4096'),
        _entry(size: null),
        _entry(madeUtc: null),
        _entry(madeUtc: 'yesterday'),
        _entry(madeUtc: '2026-10-31T09:30:00'),
        _entry(madeUtc: '2026-10-31T09:30:00+01:00'),
        _entry(madeUtc: 1793352600000),
        _entry(state: 'sealed'),
        _entry(state: null),
        _entry(state: 'shipped'),
        _entry(state: 'shipped', snapshot: ''),
        _entry(state: 'shipped', snapshot: 41),
      ];
      final reply = LinkBackupEntry.listFromReply({
        'entries': [...malformed, _entry(name: 'kept.zip')],
      });
      expect(reply.valueOrNull!.map((e) => e.name), ['kept.zip']);
    });

    test('entries that are not a list is unknown_error', () {
      for (final fields in <Map<Object?, Object?>>[
        {},
        {'entries': 'none'},
        {
          'entries': {'name': 'a'},
        },
      ]) {
        expect(
          LinkBackupEntry.listFromReply(fields),
          _unknown<List<LinkBackupEntry>>(),
          reason: '$fields',
        );
      }
    });

    test('an entry never prints its name', () {
      final entry = LinkBackupEntry(
        name: 'secret-name.zip',
        sizeBytes: 1,
        madeUtc: DateTime.utc(2026),
        state: LinkBackupState.shipped,
        snapshot: 'snap-1',
      );
      expect(entry.toString(), isNot(contains('secret-name')));
    });
  });

  group('restore_open', () {
    test('the read end, the SHA-256 and the size', () {
      expect(
        LinkRestoreSource.fromReply({
          'fd': {'stream': 9},
          'sha256': _sha.toUpperCase(),
          'size': 12,
        }),
        const Ok<LinkRestoreSource, LinkFailure>(
          LinkRestoreSource(handle: 9, sha256: _sha, size: 12),
        ),
      );
    });

    test('a missing or malformed field is unknown_error', () {
      final good = <String, Object?>{
        'fd': {'stream': 9},
        'sha256': _sha,
        'size': 12,
      };
      for (final fields in <Map<Object?, Object?>>[
        {...good}..remove('fd'),
        {...good, 'fd': 9},
        {...good}..remove('sha256'),
        {...good, 'sha256': 'abc'},
        {...good, 'sha256': '${_sha.substring(1)}g'},
        {...good}..remove('size'),
        {...good, 'size': -1},
        {...good, 'size': '12'},
      ]) {
        expect(
          LinkRestoreSource.fromReply(fields),
          _unknown<LinkRestoreSource>(),
          reason: '$fields',
        );
      }
    });

    test('a restore stream never prints its bytes', () {
      final stream = LinkRestoreStream(
        bytes: const Stream.empty(),
        sha256: _sha,
        size: 3,
      );
      expect(stream.toString(), 'LinkRestoreStream(3 bytes)');
    });
  });
}

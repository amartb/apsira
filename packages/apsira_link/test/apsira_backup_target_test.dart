import 'dart:async';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/backup_target.dart';
import 'package:apsira_link/backups.dart';
import 'package:apsira_link/testing.dart';
import 'package:apsira_link/testing/fake_apsira_backup_target.dart';
import 'package:apsira_link/testing/fake_backup_link.dart';
import 'package:apsira_storage/apsira_storage.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';

// ApsiraBackupTarget (K2-01, ruling R-2) maps the unchanged BackupTarget port
// onto the backup calls as contract app-link.md §5.1 states, against the
// §5.2 fake: storage_full is storageFull, not_found on rename and read is
// missing, every other failure folderUnavailable; a shipped backup's delete
// succeeds and deletes nothing (D-008); nothing throws.
const _app = 'com.apsiralabs.relay';
const _folder = BackupFolder(uri: 'apsira:$_app', displayName: 'APSIRA');
final _now = DateTime.utc(2026, 10, 31, 9, 30);
final _payload = List<int>.generate(4096, (i) => i % 251);

const _hello = Ok<LinkHello, LinkFailure>(
  LinkHello(
    version: '1.0',
    versions: ['1.0'],
    appVersion: '0.1.0',
    locked: false,
  ),
);

String _hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

late FakeApsiraLink _link;
late FakeApsiraBackupLink _backups;
late ApsiraBackupTarget _target;

/// A stream that records whether anyone listened to it.
({Stream<List<int>> bytes, bool Function() listened}) _watched(
  List<int> bytes,
) {
  var listened = false;
  final controller = StreamController<List<int>>(
    onListen: () => listened = true,
  );
  controller
    ..add(bytes)
    ..close();
  return (bytes: controller.stream, listened: () => listened);
}

Future<void> _put(String name, [List<int>? bytes]) async {
  final written = await _target.write(
    _folder,
    name,
    Stream.value(bytes ?? _payload),
  );
  expect(written.isOk, isTrue, reason: 'setup write of $name');
}

Future<List<int>> _readAll(Stream<List<int>> stream) async => [
  for (final piece in await stream.toList()) ...piece,
];

Future<Failure> _readFailure(Stream<List<int>> stream) async {
  try {
    await stream.drain<void>();
  } on BackupTargetException catch (error) {
    return error.failure;
  }
  fail('the read did not fail');
}

void main() {
  setUp(() {
    _link = FakeApsiraLink(hello: _hello);
    _backups = FakeApsiraBackupLink(clock: FakeClock(_now));
    _target = ApsiraBackupTarget(
      link: _link,
      backups: _backups,
      appPackage: _app,
      clock: FakeClock(_now),
    );
  });

  test("the folder is APSIRA's virtual apsira:<package>", () {
    expect(_target.folder, _folder);
  });

  group('pickFolder', () {
    test('a good hello is the folder, with no picker', () async {
      expect(await _target.pickFolder(), _folder);
      expect(_link.helloCalls, 1);
    });

    test('APSIRA unavailable is null', () async {
      _link.helloResult = Err(
        LinkUnavailable(LinkUnavailableReason.notInstalled),
      );
      expect(await _target.pickFolder(), isNull);
    });

    test('a call error is null', () async {
      _link.helloResult = Err(LinkCallFailed(LinkErrorCode.busy));
      expect(await _target.pickFolder(), isNull);
    });
  });

  group('hasAccess', () {
    test('our folder and a good hello', () async {
      expect(await _target.hasAccess(_folder), isTrue);
    });

    test('APSIRA refusing the app is no access', () async {
      _link.helloResult = Err(
        LinkUnavailable(LinkUnavailableReason.notAuthorised),
      );
      expect(await _target.hasAccess(_folder), isFalse);
    });

    test('a folder that is not ours is no access, APSIRA not asked', () async {
      for (final other in const [
        BackupFolder(
          uri: 'apsira:com.apsiralabs.lyceum',
          displayName: 'APSIRA',
        ),
        BackupFolder(uri: 'content://tree/backups', displayName: 'Backups'),
      ]) {
        expect(await _target.hasAccess(other), isFalse);
      }
      expect(_link.helloCalls, 0);
    });
  });

  group('freeBytes', () {
    test("is backup_space, the queue's free bytes", () async {
      _backups.queueCap = 10000;
      await _put('a.zip');
      expect(await _target.freeBytes(_folder), 10000 - _payload.length);
    });

    test('any failure is null', () async {
      _backups.failures['backup_space'] = LinkCallFailed(LinkErrorCode.busy);
      expect(await _target.freeBytes(_folder), isNull);
      _backups.unavailable = LinkUnavailableReason.noAnswer;
      expect(await _target.freeBytes(_folder), isNull);
    });

    test('a folder that is not ours is null', () async {
      const other = BackupFolder(uri: 'apsira:x', displayName: 'APSIRA');
      expect(await _target.freeBytes(other), isNull);
      expect(_backups.calls, isEmpty);
    });
  });

  group('write', () {
    test('begin, write, commit with the plain SHA-256: queued', () async {
      final written = await _target.write(
        _folder,
        'relay-1.zip',
        Stream.fromIterable([_payload.sublist(0, 100), _payload.sublist(100)]),
      );
      final file = written.valueOrNull!;
      expect(file.name, 'relay-1.zip');
      expect(file.sizeBytes, _payload.length);
      expect(file.modifiedUtc, _now);
      expect(_backups.calls, [
        'backup_list',
        'backup_begin',
        FakeApsiraBackupLink.writeCall,
        'backup_commit',
      ]);
      expect(_hex(_backups.bytesOf('relay-1.zip')!), _hex(_payload));
      final entry = (await _backups.backupList()).valueOrNull!.single;
      expect(entry.state, LinkBackupState.queued);
    });

    for (final shipped in [false, true]) {
      test('a taken name (${shipped ? 'shipped' : 'queued'}) is exists, '
          'the bytes not listened to', () async {
        await _put('a.zip');
        if (shipped) _backups.ship('a.zip');
        _backups.calls.clear();
        final watched = _watched([1, 2, 3]);
        final written = await _target.write(_folder, 'a.zip', watched.bytes);
        expect(written.failureOrNull, BackupTarget.exists);
        expect(watched.listened(), isFalse);
        expect(_backups.calls, ['backup_list']);
      });
    }

    test(
      'a folder that is not ours: folderUnavailable, nothing asked',
      () async {
        final watched = _watched([1]);
        final written = await _target.write(
          const BackupFolder(uri: 'content://tree/x', displayName: 'x'),
          'a.zip',
          watched.bytes,
        );
        expect(written.failureOrNull, BackupTarget.folderUnavailable);
        expect(watched.listened(), isFalse);
        expect(_backups.calls, isEmpty);
      },
    );

    test('APSIRA unavailable before the write: folderUnavailable, '
        'the bytes not listened to', () async {
      _backups.unavailable = LinkUnavailableReason.notInstalled;
      final watched = _watched([1]);
      final written = await _target.write(_folder, 'a.zip', watched.bytes);
      expect(written.failureOrNull, BackupTarget.folderUnavailable);
      expect(watched.listened(), isFalse);
    });

    test('a full queue is storageFull', () async {
      _backups.queueCap = 100;
      final written = await _target.write(
        _folder,
        'a.zip',
        Stream.value(_payload),
      );
      expect(written.failureOrNull, BackupTarget.storageFull);
      expect(_backups.bytesOf('a.zip'), isNull);
    });

    for (final (call, failure) in [
      ('backup_begin', LinkCallFailed(LinkErrorCode.busy)),
      (
        FakeApsiraBackupLink.writeCall,
        LinkUnavailable(LinkUnavailableReason.noAnswer),
      ),
      ('backup_commit', LinkCallFailed(LinkErrorCode.checksumMismatch)),
      ('backup_commit', LinkCallFailed(LinkErrorCode.away)),
    ]) {
      test('$failure at $call is folderUnavailable', () async {
        _backups.failures[call] = failure;
        final written = await _target.write(
          _folder,
          'a.zip',
          Stream.value(_payload),
        );
        expect(written.failureOrNull, BackupTarget.folderUnavailable);
      });
    }

    test(
      "an error from the app's own bytes is rethrown, as the port says",
      () async {
        final bytes = Stream<List<int>>.error(const FormatException('zip'));
        await expectLater(
          _target.write(_folder, 'a.zip', bytes),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('rename', () {
    test('a queued backup moves: the file under its new name', () async {
      await _put('a.zip.tmp');
      final renamed = await _target.rename(_folder, 'a.zip.tmp', 'a.zip');
      final file = renamed.valueOrNull!;
      expect(file.name, 'a.zip');
      expect(file.sizeBytes, _payload.length);
      expect(file.modifiedUtc, _now);
      expect(_backups.bytesOf('a.zip'), isNotNull);
    });

    test('a taken target is exists', () async {
      await _put('a.zip.tmp');
      await _put('a.zip');
      expect(
        (await _target.rename(_folder, 'a.zip.tmp', 'a.zip')).failureOrNull,
        BackupTarget.exists,
      );
    });

    test('no queued backup of that name is missing', () async {
      expect(
        (await _target.rename(_folder, 'gone.tmp', 'gone')).failureOrNull,
        BackupTarget.missing,
      );
      await _put('shipped.tmp');
      _backups.ship('shipped.tmp');
      expect(
        (await _target.rename(_folder, 'shipped.tmp', 'shipped')).failureOrNull,
        BackupTarget.missing,
      );
    });

    test('not_found is missing', () async {
      _backups.failures['backup_rename'] = LinkCallFailed(
        LinkErrorCode.notFound,
      );
      expect(
        (await _target.rename(_folder, 'a', 'b')).failureOrNull,
        BackupTarget.missing,
      );
    });

    test('any other failure is folderUnavailable', () async {
      _backups.failures['backup_rename'] = LinkCallFailed(LinkErrorCode.busy);
      expect(
        (await _target.rename(_folder, 'a', 'b')).failureOrNull,
        BackupTarget.folderUnavailable,
      );
      _backups.failures.clear();
      await _put('c.tmp');
      _backups.failures['backup_list'] = LinkCallFailed(LinkErrorCode.busy);
      expect(
        (await _target.rename(_folder, 'c.tmp', 'c')).failureOrNull,
        BackupTarget.folderUnavailable,
      );
      expect(
        (await _target.rename(
          const BackupFolder(uri: 'apsira:x', displayName: 'APSIRA'),
          'a',
          'b',
        )).failureOrNull,
        BackupTarget.folderUnavailable,
      );
    });
  });

  group('list', () {
    test('queued and shipped, by name, with when each was made', () async {
      await _put('a.zip');
      await _put('b.zip', [1, 2, 3]);
      _backups.ship('a.zip');
      final files = (await _target.list(_folder)).valueOrNull!;
      expect([for (final f in files) f.name], ['a.zip', 'b.zip']);
      expect([for (final f in files) f.sizeBytes], [_payload.length, 3]);
      expect(files.every((f) => f.modifiedUtc == _now), isTrue);
    });

    test('a failure is folderUnavailable', () async {
      _backups.unavailable = LinkUnavailableReason.notTrusted;
      expect(
        (await _target.list(_folder)).failureOrNull,
        BackupTarget.folderUnavailable,
      );
    });
  });

  group('read', () {
    test('restore_open by name streams the plain bytes', () async {
      await _put('a.zip');
      expect(await _readAll(_target.read(_folder, 'a.zip')), _payload);
      _backups.ship('a.zip');
      expect(await _readAll(_target.read(_folder, 'a.zip')), _payload);
    });

    test('no backup of that name is missing', () async {
      expect(
        await _readFailure(_target.read(_folder, 'gone.zip')),
        BackupTarget.missing,
      );
    });

    test('a shipped backup away from home is folderUnavailable', () async {
      await _put('a.zip');
      _backups
        ..ship('a.zip')
        ..away = true;
      expect(
        await _readFailure(_target.read(_folder, 'a.zip')),
        BackupTarget.folderUnavailable,
      );
    });

    test(
      'APSIRA unavailable, or a folder not ours, is folderUnavailable',
      () async {
        expect(
          await _readFailure(
            _target.read(
              const BackupFolder(uri: 'apsira:x', displayName: 'APSIRA'),
              'a.zip',
            ),
          ),
          BackupTarget.folderUnavailable,
        );
        _backups.unavailable = LinkUnavailableReason.noAnswer;
        expect(
          await _readFailure(_target.read(_folder, 'a.zip')),
          BackupTarget.folderUnavailable,
        );
      },
    );

    test(
      'a failure part-way ends the stream with BackupTargetException',
      () async {
        final target = ApsiraBackupTarget(
          link: _link,
          backups: _BrokenRestore(),
          appPackage: _app,
          clock: FakeClock(_now),
        );
        final pieces = <List<int>>[];
        Object? error;
        try {
          await for (final piece in target.read(_folder, 'a.zip')) {
            pieces.add(piece);
          }
        } on Object catch (e) {
          error = e;
        }
        expect(pieces, [
          [1, 2],
        ]);
        expect(error, isA<BackupTargetException>());
        expect(
          (error! as BackupTargetException).failure,
          BackupTarget.folderUnavailable,
        );
      },
    );
  });

  group('delete', () {
    test('a queued copy is removed', () async {
      await _put('a.zip');
      expect((await _target.delete(_folder, 'a.zip')).isOk, isTrue);
      expect(_backups.bytesOf('a.zip'), isNull);
    });

    test('a shipped backup succeeds and is not deleted (D-008)', () async {
      await _put('a.zip');
      _backups.ship('a.zip');
      expect((await _target.delete(_folder, 'a.zip')).isOk, isTrue);
      expect(_backups.bytesOf('a.zip'), _payload);
      expect((await _target.list(_folder)).valueOrNull!.single.name, 'a.zip');
    });

    test('a name that is not there is already deleted', () async {
      expect((await _target.delete(_folder, 'gone.zip')).isOk, isTrue);
    });

    test('any other failure is folderUnavailable', () async {
      _backups.failures['backup_delete'] = LinkCallFailed(LinkErrorCode.busy);
      expect(
        (await _target.delete(_folder, 'a.zip')).failureOrNull,
        BackupTarget.folderUnavailable,
      );
      _backups.failures.clear();
      expect(
        (await _target.delete(
          const BackupFolder(uri: 'apsira:x', displayName: 'APSIRA'),
          'a.zip',
        )).failureOrNull,
        BackupTarget.folderUnavailable,
      );
    });
  });

  group('every failure row', () {
    final rows = <(LinkFailure, Failure)>[
      for (final reason in LinkUnavailableReason.values)
        (LinkUnavailable(reason), BackupTarget.folderUnavailable),
      for (final code in LinkErrorCode.values)
        (
          LinkCallFailed(code),
          code == LinkErrorCode.storageFull
              ? BackupTarget.storageFull
              : BackupTarget.folderUnavailable,
        ),
    ];
    for (final (link, port) in rows) {
      test('$link in list is ${port.code}', () async {
        _backups.failures['backup_list'] = link;
        expect((await _target.list(_folder)).failureOrNull, port);
      });
    }
  });

  group('FakeApsiraBackupTarget', () {
    test('hands a backup over to its fake queue and reads it back', () async {
      final fake = FakeApsiraBackupTarget(appPackage: _app);
      expect(await fake.pickFolder(), fake.folder);
      expect(fake.folder, _folder);
      final written = await fake.write(
        fake.folder,
        'a.zip',
        Stream.value(_payload),
      );
      expect(written.isOk, isTrue);
      expect(fake.backups.bytesOf('a.zip'), _payload);
      expect(await _readAll(fake.read(fake.folder, 'a.zip')), _payload);
    });

    test('its link can be made unavailable', () async {
      final fake = FakeApsiraBackupTarget(appPackage: _app);
      fake.link.helloResult = Err(
        LinkUnavailable(LinkUnavailableReason.notInstalled),
      );
      expect(await fake.pickFolder(), isNull);
    });
  });
}

/// A link whose restore stream fails after its first piece, as a read end
/// that closes early does; every other call is not used.
final class _BrokenRestore implements ApsiraBackupLink {
  @override
  Future<Result<LinkRestoreStream, LinkFailure>> restoreOpen({
    String? name,
    String? snapshot,
  }) async => Ok(
    LinkRestoreStream(
      bytes:
          Stream.fromIterable([
            [1, 2],
          ]).followedBy(
            Stream.error(
              LinkStreamException(
                LinkCallFailed(LinkErrorCode.checksumMismatch),
              ),
            ),
          ),
      sha256: _hex([1, 2]),
      size: 2,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

extension<T> on Stream<T> {
  Stream<T> followedBy(Stream<T> next) async* {
    yield* this;
    yield* next;
  }
}

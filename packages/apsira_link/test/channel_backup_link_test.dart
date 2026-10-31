import 'dart:async';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/backups.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ChannelApsiraBackupLink (K2-02b) over a mocked `apsira_link/link`: each of
// contract app-link.md §5.2's seven methods sends its extras and parses its
// Bundle, every §8 error is its LinkFailure, and no channel failure throws.
const _channel = MethodChannel(ChannelApsiraLink.channelName);

void _answer(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

Map<Object?, Object?> _args(MethodCall call) =>
    call.arguments as Map<Object?, Object?>;

Map<Object?, Object?> _fields(Map<Object?, Object?> fields) => {
  'fields': fields,
  'devUnverified': false,
};

String _hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// The contract §8 codes: what an `{error}` reply of each becomes.
final _errors = <String, LinkFailure>{
  'not_authorised': LinkUnavailable(LinkUnavailableReason.notAuthorised),
  'unsupported_version': LinkUnavailable(
    LinkUnavailableReason.unsupportedVersion,
  ),
  'busy': LinkCallFailed(LinkErrorCode.busy),
  'away': LinkCallFailed(LinkErrorCode.away),
  'storage_full': LinkCallFailed(LinkErrorCode.storageFull),
  'not_found': LinkCallFailed(LinkErrorCode.notFound),
  'not_allowed': LinkCallFailed(LinkErrorCode.notAllowed),
  'checksum_mismatch': LinkCallFailed(LinkErrorCode.checksumMismatch),
  'a_code_from_2030': LinkUnavailable(LinkUnavailableReason.unknownError),
};

/// Each control method, called once: its failure, if any.
final _calls = <String, Future<LinkFailure?> Function(ApsiraBackupLink)>{
  'backup_space': (l) async => (await l.backupSpace()).failureOrNull,
  'backup_begin': (l) async =>
      (await l.backupBegin('a.zip', size: 3)).failureOrNull,
  'backup_commit': (l) async =>
      (await l.backupCommit('t-1', sha256: 'ab', size: 3)).failureOrNull,
  'backup_rename': (l) async =>
      (await l.backupRename('a.tmp', 'a.zip')).failureOrNull,
  'backup_list': (l) async => (await l.backupList()).failureOrNull,
  'backup_delete': (l) async => (await l.backupDelete('a.zip')).failureOrNull,
  'restore_open': (l) async =>
      (await l.restoreOpen(name: 'a.zip')).failureOrNull,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const link = ChannelApsiraBackupLink();

  tearDown(() => _answer(null));

  group('each method sends contract §5.2\'s extras', () {
    late List<MethodCall> sent;

    setUp(() {
      sent = [];
      _answer((call) async {
        sent.add(call);
        return _fields({});
      });
    });

    Future<Map<Object?, Object?>> only(Future<Object?> Function() run) async {
      await run();
      expect(sent.single.method, 'call');
      expect(_args(sent.single)['version'], linkVersions.last);
      return _args(sent.single);
    }

    test('backup_space: none', () async {
      final args = await only(link.backupSpace);
      expect(args['method'], 'backup_space');
      expect(args['extras'], isEmpty);
    });

    test('backup_begin: name and size, size only when known', () async {
      final args = await only(() => link.backupBegin('a.zip', size: 4096));
      expect(args['method'], 'backup_begin');
      expect(args['extras'], {'name': 'a.zip', 'size': 4096});
      sent.clear();
      final unknown = await only(() => link.backupBegin('b.zip'));
      expect(unknown['extras'], {'name': 'b.zip'});
    });

    test('backup_commit: ticket, sha256 and size', () async {
      final args = await only(
        () => link.backupCommit('t-1', sha256: 'abc', size: 3),
      );
      expect(args['method'], 'backup_commit');
      expect(args['extras'], {'ticket': 't-1', 'sha256': 'abc', 'size': 3});
    });

    test('backup_rename: from and to', () async {
      final args = await only(() => link.backupRename('a.tmp', 'a.zip'));
      expect(args['method'], 'backup_rename');
      expect(args['extras'], {'from': 'a.tmp', 'to': 'a.zip'});
    });

    test('backup_list: none', () async {
      final args = await only(link.backupList);
      expect(args['method'], 'backup_list');
      expect(args['extras'], isEmpty);
    });

    test('backup_delete: name', () async {
      final args = await only(() => link.backupDelete('a.zip'));
      expect(args['method'], 'backup_delete');
      expect(args['extras'], {'name': 'a.zip'});
    });

    test('restore_open: name or snapshot', () async {
      final byName = await only(() => link.restoreOpen(name: 'a.zip'));
      expect(byName['method'], 'restore_open');
      expect(byName['extras'], {'name': 'a.zip'});
      sent.clear();
      final bySnapshot = await only(() => link.restoreOpen(snapshot: 's-1'));
      expect(bySnapshot['extras'], {'snapshot': 's-1'});
    });
  });

  test('restore_open needs exactly one of name and snapshot', () {
    expect(() => link.restoreOpen(), throwsArgumentError);
    expect(
      () => link.restoreOpen(name: 'a.zip', snapshot: 's-1'),
      throwsArgumentError,
    );
  });

  group('each method parses its Bundle', () {
    test('backup_space', () async {
      _answer((call) async => _fields({'free_bytes': 1 << 32}));
      expect(await link.backupSpace(), const Ok<int, LinkFailure>(1 << 32));
    });

    test('backup_begin', () async {
      _answer(
        (call) async => _fields({
          'ticket': 't-9',
          'fd': {'stream': 4},
        }),
      );
      expect(
        await link.backupBegin('a.zip'),
        const Ok<LinkBackupTicket, LinkFailure>(
          LinkBackupTicket(ticket: 't-9', handle: 4),
        ),
      );
    });

    test('backup_commit', () async {
      _answer((call) async => _fields({'state': 'queued'}));
      expect(
        await link.backupCommit('t-9', sha256: 'ab', size: 1),
        const Ok<LinkBackupState, LinkFailure>(LinkBackupState.queued),
      );
    });

    test('backup_rename', () async {
      _answer((call) async => _fields({}));
      expect(
        await link.backupRename('a', 'b'),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.renamed),
      );
      _answer((call) async => _fields({'exists': true}));
      expect(
        await link.backupRename('a', 'b'),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.exists),
      );
      _answer((call) async => _fields({'missing': true}));
      expect(
        await link.backupRename('a', 'b'),
        const Ok<LinkRenameOutcome, LinkFailure>(LinkRenameOutcome.missing),
      );
    });

    test('backup_list, a malformed entry dropped', () async {
      _answer(
        (call) async => _fields({
          'entries': [
            {
              'name': 'a.zip',
              'size': 3,
              'made_utc': '2026-10-31T10:00:00Z',
              'state': 'shipped',
              'snapshot': 'snap-2',
            },
            {'name': 'b.zip', 'size': 'x'},
          ],
        }),
      );
      expect((await link.backupList()).valueOrNull, [
        LinkBackupEntry(
          name: 'a.zip',
          sizeBytes: 3,
          madeUtc: DateTime.utc(2026, 10, 31, 10),
          state: LinkBackupState.shipped,
          snapshot: 'snap-2',
        ),
      ]);
    });

    test('backup_delete', () async {
      _answer((call) async => _fields({}));
      expect(await link.backupDelete('a.zip'), isA<Ok<void, LinkFailure>>());
    });
  });

  group('every §8 error is its LinkFailure, for every method', () {
    for (final MapEntry(key: method, value: call) in _calls.entries) {
      test(method, () async {
        for (final MapEntry(key: code, value: failure) in _errors.entries) {
          _answer((call) async => {'error': code});
          expect(await call(link), failure, reason: code);
        }
        _answer((call) async => {'unavailable': 'not_installed'});
        expect(
          await call(link),
          LinkUnavailable(LinkUnavailableReason.notInstalled),
        );
      });
    }
  });

  group('no channel failure throws: each is unavailable', () {
    for (final MapEntry(key: method, value: call) in _calls.entries) {
      test(method, () async {
        final noAnswer = LinkUnavailable(LinkUnavailableReason.noAnswer);
        _answer((call) async => throw PlatformException(code: 'boom'));
        expect(await call(link), noAnswer);
        _answer((call) async => throw MissingPluginException());
        expect(await call(link), noAnswer);
        _answer(null);
        expect(await call(link), noAnswer);
        final unknown = LinkUnavailable(LinkUnavailableReason.unknownError);
        _answer((call) async => 'nonsense');
        expect(await call(link), unknown);
        _answer((call) async => _fields({'what': 'ever'}));
        if (method != 'backup_rename' && method != 'backup_delete') {
          expect(await call(link), unknown);
        }
      });
    }

    testWidgets('a silent APSIRA is noAnswer at the deadline', (tester) async {
      _answer((call) => Completer<Object?>().future);
      LinkFailure? failure;
      unawaited(link.backupList().then((r) => failure = r.failureOrNull));
      await tester.pump(const Duration(seconds: 4));
      expect(failure, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(failure, LinkUnavailable(LinkUnavailableReason.noAnswer));
    });
  });

  group('the byte streams', () {
    test('backupWrite writes on the ticket\'s handle and reports '
        'the SHA-256 and size', () async {
      final written = BytesBuilder();
      final methods = <String>[];
      _answer((call) async {
        methods.add(call.method);
        expect(_args(call)['handle'], 4);
        if (call.method == 'write') {
          written.add(_args(call)['bytes']! as Uint8List);
        }
        return <Object?, Object?>{};
      });
      final payload = List<int>.generate(5000, (i) => i & 0xff);
      final reply = await link.backupWrite(
        const LinkBackupTicket(ticket: 't-1', handle: 4),
        Stream.value(payload),
      );
      expect(methods, ['write', 'close']);
      expect(written.takeBytes(), payload);
      expect(
        reply,
        Ok<LinkWritten, LinkFailure>((sha256: _hex(payload), size: 5000)),
      );
    });

    test('a write that fails is its failure, never a throw', () async {
      _answer((call) async => throw PlatformException(code: 'io'));
      expect(
        await link.backupWrite(
          const LinkBackupTicket(ticket: 't-1', handle: 4),
          Stream.value([1, 2, 3]),
        ),
        Err<LinkWritten, LinkFailure>(
          LinkUnavailable(LinkUnavailableReason.noAnswer),
        ),
      );
    });

    test('restoreOpen streams the read end, checked', () async {
      final served = Uint8List.fromList([5, 6, 7]);
      var read = false;
      _answer((call) async {
        switch (call.method) {
          case 'call':
            return _fields({
              'fd': {'stream': 11},
              'sha256': _hex(served),
              'size': served.length,
            });
          case 'read':
            expect(_args(call)['handle'], 11);
            if (read) return {'end': true};
            read = true;
            return {'bytes': served};
          default:
            return <Object?, Object?>{};
        }
      });
      final open = (await link.restoreOpen(snapshot: 'snap-2')).valueOrNull!;
      expect(open.sha256, _hex(served));
      expect(open.size, 3);
      expect(await open.bytes.expand((b) => b).toList(), served);
    });

    test('a malformed reply holding a stream cancels it', () async {
      final methods = <String>[];
      final handles = <Object?>[];
      Future<Object?> answer(MethodCall call, Map<Object?, Object?> fields) {
        methods.add(call.method);
        if (call.method == 'call') return Future.value(_fields(fields));
        handles.add(_args(call)['handle']);
        return Future.value(<Object?, Object?>{});
      }

      _answer(
        (call) => answer(call, {
          'fd': {'stream': 5},
        }),
      );
      expect(
        await link.backupBegin('a.zip'),
        Err<LinkBackupTicket, LinkFailure>(
          LinkUnavailable(LinkUnavailableReason.unknownError),
        ),
      );
      _answer(
        (call) => answer(call, {
          'fd': {'stream': 6},
          'size': 3,
        }),
      );
      expect(
        await link.restoreOpen(name: 'a.zip'),
        Err<LinkRestoreStream, LinkFailure>(
          LinkUnavailable(LinkUnavailableReason.unknownError),
        ),
      );
      expect(methods, ['call', 'cancel', 'call', 'cancel']);
      expect(handles, [5, 6]);
    });
  });
}

import 'dart:async';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ChannelApsiraArchiveLink (K2-02c) over a mocked `apsira_link/link`
// channel: each method's extras (atrium-offload.md §3), archive_put's
// stream checked against the item (cancelled on a mismatch, never closed)
// and read back with archive_state, and AO §4's errors.
const _channel = MethodChannel(ChannelApsiraLink.channelName);
const _link = ChannelApsiraArchiveLink();

Uint8List _bytes(int length, {int seed = 0}) =>
    Uint8List.fromList(List.generate(length, (i) => (i * 7 + seed) & 0xff));

String _hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

LinkArchiveItem _itemOf(List<int> bytes, {int? size, String? sha256}) =>
    LinkArchiveItem(
      itemId: 'doc-1',
      displayName: 'Lease.pdf',
      mimeType: 'application/pdf',
      size: size ?? bytes.length,
      sha256: sha256 ?? _hex(bytes),
      keptUtc: DateTime.utc(2026, 10, 31),
    );

Map<String, Object?> _fields(Map<String, Object?> fields) => {
  'fields': fields,
  'devUnverified': false,
};

/// A Kotlin stand-in: answers each control call by its `method` from
/// [replies], serves [served] to reads, and records every call.
class _Apsira {
  _Apsira(this.replies, {this.served});

  final Map<String, Object?> replies;
  final Uint8List? served;
  final calls = <MethodCall>[];
  final written = BytesBuilder();
  var _at = 0;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    final args = call.arguments as Map<Object?, Object?>;
    switch (call.method) {
      case 'call':
        return replies[args['method']];
      case 'write':
        written.add(args['bytes']! as Uint8List);
        return <Object?, Object?>{};
      case 'read':
        final all = served!;
        if (_at >= all.length) return {'end': true};
        final end = (_at + (args['max']! as int)).clamp(0, all.length);
        final chunk = Uint8List.sublistView(all, _at, end);
        _at = end;
        return {'bytes': chunk};
      default:
        return <Object?, Object?>{};
    }
  }

  List<String> get methods => [
    for (final c in calls)
      c.method == 'call'
          ? (c.arguments as Map<Object?, Object?>)['method']! as String
          : c.method,
  ];

  Map<Object?, Object?> extrasOf(String method) =>
      (calls
              .map((c) => c.arguments as Map<Object?, Object?>)
              .firstWhere((a) => a['method'] == method)['extras']
          as Map<Object?, Object?>?) ??
      const {};

  Map<Object?, Object?> argsOf(String method) =>
      calls.firstWhere((c) => c.method == method).arguments
          as Map<Object?, Object?>;
}

_Apsira _serve(Map<String, Object?> replies, {Uint8List? served}) {
  final apsira = _Apsira(replies, served: served);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, apsira.handle);
  return apsira;
}

Map<String, Object?> _error(String code) => {'error': code};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  group('archivePut', () {
    final putReply = _fields({
      'fd': {'stream': 4},
    });

    test('sends the metadata, writes and closes the stream, then answers '
        'archive_state', () async {
      final bytes = _bytes(70 * 1024);
      final item = _itemOf(bytes);
      final apsira = _serve({
        'archive_put': putReply,
        'archive_state': _fields({'state': 'stored'}),
      });
      final result = await _link.archivePut(
        item,
        Stream.fromIterable([bytes.sublist(0, 1000), bytes.sublist(1000)]),
      );
      expect(
        result,
        const Ok<LinkArchiveState, LinkFailure>(LinkArchiveState.stored),
      );
      expect(apsira.extrasOf('archive_put'), item.extras);
      expect(apsira.methods, [
        'archive_put',
        'write',
        'write',
        'close',
        'archive_state',
      ]);
      expect(apsira.argsOf('close'), {'handle': 4});
      expect(apsira.extrasOf('archive_state'), {'item_id': 'doc-1'});
      expect(apsira.written.takeBytes(), bytes);
    });

    test(
      'a stream with another SHA-256 is cancelled: checksum_mismatch',
      () async {
        final bytes = _bytes(100);
        final apsira = _serve({
          'archive_put': putReply,
          'archive_state': _fields({'state': 'stored'}),
        });
        final result = await _link.archivePut(
          _itemOf(bytes, sha256: _hex(_bytes(100, seed: 1))),
          Stream.value(bytes),
        );
        expect(
          result.failureOrNull,
          LinkCallFailed(LinkErrorCode.checksumMismatch),
        );
        expect(apsira.methods, ['archive_put', 'cancel']);
        expect(apsira.argsOf('cancel'), {'handle': 4});
      },
    );

    test('a short stream is cancelled: checksum_mismatch', () async {
      final bytes = _bytes(100);
      final apsira = _serve({'archive_put': putReply});
      final result = await _link.archivePut(
        _itemOf(bytes, size: 101),
        Stream.value(bytes),
      );
      expect(
        result.failureOrNull,
        LinkCallFailed(LinkErrorCode.checksumMismatch),
      );
      expect(apsira.methods, ['archive_put', 'cancel']);
    });

    test('a long stream is cancelled once it passes the size', () async {
      final bytes = _bytes(70 * 1024);
      final apsira = _serve({'archive_put': putReply});
      final result = await _link.archivePut(
        _itemOf(bytes),
        Stream.fromIterable([bytes, _bytes(10), _bytes(10)]),
      );
      expect(
        result.failureOrNull,
        LinkCallFailed(LinkErrorCode.checksumMismatch),
      );
      expect(apsira.methods, ['archive_put', 'write', 'cancel']);
      expect(apsira.methods, isNot(contains('close')));
    });

    test('a failing source is cancelled and is its failure', () async {
      final apsira = _serve({'archive_put': putReply});
      final result = await _link.archivePut(
        _itemOf(_bytes(10)),
        Stream.error(StateError('disk')),
      );
      expect(
        result.failureOrNull,
        LinkUnavailable(LinkUnavailableReason.unknownError),
      );
      expect(apsira.methods, ['archive_put', 'cancel']);
    });

    test('a refused put sends no stream and is its AO §4 failure', () async {
      for (final (code, failure) in [
        ('away', LinkCallFailed(LinkErrorCode.away)),
        ('store_full', LinkCallFailed(LinkErrorCode.storeFull)),
        (
          'not_authorised',
          LinkUnavailable(LinkUnavailableReason.notAuthorised),
        ),
      ]) {
        var listened = false;
        final source = StreamController<List<int>>(
          onListen: () => listened = true,
        );
        final apsira = _serve({'archive_put': _error(code)});
        final result = await _link.archivePut(
          _itemOf(_bytes(3)),
          source.stream,
        );
        expect(result.failureOrNull, failure, reason: code);
        expect(apsira.methods, ['archive_put'], reason: code);
        expect(listened, isFalse, reason: code);
        unawaited(source.close());
      }
    });

    test('a put reply without a write end is unknownError', () async {
      final apsira = _serve({'archive_put': _fields({})});
      final result = await _link.archivePut(
        _itemOf(_bytes(3)),
        Stream.value(_bytes(3)),
      );
      expect(
        result.failureOrNull,
        LinkUnavailable(LinkUnavailableReason.unknownError),
      );
      expect(apsira.methods, ['archive_put']);
    });

    test('a failed read-back is that failure', () async {
      final bytes = _bytes(5);
      _serve({'archive_put': putReply, 'archive_state': _error('away')});
      final result = await _link.archivePut(
        _itemOf(bytes),
        Stream.value(bytes),
      );
      expect(result.failureOrNull, LinkCallFailed(LinkErrorCode.away));
    });
  });

  group('archiveState', () {
    test('sends item_id and answers the state', () async {
      final apsira = _serve({
        'archive_state': _fields({'state': 'secured'}),
      });
      expect(
        await _link.archiveState('doc-9'),
        const Ok<LinkArchiveState, LinkFailure>(LinkArchiveState.secured),
      );
      expect(apsira.extrasOf('archive_state'), {'item_id': 'doc-9'});
    });

    test('APSIRA missing is unavailable, never a throw', () async {
      _serve({
        'archive_state': {'unavailable': 'not_installed'},
      });
      expect(
        (await _link.archiveState('doc-9')).failureOrNull,
        LinkUnavailable(LinkUnavailableReason.notInstalled),
      );
    });

    test('a platform error is noAnswer', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _channel,
            (call) async => throw PlatformException(code: 'x'),
          );
      expect(
        (await _link.archiveState('doc-9')).failureOrNull,
        LinkUnavailable(LinkUnavailableReason.noAnswer),
      );
    });
  });

  group('archiveList', () {
    final listReply = _fields({
      'items': [
        {
          'item_id': 'doc-1',
          'display_name': 'Lease.pdf',
          'mime_type': 'application/pdf',
          'size': 3,
          'sha256': _hex(_bytes(3)),
          'kept_utc': '2026-10-31T00:00:00.000Z',
          'state': 'secured',
        },
      ],
    });

    test('without since sends no extras and parses the items', () async {
      final apsira = _serve({'archive_list': listReply});
      final list = await _link.archiveList();
      expect(apsira.extrasOf('archive_list'), isEmpty);
      expect(list.valueOrNull, [
        LinkArchiveEntry(
          item: _itemOf(_bytes(3)),
          state: LinkArchiveState.secured,
        ),
      ]);
    });

    test('since is sent in UTC', () async {
      final apsira = _serve({'archive_list': listReply});
      await _link.archiveList(since: DateTime.utc(2026, 10, 1, 8).toLocal());
      expect(apsira.extrasOf('archive_list'), {
        'since': '2026-10-01T08:00:00.000Z',
      });
    });
  });

  group('archiveFetch', () {
    test('sends item_id and reads the stream to its checked end', () async {
      final bytes = _bytes(70 * 1024);
      final apsira = _serve({
        'archive_fetch': _fields({
          'fd': {'stream': 9},
          'sha256': _hex(bytes),
          'size': bytes.length,
        }),
      }, served: bytes);
      final fetch = (await _link.archiveFetch('doc-1')).valueOrNull!;
      expect(apsira.extrasOf('archive_fetch'), {'item_id': 'doc-1'});
      expect(fetch.size, bytes.length);
      expect(fetch.sha256, _hex(bytes));
      final read = await fetch.bytes.expand((b) => b).toList();
      expect(read, bytes);
      expect(apsira.methods.last, 'close');
    });

    test('an altered stream ends with checksum_mismatch', () async {
      final bytes = _bytes(10);
      _serve({
        'archive_fetch': _fields({
          'fd': {'stream': 9},
          'sha256': _hex(_bytes(10, seed: 3)),
          'size': 10,
        }),
      }, served: bytes);
      final fetch = (await _link.archiveFetch('doc-1')).valueOrNull!;
      await expectLater(
        fetch.bytes,
        emitsThrough(
          emitsError(
            LinkStreamException(LinkCallFailed(LinkErrorCode.checksumMismatch)),
          ),
        ),
      );
    });

    test('not_found and away are AO §4 failures', () async {
      for (final (code, error) in [
        ('not_found', LinkErrorCode.notFound),
        ('away', LinkErrorCode.away),
      ]) {
        _serve({'archive_fetch': _error(code)});
        expect(
          (await _link.archiveFetch('doc-1')).failureOrNull,
          LinkCallFailed(error),
          reason: code,
        );
      }
    });

    test(
      'a malformed reply is unknownError and cancels its read end',
      () async {
        final apsira = _serve({
          'archive_fetch': _fields({
            'fd': {'stream': 9},
            'sha256': 'short',
            'size': 10,
          }),
        });
        expect(
          (await _link.archiveFetch('doc-1')).failureOrNull,
          LinkUnavailable(LinkUnavailableReason.unknownError),
        );
        expect(apsira.methods, ['archive_fetch', 'cancel']);
        expect(apsira.argsOf('cancel'), {'handle': 9});
      },
    );

    test('a reply without a read end is unknownError', () async {
      final apsira = _serve({
        'archive_fetch': _fields({'sha256': _hex(_bytes(1)), 'size': 1}),
      });
      expect(
        (await _link.archiveFetch('doc-1')).failureOrNull,
        LinkUnavailable(LinkUnavailableReason.unknownError),
      );
      expect(apsira.methods, ['archive_fetch']);
    });
  });

  group('archiveRelease', () {
    test('sends item_id and answers Ok', () async {
      final apsira = _serve({'archive_release': _fields({})});
      expect((await _link.archiveRelease('doc-1')).isOk, isTrue);
      expect(apsira.extrasOf('archive_release'), {'item_id': 'doc-1'});
    });

    test('away is its failure', () async {
      _serve({'archive_release': _error('away')});
      expect(
        (await _link.archiveRelease('doc-1')).failureOrNull,
        LinkCallFailed(LinkErrorCode.away),
      );
    });
  });
}

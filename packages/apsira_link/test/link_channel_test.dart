import 'dart:async';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/src/link_channel.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// LinkChannel (K2-02a): the control call, and the byte streams of contract
// app-link.md §4 and §8 (64 KiB chunks, the SHA-256 and size checked) over
// a mocked channel.
const _channel = MethodChannel(LinkChannel.name);

void _answer(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

Map<Object?, Object?> _args(MethodCall call) =>
    call.arguments as Map<Object?, Object?>;

Uint8List _bytes(int length, {int seed = 0}) =>
    Uint8List.fromList(List.generate(length, (i) => (i * 31 + seed) & 0xff));

String _hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// A Kotlin stand-in serving [served] in reads of at most `max` bytes and
/// recording every call.
class _Reader {
  _Reader(this.served);

  final Uint8List served;
  final calls = <MethodCall>[];
  var _at = 0;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    if (call.method != 'read') return <Object?, Object?>{};
    final max = _args(call)['max']! as int;
    if (_at >= served.length) return {'end': true};
    final end = (_at + max).clamp(0, served.length);
    final chunk = Uint8List.sublistView(served, _at, end);
    _at = end;
    return {'bytes': chunk};
  }

  Iterable<String> get methods => calls.map((c) => c.method);
}

Matcher _streamFailure(LinkFailure failure) =>
    isA<LinkStreamException>().having((e) => e.failure, 'failure', failure);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = LinkChannel();

  tearDown(() => _answer(null));

  test('the names Kotlin answers to', () {
    expect(LinkChannel.name, ChannelApsiraLink.channelName);
    expect(LinkChannel.callMethod, 'call');
    expect(LinkChannel.writeMethod, 'write');
    expect(LinkChannel.readMethod, 'read');
    expect(LinkChannel.closeMethod, 'close');
    expect(LinkChannel.cancelMethod, 'cancel');
    expect(LinkChannel.chunkSize, 64 * 1024);
  });

  group('call', () {
    test('sends the method, the last version and the extras', () async {
      final calls = <MethodCall>[];
      _answer((call) async {
        calls.add(call);
        return {
          'fields': {'free_bytes': 7},
          'devUnverified': false,
        };
      });
      final reply = await channel.call('backup_space', const {'x': 1});
      expect(calls.single.method, 'call');
      expect(_args(calls.single), {
        'method': 'backup_space',
        'version': linkVersions.last,
        'extras': {'x': 1},
      });
      final value = (reply as Ok<LinkReply, LinkFailure>).value;
      expect(value.fields, {'free_bytes': 7});
      expect(value.devUnverified, isFalse);
    });

    test('every platform error is noAnswer', () async {
      final noAnswer = Err<LinkReply, LinkFailure>(
        LinkUnavailable(LinkUnavailableReason.noAnswer),
      );
      _answer((call) async => throw PlatformException(code: 'boom'));
      expect(await channel.call('hello', const {}), noAnswer);
      _answer((call) async => throw MissingPluginException());
      expect(await channel.call('hello', const {}), noAnswer);
      _answer(null);
      expect(await channel.call('hello', const {}), noAnswer);
    });
  });

  group('writeAll', () {
    test(
      'writes 64 KiB chunks, closes, and reports the SHA-256 and size',
      () async {
        final writes = <Uint8List>[];
        final methods = <String>[];
        _answer((call) async {
          methods.add(call.method);
          expect(_args(call)['handle'], 3);
          if (call.method == 'write') {
            writes.add(_args(call)['bytes']! as Uint8List);
          }
          return <Object?, Object?>{};
        });
        final pieces = [
          _bytes(10),
          _bytes(100 * 1024, seed: 1),
          _bytes(30 * 1024),
        ];
        final all = [for (final p in pieces) ...p];

        final written = await channel.writeAll(3, Stream.fromIterable(pieces));

        expect(
          written,
          Ok<LinkWritten, LinkFailure>((sha256: _hex(all), size: all.length)),
        );
        expect(writes.map((w) => w.length), [
          65536,
          65536,
          all.length - 131072,
        ]);
        expect([for (final w in writes) ...w], all);
        expect(methods, ['write', 'write', 'write', 'close']);
      },
    );

    test('an empty stream writes nothing and closes', () async {
      final methods = <String>[];
      _answer((call) async {
        methods.add(call.method);
        return <Object?, Object?>{};
      });
      expect(
        await channel.writeAll(1, const Stream.empty()),
        Ok<LinkWritten, LinkFailure>((sha256: _hex(const []), size: 0)),
      );
      expect(methods, ['close']);
    });

    test('a refused write cancels the stream and is its failure', () async {
      final methods = <String>[];
      _answer((call) async {
        methods.add(call.method);
        if (call.method == 'write') return {'unavailable': 'unknown_error'};
        return <Object?, Object?>{};
      });
      expect(
        await channel.writeAll(1, Stream.value(_bytes(5))),
        Err<LinkWritten, LinkFailure>(
          LinkUnavailable(LinkUnavailableReason.unknownError),
        ),
      );
      expect(methods, ['write', 'cancel']);
    });

    test('a platform error while writing is noAnswer and cancels', () async {
      final methods = <String>[];
      _answer((call) async {
        methods.add(call.method);
        if (call.method == 'write') throw PlatformException(code: 'pipe');
        return <Object?, Object?>{};
      });
      expect(
        await channel.writeAll(1, Stream.value(_bytes(5))),
        Err<LinkWritten, LinkFailure>(
          LinkUnavailable(LinkUnavailableReason.noAnswer),
        ),
      );
      expect(methods, ['write', 'cancel']);
    });

    test('a failing source cancels the stream and is unknownError', () async {
      final methods = <String>[];
      _answer((call) async {
        methods.add(call.method);
        return <Object?, Object?>{};
      });
      Stream<List<int>> source() async* {
        yield _bytes(70 * 1024);
        throw StateError('disk');
      }

      expect(
        await channel.writeAll(1, source()),
        Err<LinkWritten, LinkFailure>(
          LinkUnavailable(LinkUnavailableReason.unknownError),
        ),
      );
      expect(methods, ['write', 'cancel']);
    });
  });

  group('readAll', () {
    test('reads to the end in 64 KiB asks and closes', () async {
      final served = _bytes(150 * 1024, seed: 7);
      final reader = _Reader(served);
      _answer(reader.handle);

      final chunks = await channel
          .readAll(4, sha256: _hex(served), size: served.length)
          .toList();

      expect([for (final c in chunks) ...c], served);
      expect(
        reader.calls
            .where((c) => c.method == 'read')
            .map((c) => _args(c)['max']),
        everyElement(LinkChannel.chunkSize),
      );
      expect(reader.calls.map((c) => _args(c)['handle']), everyElement(4));
      expect(reader.methods.last, 'close');
      expect(reader.methods, isNot(contains('cancel')));
    });

    test('an upper-case stated digest is the same digest', () async {
      final served = _bytes(10);
      _answer(_Reader(served).handle);
      final chunks = await channel
          .readAll(1, sha256: _hex(served).toUpperCase(), size: 10)
          .toList();
      expect(chunks.expand((c) => c), served);
    });

    test('a short stream ends with checksumMismatch', () async {
      final served = _bytes(100);
      final reader = _Reader(Uint8List.sublistView(served, 0, 60));
      _answer(reader.handle);
      final received = <int>[];
      Object? error;
      var done = false;
      final finished = Completer<void>();
      channel
          .readAll(1, sha256: _hex(served), size: 100)
          .listen(
            received.addAll,
            onError: (Object e) => error = e,
            onDone: () {
              done = true;
              finished.complete();
            },
          );
      await finished.future;
      expect(received, hasLength(60));
      expect(
        error,
        _streamFailure(LinkCallFailed(LinkErrorCode.checksumMismatch)),
      );
      expect(done, isTrue);
    });

    test(
      'an altered stream of the stated size ends with checksumMismatch',
      () async {
        final stated = _bytes(100);
        final altered = Uint8List.fromList(stated)..[50] ^= 0xff;
        _answer(_Reader(altered).handle);
        await expectLater(
          channel.readAll(1, sha256: _hex(stated), size: 100),
          emitsInOrder([
            hasLength(100),
            emitsError(
              _streamFailure(LinkCallFailed(LinkErrorCode.checksumMismatch)),
            ),
            emitsDone,
          ]),
        );
      },
    );

    test(
      'a stream longer than stated ends with checksumMismatch and cancels',
      () async {
        final served = _bytes(100);
        final reader = _Reader(served);
        _answer(reader.handle);
        await expectLater(
          channel.readAll(1, sha256: _hex(served), size: 99),
          emitsInOrder([
            emitsError(
              _streamFailure(LinkCallFailed(LinkErrorCode.checksumMismatch)),
            ),
            emitsDone,
          ]),
        );
        expect(reader.methods.last, 'cancel');
      },
    );

    test('a refused read ends with its failure and cancels', () async {
      final methods = <String>[];
      _answer((call) async {
        methods.add(call.method);
        if (call.method == 'read') return {'unavailable': 'unknown_error'};
        return <Object?, Object?>{};
      });
      await expectLater(
        channel.readAll(1, sha256: _hex(const []), size: 0),
        emitsInOrder([
          emitsError(
            _streamFailure(LinkUnavailable(LinkUnavailableReason.unknownError)),
          ),
          emitsDone,
        ]),
      );
      expect(methods, ['read', 'cancel']);
    });

    test('a platform error or an unknown read shape ends the stream', () async {
      _answer((call) async {
        if (call.method == 'read') throw PlatformException(code: 'pipe');
        return <Object?, Object?>{};
      });
      await expectLater(
        channel.readAll(1, sha256: _hex(const []), size: 0),
        emitsInOrder([
          emitsError(
            _streamFailure(LinkUnavailable(LinkUnavailableReason.noAnswer)),
          ),
          emitsDone,
        ]),
      );
      _answer((call) async => {'bytes': 'not bytes'});
      await expectLater(
        channel.readAll(1, sha256: _hex(const []), size: 0),
        emitsInOrder([
          emitsError(
            _streamFailure(LinkUnavailable(LinkUnavailableReason.unknownError)),
          ),
          emitsDone,
        ]),
      );
    });

    test('a listener that stops early cancels the stream', () async {
      final served = _bytes(200 * 1024);
      final reader = _Reader(served);
      _answer(reader.handle);
      await channel.readAll(1, sha256: _hex(served), size: served.length).first;
      expect(reader.methods.last, 'cancel');
      expect(reader.methods, isNot(contains('close')));
    });
  });
}

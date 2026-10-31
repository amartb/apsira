// The method channel to the package's own Kotlin (D-APK-026; K2-02a), shared
// by every call library and not exported from the barrel. The control call
// (`call`, ChannelApsiraLink's `_call`/`_read` moved here unchanged) has the
// 5 s deadline; the byte streams of contract app-link.md §4 (`write`,
// `read`, `close`, `cancel` on a handle Kotlin gave for an `fd`) have none
// (§8) and end with the sender's stated size, their SHA-256 checked here.
// No method throws; Dart never retries on its own.
import 'dart:async';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';

import 'apsira_link.dart';
import 'link_failure.dart';
import 'link_hello.dart';

/// A control call's answer: APSIRA's fields, and whether the link is a dev
/// link checked by name only (contract §3.3). An `fd` in [fields] is
/// `{stream: <handle>}`.
typedef LinkReply = ({Map<Object?, Object?> fields, bool devUnverified});

/// What [LinkChannel.writeAll] wrote: the lower-case hex SHA-256 and the
/// byte count, which the call that commits the stream states.
typedef LinkWritten = ({String sha256, int size});

/// The `apsira_link/link` channel.
final class LinkChannel {
  const LinkChannel();

  /// The channel the Kotlin plugin registers.
  static const name = 'apsira_link/link';

  /// The control call: `{method, version, extras}`.
  static const callMethod = 'call';

  /// `{handle, bytes}` → `{}`.
  static const writeMethod = 'write';

  /// `{handle, max}` → `{bytes}` or `{end: true}`.
  static const readMethod = 'read';

  /// `{handle}`: the stream ended as it should.
  static const closeMethod = 'close';

  /// `{handle}`: the stream is abandoned; the peer sees it short.
  static const cancelMethod = 'cancel';

  /// The largest piece written or asked for at once.
  static const chunkSize = 64 * 1024;

  static const _channel = MethodChannel(name);

  /// [method] on APSIRA with [extras] and the version this client speaks.
  ///
  /// The reply is `{unavailable: <reason>}`, `{error: <§8 code>}` or
  /// `{fields: <map>, devUnverified: <bool>}`. A platform error, a missing
  /// plugin or no reply within [linkControlDeadline] is
  /// [LinkUnavailableReason.noAnswer]; any other shape is
  /// [LinkUnavailableReason.unknownError].
  Future<Result<LinkReply, LinkFailure>> call(
    String method,
    Map<String, Object?> extras,
  ) async {
    final Object? reply;
    try {
      reply = await _channel
          .invokeMethod<Object?>(callMethod, {
            'method': method,
            'version': linkVersions.last,
            'extras': extras,
          })
          .timeout(linkControlDeadline);
    } on PlatformException {
      return Err(LinkUnavailable(LinkUnavailableReason.noAnswer));
    } on MissingPluginException {
      return Err(LinkUnavailable(LinkUnavailableReason.noAnswer));
    } on TimeoutException {
      return Err(LinkUnavailable(LinkUnavailableReason.noAnswer));
    }
    return _read(reply);
  }

  /// Writes [bytes] to the write end [handle] in [chunkSize] pieces, then
  /// closes it. On any failure the stream is cancelled, so APSIRA sees it
  /// short and discards it (contract §8); a failing [bytes] is
  /// [LinkUnavailableReason.unknownError].
  Future<Result<LinkWritten, LinkFailure>> writeAll(
    int handle,
    Stream<List<int>> bytes,
  ) async {
    final digest = _DigestSink();
    final hashing = crypto.sha256.startChunkedConversion(digest);
    final pending = BytesBuilder(copy: false);
    var size = 0;

    Future<LinkFailure?> send(Uint8List chunk) async {
      final failure = await _stream(writeMethod, {
        'handle': handle,
        'bytes': chunk,
      });
      if (failure == null) {
        hashing.add(chunk);
        size += chunk.length;
      }
      return failure;
    }

    Future<Result<LinkWritten, LinkFailure>> abandon(
      LinkFailure failure,
    ) async {
      await _stream(cancelMethod, {'handle': handle});
      return Err(failure);
    }

    try {
      await for (final piece in bytes) {
        pending.add(piece);
        while (pending.length >= chunkSize) {
          final all = pending.takeBytes();
          final failure = await send(Uint8List.sublistView(all, 0, chunkSize));
          if (failure != null) return await abandon(failure);
          pending.add(Uint8List.sublistView(all, chunkSize));
        }
      }
    } on Object {
      return abandon(LinkUnavailable(LinkUnavailableReason.unknownError));
    }
    if (pending.isNotEmpty) {
      final failure = await send(pending.takeBytes());
      if (failure != null) return abandon(failure);
    }
    hashing.close();
    final closed = await _stream(closeMethod, {'handle': handle});
    if (closed != null) return Err(closed);
    return Ok((sha256: digest.value.toString(), size: size));
  }

  /// Reads the read end [handle] to its end in [chunkSize] asks. The stream
  /// ends with a [LinkStreamException] of
  /// [LinkErrorCode.checksumMismatch] when what arrived is not [size] bytes
  /// with the SHA-256 [sha256] (after the last chunk, before done), and of
  /// the failure when a read fails. A failed or abandoned read is
  /// cancelled; a complete one closed.
  Stream<List<int>> readAll(
    int handle, {
    required String sha256,
    required int size,
  }) async* {
    final digest = _DigestSink();
    final hashing = crypto.sha256.startChunkedConversion(digest);
    var read = 0;
    var closed = false;
    try {
      while (true) {
        final reply = await _streamReply(readMethod, {
          'handle': handle,
          'max': chunkSize,
        });
        final Map<Object?, Object?> fields;
        switch (reply) {
          case Err(:final failure):
            throw LinkStreamException(failure);
          case Ok(:final value):
            fields = value;
        }
        if (fields['end'] == true) break;
        final bytes = fields['bytes'];
        if (bytes is! Uint8List) {
          throw LinkStreamException(
            LinkUnavailable(LinkUnavailableReason.unknownError),
          );
        }
        if (read + bytes.length > size) throw _mismatch;
        read += bytes.length;
        hashing.add(bytes);
        yield bytes;
      }
      hashing.close();
      closed = true;
      await _stream(closeMethod, {'handle': handle});
      if (read != size || digest.value.toString() != sha256.toLowerCase()) {
        throw _mismatch;
      }
    } finally {
      if (!closed) await _stream(cancelMethod, {'handle': handle});
    }
  }

  static final _mismatch = LinkStreamException(
    LinkCallFailed(LinkErrorCode.checksumMismatch),
  );

  // A stream call answered `{}` is null; otherwise its failure.
  static Future<LinkFailure?> _stream(
    String method,
    Map<String, Object?> arguments,
  ) async => switch (await _streamReply(method, arguments)) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  // A stream call: no deadline (contract §8). `{unavailable}` and `{error}`
  // are failures as in [call]; any other map is the answer.
  static Future<Result<Map<Object?, Object?>, LinkFailure>> _streamReply(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException {
      return Err(LinkUnavailable(LinkUnavailableReason.noAnswer));
    } on MissingPluginException {
      return Err(LinkUnavailable(LinkUnavailableReason.noAnswer));
    }
    if (reply is! Map<Object?, Object?>) return _unknown();
    final failure = _failure(reply);
    return failure == null ? Ok(reply) : Err(failure);
  }

  static LinkFailure? _failure(Map<Object?, Object?> reply) {
    final unavailable = reply['unavailable'];
    if (unavailable != null) {
      return unavailable is String
          ? LinkUnavailable(LinkUnavailableReason.fromWire(unavailable))
          : LinkUnavailable(LinkUnavailableReason.unknownError);
    }
    final error = reply['error'];
    if (error != null) {
      return error is String
          ? linkFailureFromWire(error)
          : LinkUnavailable(LinkUnavailableReason.unknownError);
    }
    return null;
  }

  static Result<LinkReply, LinkFailure> _read(Object? reply) {
    if (reply is! Map<Object?, Object?>) return _unknown();
    final failure = _failure(reply);
    if (failure != null) return Err(failure);
    final fields = reply['fields'];
    final devUnverified = reply['devUnverified'];
    if (fields is! Map<Object?, Object?> || devUnverified is! bool) {
      return _unknown();
    }
    return Ok((fields: fields, devUnverified: devUnverified));
  }

  static Result<T, LinkFailure> _unknown<T>() =>
      Err(LinkUnavailable(LinkUnavailableReason.unknownError));
}

/// Holds the one digest a chunked SHA-256 conversion produces.
final class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? _value;

  crypto.Digest get value => _value!;

  @override
  void add(crypto.Digest data) => _value = data;

  @override
  void close() {}
}

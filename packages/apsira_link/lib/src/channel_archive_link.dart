// The ApsiraArchiveLink adapter over the package's own Kotlin (D-APK-026;
// K2-02c): atrium-offload.md §3's five methods through LinkChannel
// (K2-02a), which checks APSIRA's certificate before any call. Written from
// the contract; no source app. Nothing here logs; display_name and
// mime_type travel only in archive_put's extras.
import 'dart:convert';

import 'package:apsira_core/apsira_core.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';

import 'archive_link.dart';
import 'link_channel.dart';
import 'link_failure.dart';

/// [ApsiraArchiveLink] over the `apsira_link/link` method channel.
final class ChannelApsiraArchiveLink implements ApsiraArchiveLink {
  const ChannelApsiraArchiveLink();

  static const _channel = LinkChannel();

  @override
  Future<Result<LinkArchiveState, LinkFailure>> archivePut(
    LinkArchiveItem item,
    Stream<List<int>> bytes,
  ) async {
    final put = await _channel.call(LinkArchiveMethod.put.wire, item.extras);
    final int handle;
    switch (put) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: (:final fields, devUnverified: _)):
        final fd = _streamHandle(fields['fd']);
        if (fd == null) return linkArchiveUnknown();
        handle = fd;
    }
    final check = _ItemCheck(item);
    final written = await _channel.writeAll(handle, check.watch(bytes));
    if (written case Err(:final failure)) {
      return Err(
        check.mismatched
            ? LinkCallFailed(LinkErrorCode.checksumMismatch)
            : failure,
      );
    }
    return archiveState(item.itemId);
  }

  @override
  Future<Result<LinkArchiveState, LinkFailure>> archiveState(
    String itemId,
  ) async => switch (await _channel.call(LinkArchiveMethod.state.wire, {
    'item_id': itemId,
  })) {
    Ok(value: (:final fields, devUnverified: _)) => LinkArchiveState.fromReply(
      fields,
    ),
    Err(:final failure) => Err(failure),
  };

  @override
  Future<Result<List<LinkArchiveEntry>, LinkFailure>> archiveList({
    DateTime? since,
  }) async => switch (await _channel.call(LinkArchiveMethod.list.wire, {
    if (since != null) 'since': since.toUtc().toIso8601String(),
  })) {
    Ok(value: (:final fields, devUnverified: _)) =>
      LinkArchiveEntry.listFromReply(fields),
    Err(:final failure) => Err(failure),
  };

  @override
  Future<Result<LinkArchiveFetch, LinkFailure>> archiveFetch(
    String itemId,
  ) async {
    final reply = await _channel.call(LinkArchiveMethod.fetch.wire, {
      'item_id': itemId,
    });
    final Map<Object?, Object?> fields;
    switch (reply) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        fields = value.fields;
    }
    final handle = _streamHandle(fields['fd']);
    if (handle == null) return linkArchiveUnknown();
    final sha256 = fields['sha256'];
    final size = fields['size'];
    if (sha256 is! String ||
        !_sha256Shape.hasMatch(sha256) ||
        size is! int ||
        size < 0) {
      await _cancel(handle);
      return linkArchiveUnknown();
    }
    final digest = sha256.toLowerCase();
    return Ok(
      LinkArchiveFetch(
        bytes: _channel.readAll(handle, sha256: digest, size: size),
        sha256: digest,
        size: size,
      ),
    );
  }

  @override
  Future<Result<void, LinkFailure>> archiveRelease(String itemId) async =>
      switch (await _channel.call(LinkArchiveMethod.release.wire, {
        'item_id': itemId,
      })) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(failure),
      };

  static final _sha256Shape = RegExp(r'^[0-9a-fA-F]{64}$');

  // The handle of an `fd` in a reply (`{stream: <handle>}`, K2-02a); null
  // for any other shape.
  static int? _streamHandle(Object? fd) {
    if (fd is! Map<Object?, Object?>) return null;
    final handle = fd['stream'];
    return handle is int ? handle : null;
  }

  // Abandons the read end of a reply this adapter will not hand out, so
  // Kotlin closes it now rather than at detach. Best effort: a failure here
  // changes nothing about the answer.
  static Future<void> _cancel(int handle) async {
    try {
      await const MethodChannel(LinkChannel.name)
          .invokeMethod<Object?>(LinkChannel.cancelMethod, {'handle': handle});
    } on PlatformException {
      // Kotlin closes every handle on detach.
    } on MissingPluginException {
      // No plugin, no handle to leak.
    }
  }
}

/// Watches the bytes of an `archive_put` against its item: a stream that
/// runs past the item's size fails at once, and one that ends short or
/// with another SHA-256 fails at its end, before LinkChannel.writeAll
/// sends the last piece and closes. writeAll then cancels the write end.
final class _ItemCheck {
  _ItemCheck(this.item);

  final LinkArchiveItem item;

  /// The bytes were not the item's.
  bool mismatched = false;

  Stream<List<int>> watch(Stream<List<int>> bytes) async* {
    crypto.Digest? digest;
    final hashing = crypto.sha256.startChunkedConversion(
      ChunkedConversionSink<crypto.Digest>.withCallback(
        (digests) => digest = digests.single,
      ),
    );
    var size = 0;
    await for (final piece in bytes) {
      size += piece.length;
      if (size > item.size) throw _mismatch();
      hashing.add(piece);
      yield piece;
    }
    hashing.close();
    if (size != item.size || digest.toString() != item.sha256.toLowerCase()) {
      throw _mismatch();
    }
  }

  StateError _mismatch() {
    mismatched = true;
    return StateError('checksum_mismatch');
  }
}

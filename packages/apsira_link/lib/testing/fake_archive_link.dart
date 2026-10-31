// The ApsiraArchiveLink fake for ATRIUM's and the package's tests (K2-02c):
// an in-memory archive that keeps atrium-offload.md's rules. Written from
// the contract; no source app.
import 'package:apsira_core/apsira_core.dart';
import 'package:crypto/crypto.dart' as crypto;

import '../src/archive_link.dart';
import '../src/link_failure.dart';

/// An in-memory APSIRA archive (AO §2–§4): a put whose bytes match the item
/// is `stored`; [secure] stands in for the next hub snapshot. [away]
/// refuses the calls that move bytes (put, fetch) with `away`; [storeFull]
/// refuses a put with `store_full`; both before the stream is read. A put
/// whose bytes are not the item's stores nothing (`checksum_mismatch`); a
/// fetch of an item it does not hold is `not_found`. [unavailable] fails
/// every call. [calls] records each method's wire name, never its content.
final class FakeApsiraArchiveLink implements ApsiraArchiveLink {
  FakeApsiraArchiveLink();

  /// The hub is not reachable.
  bool away = false;

  /// The hub's area is full.
  bool storeFull = false;

  /// When set, every call fails with this reason.
  LinkUnavailableReason? unavailable;

  /// The wire name of each call, in order.
  final calls = <String>[];

  final _held = <String, ({LinkArchiveEntry entry, List<int> bytes})>{};

  /// Marks [itemId] secured, as the next hub snapshot does; a [StateError]
  /// when the archive does not hold it.
  void secure(String itemId) {
    final held = _held[itemId];
    if (held == null) throw StateError('the archive does not hold $itemId');
    _held[itemId] = (
      entry: LinkArchiveEntry(
        item: held.entry.item,
        state: LinkArchiveState.secured,
      ),
      bytes: held.bytes,
    );
  }

  Result<T, LinkFailure>? _refuse<T>(LinkArchiveMethod method) {
    calls.add(method.wire);
    final reason = unavailable;
    return reason == null ? null : Err(LinkUnavailable(reason));
  }

  @override
  Future<Result<LinkArchiveState, LinkFailure>> archivePut(
    LinkArchiveItem item,
    Stream<List<int>> bytes,
  ) async {
    final refused = _refuse<LinkArchiveState>(LinkArchiveMethod.put);
    if (refused != null) return refused;
    if (away) return Err(LinkCallFailed(LinkErrorCode.away));
    if (storeFull) return Err(LinkCallFailed(LinkErrorCode.storeFull));
    final List<int> read;
    try {
      read = await bytes.expand((piece) => piece).toList();
    } on Object {
      return Err(LinkUnavailable(LinkUnavailableReason.unknownError));
    }
    if (read.length != item.size ||
        crypto.sha256.convert(read).toString() != item.sha256.toLowerCase()) {
      return Err(LinkCallFailed(LinkErrorCode.checksumMismatch));
    }
    _held[item.itemId] = (
      entry: LinkArchiveEntry(item: item, state: LinkArchiveState.stored),
      bytes: List.unmodifiable(read),
    );
    return const Ok(LinkArchiveState.stored);
  }

  @override
  Future<Result<LinkArchiveState, LinkFailure>> archiveState(
    String itemId,
  ) async =>
      _refuse(LinkArchiveMethod.state) ??
      Ok(_held[itemId]?.entry.state ?? LinkArchiveState.absent);

  @override
  Future<Result<List<LinkArchiveEntry>, LinkFailure>> archiveList({
    DateTime? since,
  }) async =>
      _refuse(LinkArchiveMethod.list) ??
      Ok(
        List.unmodifiable([
          for (final held in _held.values)
            if (since == null || !held.entry.item.keptUtc.isBefore(since))
              held.entry,
        ]),
      );

  @override
  Future<Result<LinkArchiveFetch, LinkFailure>> archiveFetch(
    String itemId,
  ) async {
    final refused = _refuse<LinkArchiveFetch>(LinkArchiveMethod.fetch);
    if (refused != null) return refused;
    if (away) return Err(LinkCallFailed(LinkErrorCode.away));
    final held = _held[itemId];
    if (held == null) return Err(LinkCallFailed(LinkErrorCode.notFound));
    return Ok(
      LinkArchiveFetch(
        bytes: Stream.value(held.bytes),
        sha256: held.entry.item.sha256.toLowerCase(),
        size: held.bytes.length,
      ),
    );
  }

  @override
  Future<Result<void, LinkFailure>> archiveRelease(String itemId) async {
    final refused = _refuse<void>(LinkArchiveMethod.release);
    if (refused != null) return refused;
    _held.remove(itemId);
    return const Ok(null);
  }
}

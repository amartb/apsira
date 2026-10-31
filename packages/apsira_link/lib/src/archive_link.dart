// The archive calls of the app link (master-app contract atrium-offload.md
// §3, §4; D-010, D-028, D-APK-026; K2-02c): what ATRIUM calls on APSIRA to
// offload a kept document and fetch it back. Every failure is a value;
// APSIRA missing is unavailable (app-link.md §1). Written from the
// contract; no source app. `display_name` and `mime_type` are content: no
// toString here holds them.
import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/foundation.dart';

import 'link_failure.dart';

/// The five archive methods on APSIRA (AO §3), by wire name.
enum LinkArchiveMethod {
  put('archive_put'),
  state('archive_state'),
  list('archive_list'),
  fetch('archive_fetch'),
  release('archive_release');

  const LinkArchiveMethod(this.wire);

  /// The method's name on the channel and in the contract.
  final String wire;
}

/// Where an offloaded document is (AO §2).
enum LinkArchiveState {
  /// The hub wrote the bytes to the archive and verified their SHA-256.
  stored('stored'),

  /// A snapshot of the append-only store holds them (D-008): only now may
  /// ATRIUM remove its local bytes.
  secured('secured'),

  /// The archive does not hold the item.
  absent('absent');

  const LinkArchiveState(this.wire);

  /// The `state` value on the channel and in the contract.
  final String wire;

  /// The state named [wire]; null when the name is unknown.
  static LinkArchiveState? fromWire(String wire) {
    for (final state in values) {
      if (state.wire == wire) return state;
    }
    return null;
  }

  /// The state of an `archive_state` reply [fields]; a missing or unknown
  /// `state` is [LinkUnavailableReason.unknownError].
  static Result<LinkArchiveState, LinkFailure> fromReply(
    Map<Object?, Object?> fields,
  ) {
    final wire = fields['state'];
    final state = wire is String ? fromWire(wire) : null;
    return state == null ? linkArchiveUnknown() : Ok(state);
  }
}

final _sha256Shape = RegExp(r'^[0-9a-fA-F]{64}$');

/// A kept document as ATRIUM states it to the archive (AO §3): [sha256]
/// and [size] are of the plain document. [displayName] and [mimeType] are
/// content: APSIRA seals them and never logs them, and [toString] omits
/// them.
@immutable
final class LinkArchiveItem {
  const LinkArchiveItem({
    required this.itemId,
    required this.displayName,
    required this.mimeType,
    required this.size,
    required this.sha256,
    required this.keptUtc,
  });

  /// ATRIUM's id of the item.
  final String itemId;

  final String displayName;

  final String mimeType;

  final int size;

  /// Hex SHA-256 of the plain document; compared without regard to case.
  final String sha256;

  /// When ATRIUM kept the document; sent in UTC.
  final DateTime keptUtc;

  /// The `archive_put` extras: exactly AO §3's six keys.
  Map<String, Object?> get extras => {
    'item_id': itemId,
    'display_name': displayName,
    'mime_type': mimeType,
    'size': size,
    'sha256': sha256,
    'kept_utc': keptUtc.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is LinkArchiveItem &&
      other.itemId == itemId &&
      other.displayName == displayName &&
      other.mimeType == mimeType &&
      other.size == size &&
      other.sha256.toLowerCase() == sha256.toLowerCase() &&
      other.keptUtc.isAtSameMomentAs(keptUtc);

  @override
  int get hashCode => Object.hash(
    itemId,
    displayName,
    mimeType,
    size,
    sha256.toLowerCase(),
    keptUtc.microsecondsSinceEpoch,
  );

  /// Never the name or the type: they are content.
  @override
  String toString() => 'LinkArchiveItem($itemId, $size bytes)';
}

/// An item the archive holds (AO §3 `archive_list` `items`): its metadata
/// and its [state].
@immutable
final class LinkArchiveEntry {
  const LinkArchiveEntry({required this.item, required this.state});

  final LinkArchiveItem item;

  final LinkArchiveState state;

  /// The entries of an `archive_list` reply [fields], in APSIRA's order.
  ///
  /// `items` that is not a list is [LinkUnavailableReason.unknownError]. An
  /// item that is not a map, or whose `item_id` is not a non-empty string,
  /// `display_name` or `mime_type` not a string, `size` not a non-negative
  /// int, `sha256` not 64 hex digits, `kept_utc` not an ISO 8601 UTC
  /// instant (`…Z`) or `state` not a known state, is dropped.
  static Result<List<LinkArchiveEntry>, LinkFailure> listFromReply(
    Map<Object?, Object?> fields,
  ) {
    final items = fields['items'];
    if (items is! List<Object?>) return linkArchiveUnknown();
    return Ok(
      List.unmodifiable([
        for (final item in items)
          if (_entry(item) case final LinkArchiveEntry parsed) parsed,
      ]),
    );
  }

  static LinkArchiveEntry? _entry(Object? entry) {
    if (entry is! Map<Object?, Object?>) return null;
    final id = entry['item_id'];
    final name = entry['display_name'];
    final mime = entry['mime_type'];
    final size = entry['size'];
    final sha256 = entry['sha256'];
    final kept = entry['kept_utc'];
    final stateWire = entry['state'];
    final state = stateWire is String
        ? LinkArchiveState.fromWire(stateWire)
        : null;
    // `Z` only: an offset parses to UTC too, but is not the contract's form.
    final keptUtc = kept is String && kept.endsWith('Z')
        ? DateTime.tryParse(kept)
        : null;
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        mime is! String ||
        size is! int ||
        size < 0 ||
        sha256 is! String ||
        !_sha256Shape.hasMatch(sha256) ||
        keptUtc == null ||
        !keptUtc.isUtc ||
        state == null) {
      return null;
    }
    return LinkArchiveEntry(
      item: LinkArchiveItem(
        itemId: id,
        displayName: name,
        mimeType: mime,
        size: size,
        sha256: sha256.toLowerCase(),
        keptUtc: keptUtc,
      ),
      state: state,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LinkArchiveEntry && other.item == item && other.state == state;

  @override
  int get hashCode => Object.hash(item, state);

  /// Never the name or the type: they are content.
  @override
  String toString() => 'LinkArchiveEntry($item, ${state.wire})';
}

/// A document being fetched back: the plain [bytes] and their stated
/// [sha256] and [size]. [bytes] is single-subscription; it ends with a
/// [LinkStreamException] when it fails or when what arrived is not [size]
/// bytes with that SHA-256. Listen to it to the end, or cancel: either
/// releases the read end.
@immutable
final class LinkArchiveFetch {
  const LinkArchiveFetch({
    required this.bytes,
    required this.sha256,
    required this.size,
  });

  final Stream<List<int>> bytes;

  /// The plain document's SHA-256, lower-case hex.
  final String sha256;

  final int size;

  /// Never the bytes.
  @override
  String toString() => 'LinkArchiveFetch($size bytes)';
}

/// APSIRA's documents archive, seen from ATRIUM (AO §3). Only
/// `com.apsiralabs.atrium` may call these methods; APSIRA refuses any other
/// caller with `not_authorised`. At home only: the calls that move bytes
/// answer `away` when the hub is not reachable, and nothing is queued on
/// the phone. No method throws: APSIRA missing, untrusted, slow or confused
/// is an [Err] with a [LinkUnavailable]; an AO §4 error (`away`,
/// `checksum_mismatch`, `store_full`, `not_found`) is a [LinkCallFailed].
abstract interface class ApsiraArchiveLink {
  /// Offloads [item] (`archive_put`): sends its metadata, writes [bytes] to
  /// the write end and closes it, then answers one `archive_state` of the
  /// item (`stored` expected). Bytes whose size or SHA-256 is not the
  /// item's are cancelled before the end, so APSIRA discards them, and the
  /// result is `checksum_mismatch`. A refused put never listens to [bytes].
  Future<Result<LinkArchiveState, LinkFailure>> archivePut(
    LinkArchiveItem item,
    Stream<List<int>> bytes,
  );

  /// Where [itemId] is (`archive_state`): stored, secured or absent.
  Future<Result<LinkArchiveState, LinkFailure>> archiveState(String itemId);

  /// The items the archive holds, with their metadata and state
  /// (`archive_list`), from [since] (UTC) when given.
  Future<Result<List<LinkArchiveEntry>, LinkFailure>> archiveList({
    DateTime? since,
  });

  /// Opens [itemId] for reading (`archive_fetch`); `not_found` when the
  /// archive does not hold it.
  Future<Result<LinkArchiveFetch, LinkFailure>> archiveFetch(String itemId);

  /// Tells APSIRA that ATRIUM purged [itemId] (`archive_release`): the hub
  /// removes it from the live area; snapshots keep it per retention.
  Future<Result<void, LinkFailure>> archiveRelease(String itemId);
}

/// [LinkUnavailableReason.unknownError] as an [Err]: a reply of the wrong
/// shape.
Result<T, LinkFailure> linkArchiveUnknown<T>() =>
    Err(LinkUnavailable(LinkUnavailableReason.unknownError));

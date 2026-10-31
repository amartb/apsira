// The backup calls of the app link (contract app-link.md §5.2, D-008,
// D-APK-026; K2-02b): what an app calls on APSIRA to hand a backup over and
// read one back. Every failure is a value; APSIRA missing is unavailable
// (§1). Written from the contract; no source app.
import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/foundation.dart';

import 'link_channel.dart';
import 'link_failure.dart';

/// The seven backup methods on APSIRA (contract §5.2), by wire name.
enum LinkBackupMethod {
  space('backup_space'),
  begin('backup_begin'),
  commit('backup_commit'),
  rename('backup_rename'),
  list('backup_list'),
  delete('backup_delete'),
  restore('restore_open');

  const LinkBackupMethod(this.wire);

  /// The method's name on the channel and in the contract.
  final String wire;
}

/// Where a backup APSIRA knows is (contract §5.2 `state`).
enum LinkBackupState {
  /// Sealed and held on the device, waiting to ship home.
  queued('queued'),

  /// In the hub's append-only store as a snapshot (D-008): never deleted by
  /// an app.
  shipped('shipped');

  const LinkBackupState(this.wire);

  /// The `state` value on the channel and in the contract.
  final String wire;

  /// The state named [wire]; null when the name is unknown.
  static LinkBackupState? fromWire(String wire) {
    for (final state in values) {
      if (state.wire == wire) return state;
    }
    return null;
  }

  /// The state of a `backup_commit` reply [fields]; a missing or unknown
  /// `state` is [LinkUnavailableReason.unknownError].
  static Result<LinkBackupState, LinkFailure> fromCommitReply(
    Map<Object?, Object?> fields,
  ) {
    final wire = fields['state'];
    final state = wire is String ? fromWire(wire) : null;
    return state == null ? _unknown() : Ok(state);
  }
}

/// How a `backup_rename` ended: the answer carries nothing (renamed), or a
/// true `exists` (the target is taken) or `missing` (no queued backup of
/// that name); nothing moved in either case.
enum LinkRenameOutcome {
  renamed,
  exists,
  missing;

  /// The outcome of a `backup_rename` reply [fields]; both flags, or a flag
  /// that is not a bool, is [LinkUnavailableReason.unknownError].
  static Result<LinkRenameOutcome, LinkFailure> fromReply(
    Map<Object?, Object?> fields,
  ) {
    final exists = fields['exists'] ?? false;
    final missing = fields['missing'] ?? false;
    if (exists is! bool || missing is! bool || (exists && missing)) {
      return _unknown();
    }
    if (exists) return const Ok(LinkRenameOutcome.exists);
    if (missing) return const Ok(LinkRenameOutcome.missing);
    return const Ok(LinkRenameOutcome.renamed);
  }
}

/// The free bytes of APSIRA's queue for this app, from a `backup_space`
/// reply [fields]; a missing, negative or mistyped `free_bytes` is
/// [LinkUnavailableReason.unknownError].
Result<int, LinkFailure> linkFreeBytesFromReply(Map<Object?, Object?> fields) {
  final free = fields['free_bytes'];
  return free is int && free >= 0 ? Ok(free) : _unknown();
}

/// A backup APSIRA has begun to take: the [ticket] its commit names and the
/// [handle] of the write end (`fd`, contract §4).
@immutable
final class LinkBackupTicket {
  const LinkBackupTicket({required this.ticket, required this.handle});

  /// APSIRA's ticket, stated again by `backup_commit`.
  final String ticket;

  /// The write end's stream handle.
  final int handle;

  /// The ticket of a `backup_begin` reply [fields]; a missing ticket or
  /// write end is [LinkUnavailableReason.unknownError].
  static Result<LinkBackupTicket, LinkFailure> fromReply(
    Map<Object?, Object?> fields,
  ) {
    final ticket = fields['ticket'];
    final handle = linkStreamHandle(fields['fd']);
    if (ticket is! String || ticket.isEmpty || handle == null) {
      return _unknown();
    }
    return Ok(LinkBackupTicket(ticket: ticket, handle: handle));
  }

  @override
  bool operator ==(Object other) =>
      other is LinkBackupTicket &&
      other.ticket == ticket &&
      other.handle == handle;

  @override
  int get hashCode => Object.hash(ticket, handle);

  @override
  String toString() => 'LinkBackupTicket(handle $handle)';
}

/// A backup APSIRA knows for this app (contract §5.2 `entries`).
@immutable
final class LinkBackupEntry {
  const LinkBackupEntry({
    required this.name,
    required this.sizeBytes,
    required this.madeUtc,
    required this.state,
    this.snapshot,
  });

  /// The app's own file name.
  final String name;

  /// The plain backup's size.
  final int sizeBytes;

  /// When the backup was made, in UTC (`made_utc`).
  final DateTime madeUtc;

  final LinkBackupState state;

  /// The hub's snapshot id; set exactly when [state] is shipped.
  final String? snapshot;

  /// The entries of a `backup_list` reply [fields], in APSIRA's order.
  ///
  /// `entries` that is not a list is [LinkUnavailableReason.unknownError].
  /// An entry that is not a map, or whose `name` is not a non-empty string,
  /// `size` not a non-negative int, `made_utc` not an ISO 8601 UTC instant
  /// (`…Z`), `state` not `queued` or `shipped`, or that is shipped without a
  /// non-empty `snapshot`, is dropped. A queued entry has no snapshot.
  static Result<List<LinkBackupEntry>, LinkFailure> listFromReply(
    Map<Object?, Object?> fields,
  ) {
    final entries = fields['entries'];
    if (entries is! List<Object?>) return _unknown();
    return Ok(
      List.unmodifiable([
        for (final entry in entries)
          if (_entry(entry) case final LinkBackupEntry parsed) parsed,
      ]),
    );
  }

  static LinkBackupEntry? _entry(Object? entry) {
    if (entry is! Map<Object?, Object?>) return null;
    final name = entry['name'];
    final size = entry['size'];
    final made = entry['made_utc'];
    final stateWire = entry['state'];
    final state = stateWire is String
        ? LinkBackupState.fromWire(stateWire)
        : null;
    // `Z` only: an offset parses to UTC too, but is not the contract's form.
    final madeUtc = made is String && made.endsWith('Z')
        ? DateTime.tryParse(made)
        : null;
    if (name is! String ||
        name.isEmpty ||
        size is! int ||
        size < 0 ||
        madeUtc == null ||
        !madeUtc.isUtc ||
        state == null) {
      return null;
    }
    String? snapshot;
    if (state == LinkBackupState.shipped) {
      final sent = entry['snapshot'];
      if (sent is! String || sent.isEmpty) return null;
      snapshot = sent;
    }
    return LinkBackupEntry(
      name: name,
      sizeBytes: size,
      madeUtc: madeUtc,
      state: state,
      snapshot: snapshot,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LinkBackupEntry &&
      other.name == name &&
      other.sizeBytes == sizeBytes &&
      other.madeUtc == madeUtc &&
      other.state == state &&
      other.snapshot == snapshot;

  @override
  int get hashCode => Object.hash(name, sizeBytes, madeUtc, state, snapshot);

  /// Never the name: backup names stay out of logs.
  @override
  String toString() =>
      'LinkBackupEntry(${state.wire}, $sizeBytes bytes, '
      '${madeUtc.toIso8601String()})';
}

/// What a `restore_open` reply opened: the read end's [handle] and the
/// plain backup's [sha256] (lower-case hex) and [size].
@immutable
final class LinkRestoreSource {
  const LinkRestoreSource({
    required this.handle,
    required this.sha256,
    required this.size,
  });

  final int handle;
  final String sha256;
  final int size;

  static final _sha256Shape = RegExp(r'^[0-9a-fA-F]{64}$');

  /// The source of a `restore_open` reply [fields]; a missing read end, a
  /// `sha256` that is not 64 hex digits or a `size` that is not a
  /// non-negative int is [LinkUnavailableReason.unknownError].
  static Result<LinkRestoreSource, LinkFailure> fromReply(
    Map<Object?, Object?> fields,
  ) {
    final handle = linkStreamHandle(fields['fd']);
    final sha256 = fields['sha256'];
    final size = fields['size'];
    if (handle == null ||
        sha256 is! String ||
        !_sha256Shape.hasMatch(sha256) ||
        size is! int ||
        size < 0) {
      return _unknown();
    }
    return Ok(
      LinkRestoreSource(
        handle: handle,
        sha256: sha256.toLowerCase(),
        size: size,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LinkRestoreSource &&
      other.handle == handle &&
      other.sha256 == sha256 &&
      other.size == size;

  @override
  int get hashCode => Object.hash(handle, sha256, size);

  @override
  String toString() => 'LinkRestoreSource(handle $handle, $size bytes)';
}

/// A backup being read back: the plain [bytes] and their stated [sha256]
/// and [size]. [bytes] is single-subscription; it ends with a
/// [LinkStreamException] when it fails or when what arrived is not [size]
/// bytes with that SHA-256. Listen to it to the end, or cancel: either
/// releases the read end.
@immutable
final class LinkRestoreStream {
  const LinkRestoreStream({
    required this.bytes,
    required this.sha256,
    required this.size,
  });

  final Stream<List<int>> bytes;

  /// The plain backup's SHA-256, lower-case hex.
  final String sha256;

  final int size;

  /// Never the bytes.
  @override
  String toString() => 'LinkRestoreStream($size bytes)';
}

/// APSIRA's backup queue, seen from an app (contract §5.2). No method
/// throws: APSIRA missing, untrusted, slow or confused is an [Err] with a
/// [LinkUnavailable], and a §8 error is a [LinkCallFailed]. The one throw is
/// [restoreOpen]'s [ArgumentError], a programming error.
///
/// A backup shipped home is never deleted by an app (D-008):
/// [backupDelete] removes only a queued copy and succeeds on a shipped one.
abstract interface class ApsiraBackupLink {
  /// The free bytes of this app's queue on the device (`backup_space`).
  Future<Result<int, LinkFailure>> backupSpace();

  /// Begins a backup named [name] of [size] bytes, when known
  /// (`backup_begin`): its ticket and write end.
  Future<Result<LinkBackupTicket, LinkFailure>> backupBegin(
    String name, {
    int? size,
  });

  /// Writes [bytes] to [ticket]'s write end to the end and closes it: the
  /// SHA-256 and size of what was written, for [backupCommit]. A failure
  /// cancels the write end; APSIRA discards it.
  Future<Result<LinkWritten, LinkFailure>> backupWrite(
    LinkBackupTicket ticket,
    Stream<List<int>> bytes,
  );

  /// Commits [ticket] stating the plain backup's [sha256] and [size]
  /// (`backup_commit`): APSIRA checks them (`checksum_mismatch` otherwise),
  /// seals the backup and queues it.
  Future<Result<LinkBackupState, LinkFailure>> backupCommit(
    String ticket, {
    required String sha256,
    required int size,
  });

  /// Renames a queued backup [from] to [to] (`backup_rename`).
  Future<Result<LinkRenameOutcome, LinkFailure>> backupRename(
    String from,
    String to,
  );

  /// This app's backups APSIRA knows, queued and shipped (`backup_list`).
  Future<Result<List<LinkBackupEntry>, LinkFailure>> backupList();

  /// Removes the queued copy named [name] (`backup_delete`); a shipped
  /// backup stays, governed by the hub's retention, and the call succeeds.
  Future<Result<void, LinkFailure>> backupDelete(String name);

  /// Opens a backup by exactly one of [name] and [snapshot] for reading
  /// (`restore_open`). A shipped backup needs the hub (`away` otherwise).
  /// Neither or both is an [ArgumentError].
  Future<Result<LinkRestoreStream, LinkFailure>> restoreOpen({
    String? name,
    String? snapshot,
  });
}

/// Throws the [ArgumentError] of [ApsiraBackupLink.restoreOpen] unless
/// exactly one of [name] and [snapshot] is given.
void checkRestoreTarget(String? name, String? snapshot) {
  if ((name == null) == (snapshot == null)) {
    throw ArgumentError('restoreOpen needs exactly one of name and snapshot');
  }
}

/// The handle of an `fd` in a reply (`{stream: <handle>}`, K2-02a); null
/// for any other shape.
int? linkStreamHandle(Object? fd) {
  if (fd is! Map<Object?, Object?>) return null;
  final handle = fd['stream'];
  return handle is int ? handle : null;
}

Result<T, LinkFailure> _unknown<T>() =>
    Err(LinkUnavailable(LinkUnavailableReason.unknownError));

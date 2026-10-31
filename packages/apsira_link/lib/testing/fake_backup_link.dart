// The ApsiraBackupLink fake for app and package tests (contract app-link.md
// §5.2, D-008; K2-02b): an in-memory APSIRA queue that keeps the contract's
// rules, so an adapter tested against it is tested against them. Written
// from the contract; no source app.
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:crypto/crypto.dart' as crypto;

import '../src/backup_link.dart';
import '../src/link_channel.dart';
import '../src/link_failure.dart';

/// An [ApsiraBackupLink] holding this app's backups in memory, by contract
/// §5.2's rules:
///
/// - `backup_commit` checks the stated SHA-256 and size against what was
///   written (`checksum_mismatch` otherwise, the write discarded); a ticket
///   commits once; the backup is then queued, superseding a queued copy of
///   the same name;
/// - [ship] marks a queued backup shipped, with a snapshot id;
/// - `backup_delete` removes only queued copies and succeeds on a shipped
///   backup, which stays (D-008); an unknown name is `not_found`;
/// - `restore_open` of a shipped backup is `away` while [away]; a queued one
///   restores away from home;
/// - queued bytes count toward [queueCap] (shipped ones do not): a backup
///   past it is `storage_full`, at `backup_begin` when its size is stated
///   and at `backup_commit`;
/// - `backup_rename` moves only a queued backup (`missing` otherwise) to a
///   name no backup has (`exists` otherwise).
///
/// [unavailable] fails every call; [failures] sets the failure one call
/// answers. Every call is recorded in [calls], before either applies.
final class FakeApsiraBackupLink implements ApsiraBackupLink {
  /// [clock] stamps `made_utc` (by default a fixed 2026-01-01T00:00Z).
  FakeApsiraBackupLink({Clock? clock, this.queueCap = 1 << 30})
    : _clock = clock ?? FakeClock(DateTime.utc(2026));

  /// The name [calls] and [failures] use for [backupWrite], the stream
  /// write; the other calls use their [LinkBackupMethod.wire].
  static const writeCall = LinkChannel.writeMethod;

  final Clock _clock;

  /// The bytes this app's queued backups may hold on the device.
  int queueCap;

  /// Whether the hub is out of reach: a shipped backup cannot be restored.
  bool away = false;

  /// When set, every call fails with this reason: APSIRA missing, untrusted…
  LinkUnavailableReason? unavailable;

  /// The failure a call answers, by its name in [calls]; a test may change
  /// it between calls.
  final failures = <String, LinkFailure>{};

  /// Every call made, by [LinkBackupMethod.wire] (and [writeCall]), in order.
  final calls = <String>[];

  final _held = <_Held>[];
  final _pending = <String, _Pending>{};
  var _lastTicket = 0;
  var _lastSnapshot = 0;

  /// Marks the queued backup [name] shipped home, as APSIRA does once the
  /// hub took it, with [snapshot] or a new id; returns the id. A test setup
  /// error (no queued backup [name]) is a [StateError].
  String ship(String name, {String? snapshot}) {
    final held = _latest(name, queuedOnly: true);
    if (held == null) throw StateError('no queued backup to ship');
    final id = snapshot ?? 'snap-${++_lastSnapshot}';
    held
      ..state = LinkBackupState.shipped
      ..snapshot = id;
    return id;
  }

  /// The bytes of the latest backup named [name], queued or shipped; null
  /// when there is none.
  List<int>? bytesOf(String name) {
    final held = _latest(name);
    return held == null ? null : List.unmodifiable(held.bytes);
  }

  @override
  Future<Result<int, LinkFailure>> backupSpace() async {
    if (_refused(LinkBackupMethod.space.wire) case final failure?) {
      return Err(failure);
    }
    return Ok(_free());
  }

  @override
  Future<Result<LinkBackupTicket, LinkFailure>> backupBegin(
    String name, {
    int? size,
  }) async {
    if (_refused(LinkBackupMethod.begin.wire) case final failure?) {
      return Err(failure);
    }
    if (size != null && size > _free(superseding: name)) {
      return Err(LinkCallFailed(LinkErrorCode.storageFull));
    }
    final number = ++_lastTicket;
    final ticket = LinkBackupTicket(ticket: 'ticket-$number', handle: number);
    _pending[ticket.ticket] = _Pending(name, number);
    return Ok(ticket);
  }

  @override
  Future<Result<LinkWritten, LinkFailure>> backupWrite(
    LinkBackupTicket ticket,
    Stream<List<int>> bytes,
  ) async {
    if (_refused(writeCall) case final failure?) return Err(failure);
    final pending = _pending[ticket.ticket];
    if (pending == null || pending.handle != ticket.handle) {
      // As the Kotlin answers a handle it does not hold.
      return Err(LinkUnavailable(LinkUnavailableReason.unknownError));
    }
    final builder = BytesBuilder(copy: false);
    try {
      await for (final piece in bytes) {
        builder.add(piece);
      }
    } on Object {
      _pending.remove(ticket.ticket);
      return Err(LinkUnavailable(LinkUnavailableReason.unknownError));
    }
    final written = builder.takeBytes();
    pending.bytes = written;
    return Ok((sha256: _hex(written), size: written.length));
  }

  @override
  Future<Result<LinkBackupState, LinkFailure>> backupCommit(
    String ticket, {
    required String sha256,
    required int size,
  }) async {
    if (_refused(LinkBackupMethod.commit.wire) case final failure?) {
      return Err(failure);
    }
    final pending = _pending.remove(ticket);
    if (pending == null) return Err(LinkCallFailed(LinkErrorCode.notFound));
    final bytes = pending.bytes ?? Uint8List(0);
    if (size != bytes.length || sha256.toLowerCase() != _hex(bytes)) {
      return Err(LinkCallFailed(LinkErrorCode.checksumMismatch));
    }
    if (bytes.length > _free(superseding: pending.name)) {
      return Err(LinkCallFailed(LinkErrorCode.storageFull));
    }
    _held
      ..removeWhere(
        (h) => h.name == pending.name && h.state == LinkBackupState.queued,
      )
      ..add(_Held(pending.name, bytes, _clock.nowUtc()));
    return const Ok(LinkBackupState.queued);
  }

  @override
  Future<Result<LinkRenameOutcome, LinkFailure>> backupRename(
    String from,
    String to,
  ) async {
    if (_refused(LinkBackupMethod.rename.wire) case final failure?) {
      return Err(failure);
    }
    final held = _latest(from, queuedOnly: true);
    if (held == null) return const Ok(LinkRenameOutcome.missing);
    if (_latest(to) != null) return const Ok(LinkRenameOutcome.exists);
    held.name = to;
    return const Ok(LinkRenameOutcome.renamed);
  }

  @override
  Future<Result<List<LinkBackupEntry>, LinkFailure>> backupList() async {
    if (_refused(LinkBackupMethod.list.wire) case final failure?) {
      return Err(failure);
    }
    return Ok(List.unmodifiable(_held.map((h) => h.entry)));
  }

  @override
  Future<Result<void, LinkFailure>> backupDelete(String name) async {
    if (_refused(LinkBackupMethod.delete.wire) case final failure?) {
      return Err(failure);
    }
    if (_latest(name) == null) {
      return Err(LinkCallFailed(LinkErrorCode.notFound));
    }
    // Only a queued copy goes; a shipped backup is the hub's (D-008).
    _held.removeWhere(
      (h) => h.name == name && h.state == LinkBackupState.queued,
    );
    return const Ok(null);
  }

  @override
  Future<Result<LinkRestoreStream, LinkFailure>> restoreOpen({
    String? name,
    String? snapshot,
  }) {
    checkRestoreTarget(name, snapshot);
    return _restoreOpen(name, snapshot);
  }

  Future<Result<LinkRestoreStream, LinkFailure>> _restoreOpen(
    String? name,
    String? snapshot,
  ) async {
    if (_refused(LinkBackupMethod.restore.wire) case final failure?) {
      return Err(failure);
    }
    final held = name != null
        ? _latest(name)
        : _held.where((h) => h.snapshot == snapshot).lastOrNull;
    if (held == null) return Err(LinkCallFailed(LinkErrorCode.notFound));
    if (held.state == LinkBackupState.shipped && away) {
      return Err(LinkCallFailed(LinkErrorCode.away));
    }
    final bytes = Uint8List.fromList(held.bytes);
    return Ok(
      LinkRestoreStream(
        bytes: Stream.value(bytes),
        sha256: _hex(bytes),
        size: bytes.length,
      ),
    );
  }

  LinkFailure? _refused(String call) {
    calls.add(call);
    final reason = unavailable;
    if (reason != null) return LinkUnavailable(reason);
    return failures[call];
  }

  // The cap less the queued bytes; a queued copy named [superseding] is
  // replaced by the new backup, so it does not count.
  int _free({String? superseding}) {
    var queued = 0;
    for (final held in _held) {
      if (held.state == LinkBackupState.queued && held.name != superseding) {
        queued += held.bytes.length;
      }
    }
    return queueCap - queued < 0 ? 0 : queueCap - queued;
  }

  _Held? _latest(String name, {bool queuedOnly = false}) => _held
      .where(
        (h) =>
            h.name == name &&
            (!queuedOnly || h.state == LinkBackupState.queued),
      )
      .lastOrNull;

  static String _hex(List<int> bytes) =>
      crypto.sha256.convert(bytes).toString();
}

final class _Pending {
  _Pending(this.name, this.handle);

  final String name;
  final int handle;
  Uint8List? bytes;
}

final class _Held {
  _Held(this.name, this.bytes, this.madeUtc);

  String name;
  final Uint8List bytes;
  final DateTime madeUtc;
  LinkBackupState state = LinkBackupState.queued;
  String? snapshot;

  LinkBackupEntry get entry => LinkBackupEntry(
    name: name,
    sizeBytes: bytes.length,
    madeUtc: madeUtc,
    state: state,
    snapshot: snapshot,
  );
}

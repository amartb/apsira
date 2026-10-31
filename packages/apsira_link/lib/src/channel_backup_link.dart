// ApsiraBackupLink over the package's own Kotlin (contract app-link.md §5.2,
// D-APK-026; K2-02b): each call is LinkChannel's control call (the Kotlin
// checks APSIRA before it), each `fd` one of its byte streams. Written from
// the contract; no source app.
import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/services.dart';

import 'backup_link.dart';
import 'link_channel.dart';
import 'link_failure.dart';

/// [ApsiraBackupLink] over the `apsira_link/link` channel.
///
/// Each method sends contract §5.2's extras and parses its Bundle; an
/// `{error}` reply is its [LinkFailure] (`linkFailureFromWire`), and a reply
/// that is not the contract's is [LinkUnavailableReason.unknownError]. A
/// reply that holds a stream handle but is otherwise malformed cancels the
/// stream, so APSIRA discards it. No method throws and none retries.
final class ChannelApsiraBackupLink implements ApsiraBackupLink {
  const ChannelApsiraBackupLink();

  static const _link = LinkChannel();

  @override
  Future<Result<int, LinkFailure>> backupSpace() =>
      _call(LinkBackupMethod.space, const {}, linkFreeBytesFromReply);

  @override
  Future<Result<LinkBackupTicket, LinkFailure>> backupBegin(
    String name, {
    int? size,
  }) => _call(LinkBackupMethod.begin, {
    'name': name,
    'size': ?size,
  }, LinkBackupTicket.fromReply);

  @override
  Future<Result<LinkWritten, LinkFailure>> backupWrite(
    LinkBackupTicket ticket,
    Stream<List<int>> bytes,
  ) => _link.writeAll(ticket.handle, bytes);

  @override
  Future<Result<LinkBackupState, LinkFailure>> backupCommit(
    String ticket, {
    required String sha256,
    required int size,
  }) => _call(LinkBackupMethod.commit, {
    'ticket': ticket,
    'sha256': sha256,
    'size': size,
  }, LinkBackupState.fromCommitReply);

  @override
  Future<Result<LinkRenameOutcome, LinkFailure>> backupRename(
    String from,
    String to,
  ) => _call(LinkBackupMethod.rename, {
    'from': from,
    'to': to,
  }, LinkRenameOutcome.fromReply);

  @override
  Future<Result<List<LinkBackupEntry>, LinkFailure>> backupList() =>
      _call(LinkBackupMethod.list, const {}, LinkBackupEntry.listFromReply);

  @override
  Future<Result<void, LinkFailure>> backupDelete(String name) => _call(
    LinkBackupMethod.delete,
    {'name': name},
    (_) => const Ok<void, LinkFailure>(null),
  );

  @override
  Future<Result<LinkRestoreStream, LinkFailure>> restoreOpen({
    String? name,
    String? snapshot,
  }) {
    checkRestoreTarget(name, snapshot);
    return _call(
      LinkBackupMethod.restore,
      {'name': ?name, 'snapshot': ?snapshot},
      (fields) => LinkRestoreSource.fromReply(fields).map(
        (source) => LinkRestoreStream(
          bytes: _link.readAll(
            source.handle,
            sha256: source.sha256,
            size: source.size,
          ),
          sha256: source.sha256,
          size: source.size,
        ),
      ),
    );
  }

  static Future<Result<T, LinkFailure>> _call<T>(
    LinkBackupMethod method,
    Map<String, Object?> extras,
    Result<T, LinkFailure> Function(Map<Object?, Object?> fields) parse,
  ) async {
    final reply = await _link.call(method.wire, extras);
    switch (reply) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: (:final fields, devUnverified: _)):
        final parsed = parse(fields);
        if (parsed is Err<T, LinkFailure>) {
          final handle = linkStreamHandle(fields['fd']);
          if (handle != null) await _cancel(handle);
        }
        return parsed;
    }
  }

  // Abandons a stream a malformed reply opened (LinkChannel's `cancel`);
  // a failure to cancel changes nothing: the reply is already a failure.
  static Future<void> _cancel(int handle) async {
    try {
      await const MethodChannel(LinkChannel.name)
          .invokeMethod<Object?>(LinkChannel.cancelMethod, {'handle': handle});
    } on PlatformException {
      // The Kotlin closes every handle on engine detach.
    } on MissingPluginException {
      // No plugin: no stream either.
    }
  }
}

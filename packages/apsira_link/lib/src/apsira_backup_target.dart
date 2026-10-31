// APSIRA's adapter of apsira_storage's BackupTarget (contract app-link.md
// §5.1, D-008; ruling R-2, D-APK-026; K2-01): the port unchanged, mapped
// method by method onto the backup calls of §5.2. Written from the contract;
// no source app. Every link failure is a port failure the app already
// handles (a full folder, a missing file, a folder that is gone), so an app
// whose APSIRA is missing falls back as from a folder that is gone and is
// never stopped. Nothing is logged.
import 'dart:async';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_storage/apsira_storage.dart';

import 'apsira_link.dart';
import 'backup_link.dart';
import 'link_channel.dart' show LinkWritten;
import 'link_failure.dart';

/// The [BackupTarget] whose folder is APSIRA's queue for this app.
///
/// [folder] is `apsira:<appPackage>`, named "APSIRA"; any other folder is
/// [BackupTarget.folderUnavailable]. `storage_full` is
/// [BackupTarget.storageFull], `not_found` on [rename] and [read] is
/// [BackupTarget.missing], and every other failure (each
/// [LinkUnavailable], `busy`, `away`, `checksum_mismatch`, …) is
/// [BackupTarget.folderUnavailable]. A backup already shipped home is never
/// deleted (D-008): [delete] removes only a queued copy and succeeds.
final class ApsiraBackupTarget implements BackupTarget {
  ApsiraBackupTarget({
    required this._link,
    required this._backups,
    required String appPackage,
    required this._clock,
  }) : folder = BackupFolder(uri: '$scheme$appPackage', displayName: 'APSIRA');

  /// The scheme of APSIRA's virtual folder URI.
  static const scheme = 'apsira:';

  final ApsiraLink _link;
  final ApsiraBackupLink _backups;
  final Clock _clock;

  /// APSIRA's virtual folder for this app, what [pickFolder] returns.
  final BackupFolder folder;

  /// No picker: the folder after a successful `hello`; null when APSIRA is
  /// unavailable.
  @override
  Future<BackupFolder?> pickFolder() async =>
      (await _link.hello()).isOk ? folder : null;

  /// The folder is ours and `hello` succeeds (APSIRA has the app in its
  /// table).
  @override
  Future<bool> hasAccess(BackupFolder folder) async =>
      _ours(folder) && (await _link.hello()).isOk;

  /// `backup_space`: the queue's free bytes on the device; null on any
  /// failure.
  @override
  Future<int?> freeBytes(BackupFolder folder) async {
    if (!_ours(folder)) return null;
    return (await _backups.backupSpace()).valueOrNull;
  }

  /// `backup_list` (a taken name, queued or shipped, is
  /// [BackupTarget.exists] before [bytes] is listened to), then
  /// `backup_begin`, the write, and `backup_commit` with the plain SHA-256
  /// and size. An error from [bytes] is rethrown, as the port states.
  @override
  Future<Result<BackupFile, Failure>> write(
    BackupFolder folder,
    String name,
    Stream<List<int>> bytes,
  ) async {
    if (!_ours(folder)) return const Err(BackupTarget.folderUnavailable);
    final listed = await _backups.backupList();
    switch (listed) {
      case Err(:final failure):
        return Err(_portFailure(failure));
      case Ok(:final value) when value.any((entry) => entry.name == name):
        return const Err(BackupTarget.exists);
      case Ok():
    }
    final begun = await _backups.backupBegin(name);
    final ticket = begun.valueOrNull;
    if (ticket == null) return Err(_portFailure(begun.failureOrNull!));

    // The app's own error is the app's: kept to rethrow, not mapped.
    Object? sourceError;
    StackTrace? sourceTrace;
    final watched = bytes.handleError((Object error, StackTrace trace) {
      sourceError = error;
      sourceTrace = trace;
      Error.throwWithStackTrace(error, trace);
    });
    final written = await _backups.backupWrite(ticket, watched);
    if (sourceError case final error?) {
      Error.throwWithStackTrace(error, sourceTrace!);
    }
    final LinkWritten done;
    switch (written) {
      case Err(:final failure):
        return Err(_portFailure(failure));
      case Ok(:final value):
        done = value;
    }
    final committed = await _backups.backupCommit(
      ticket.ticket,
      sha256: done.sha256,
      size: done.size,
    );
    if (committed case Err(:final failure)) return Err(_portFailure(failure));
    return Ok(
      BackupFile(
        name: name,
        sizeBytes: done.size,
        modifiedUtc: _clock.nowUtc(),
      ),
    );
  }

  /// `backup_rename` within APSIRA's queue (`exists` and `missing` are the
  /// port's), then the renamed backup from `backup_list`.
  @override
  Future<Result<BackupFile, Failure>> rename(
    BackupFolder folder,
    String from,
    String to,
  ) async {
    if (!_ours(folder)) return const Err(BackupTarget.folderUnavailable);
    switch (await _backups.backupRename(from, to)) {
      case Err(:final failure):
        return Err(_portFailure(failure, notFound: BackupTarget.missing));
      case Ok(value: LinkRenameOutcome.exists):
        return const Err(BackupTarget.exists);
      case Ok(value: LinkRenameOutcome.missing):
        return const Err(BackupTarget.missing);
      case Ok(value: LinkRenameOutcome.renamed):
    }
    switch (await _backups.backupList()) {
      case Err(:final failure):
        return Err(_portFailure(failure));
      case Ok(:final value):
        final entry = value.where((e) => e.name == to).lastOrNull;
        return entry == null
            ? const Err(BackupTarget.folderUnavailable)
            : Ok(_file(entry));
    }
  }

  /// `backup_delete`: removes a queued copy. A backup already shipped home
  /// is not deleted, the hub's retention governs it (D-008), and the call
  /// succeeds; so does a name APSIRA does not know.
  @override
  Future<Result<void, Failure>> delete(BackupFolder folder, String name) async {
    if (!_ours(folder)) return const Err(BackupTarget.folderUnavailable);
    return switch (await _backups.backupDelete(name)) {
      Ok() => const Ok(null),
      Err(failure: LinkCallFailed(error: LinkErrorCode.notFound)) => const Ok(
        null,
      ),
      Err(:final failure) => Err(_portFailure(failure)),
    };
  }

  /// `backup_list`: the app's backups APSIRA knows, queued and shipped, each
  /// dated by when it was made.
  @override
  Future<Result<List<BackupFile>, Failure>> list(BackupFolder folder) async {
    if (!_ours(folder)) return const Err(BackupTarget.folderUnavailable);
    return switch (await _backups.backupList()) {
      Ok(:final value) => Ok(List.unmodifiable(value.map(_file))),
      Err(:final failure) => Err(_portFailure(failure)),
    };
  }

  /// `restore_open` by [name], streamed; a failure, before or part-way, ends
  /// the stream with a [BackupTargetException] ([BackupTarget.missing] for
  /// `not_found`).
  @override
  Stream<List<int>> read(BackupFolder folder, String name) async* {
    if (!_ours(folder)) {
      throw const BackupTargetException(BackupTarget.folderUnavailable);
    }
    final opened = await _backups.restoreOpen(name: name);
    final LinkRestoreStream restore;
    switch (opened) {
      case Err(:final failure):
        throw BackupTargetException(
          _portFailure(failure, notFound: BackupTarget.missing),
        );
      case Ok(:final value):
        restore = value;
    }
    // A yield* forwards the inner stream's errors as they are: map them.
    yield* restore.bytes.transform(
      StreamTransformer.fromHandlers(
        handleError: (error, trace, sink) => sink.addError(
          BackupTargetException(
            error is LinkStreamException
                ? _portFailure(error.failure, notFound: BackupTarget.missing)
                : BackupTarget.folderUnavailable,
          ),
          trace,
        ),
      ),
    );
  }

  bool _ours(BackupFolder candidate) => candidate.uri == folder.uri;

  static BackupFile _file(LinkBackupEntry entry) => BackupFile(
    name: entry.name,
    sizeBytes: entry.sizeBytes,
    modifiedUtc: entry.madeUtc,
  );

  /// The port's failure for a link [failure]: `storage_full` is
  /// [BackupTarget.storageFull], `not_found` is [notFound], everything else
  /// [BackupTarget.folderUnavailable].
  static Failure _portFailure(
    LinkFailure failure, {
    Failure notFound = BackupTarget.folderUnavailable,
  }) => switch (failure) {
    LinkCallFailed(error: LinkErrorCode.storageFull) =>
      BackupTarget.storageFull,
    LinkCallFailed(error: LinkErrorCode.notFound) => notFound,
    _ => BackupTarget.folderUnavailable,
  };
}

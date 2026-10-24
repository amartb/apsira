// From relay test/fakes/fake_backup_target.dart @ 09b28810 (LYCEUM's copy is
// the same).
import 'dart:io';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';

import '../backup_target.dart';

/// The operations of [FakeBackupTarget] a fault can be injected into.
enum FakeBackupOp { write, rename, delete, list, read }

/// A backup target over a real directory, normally a temp directory
/// (architecture §3.1).
///
/// [revokeAccess] simulates a folder that is gone; [failNext],
/// [corruptNextRead] and [truncateNextRead] inject one-shot faults; [deletes]
/// records every delete asked for.
final class FakeBackupTarget implements BackupTarget {
  FakeBackupTarget(this.root)
    : folder = BackupFolder(
        uri: root.uri.toString(),
        displayName: root.uri.pathSegments.where((s) => s.isNotEmpty).last,
      );

  /// The directory standing in for the picked folder.
  final Directory root;

  /// The folder [pickFolder] returns; any other folder is unavailable.
  final BackupFolder folder;

  /// Every name [delete] was asked for, in order, failed deletes included.
  final List<String> deletes = [];

  /// What [pickFolder] does next: `false` simulates the user cancelling.
  bool userPicks = true;

  /// What [pickFolder] throws next, once: a picker that breaks (the system
  /// activity gone, a plugin error).
  Object? pickError;

  /// What [freeBytes] answers for the folder: null, the default, is a
  /// folder whose free space cannot be measured.
  int? free;

  bool _accessible = true;
  final Map<FakeBackupOp, ({Failure failure, int? afterBytes})> _faults = {};
  int? _corruptAt;
  bool _corrupt = false;
  int? _truncateTo;
  bool _truncate = false;

  /// Simulates the folder being moved, deleted or its permission revoked,
  /// until the user picks it again.
  void revokeAccess() => _accessible = false;

  /// Makes the next call of [op] that reaches the folder fail with
  /// [failure]. For a write or a read, [afterBytes] lets that many bytes
  /// through first (a write then leaves a partial file).
  void failNext(
    FakeBackupOp op, {
    Failure failure = BackupTarget.folderUnavailable,
    int? afterBytes,
  }) {
    assert(
      afterBytes == null || op == FakeBackupOp.write || op == FakeBackupOp.read,
      'afterBytes applies to a write or a read',
    );
    _faults[op] = (failure: failure, afterBytes: afterBytes);
  }

  /// Flips every bit of the byte at [at] (the middle byte by default) in
  /// what the next read returns; the file itself stays intact.
  void corruptNextRead({int? at}) {
    _corrupt = true;
    _corruptAt = at;
  }

  /// Ends the next read after [keep] bytes (half the file by default); the
  /// file itself stays intact.
  void truncateNextRead({int? keep}) {
    _truncate = true;
    _truncateTo = keep;
  }

  @override
  Future<BackupFolder?> pickFolder() async {
    if (pickError case final error?) {
      pickError = null;
      throw error;
    }
    if (!userPicks) return null;
    _accessible = true;
    return folder;
  }

  @override
  Future<bool> hasAccess(BackupFolder folder) async => _reachable(folder);

  @override
  Future<int?> freeBytes(BackupFolder folder) async =>
      _reachable(folder) ? free : null;

  @override
  Future<Result<BackupFile, Failure>> write(
    BackupFolder folder,
    String name,
    Stream<List<int>> bytes,
  ) async {
    final file = _file(name);
    if (!_reachable(folder)) return const Err(BackupTarget.folderUnavailable);
    if (file.existsSync()) return const Err(BackupTarget.exists);
    final fault = _faults.remove(FakeBackupOp.write);
    if (fault != null) {
      if (fault.afterBytes case final limit?) {
        await _writePartial(file, bytes, limit);
      }
      return Err(fault.failure);
    }
    final sink = file.openWrite();
    try {
      await sink.addStream(bytes);
    } finally {
      await sink.close();
    }
    return Ok(_describe(file));
  }

  @override
  Future<Result<BackupFile, Failure>> rename(
    BackupFolder folder,
    String from,
    String to,
  ) async {
    final source = _file(from);
    final target = _file(to);
    if (!_reachable(folder)) return const Err(BackupTarget.folderUnavailable);
    if (_faults.remove(FakeBackupOp.rename)
        case (:final failure, afterBytes: _)?) {
      return Err(failure);
    }
    if (!source.existsSync()) return const Err(BackupTarget.missing);
    if (target.existsSync()) return const Err(BackupTarget.exists);
    return Ok(_describe(source.renameSync(target.path)));
  }

  @override
  Future<Result<void, Failure>> delete(BackupFolder folder, String name) async {
    final file = _file(name);
    deletes.add(name);
    if (!_reachable(folder)) return const Err(BackupTarget.folderUnavailable);
    if (_faults.remove(FakeBackupOp.delete)
        case (:final failure, afterBytes: _)?) {
      return Err(failure);
    }
    if (file.existsSync()) file.deleteSync();
    return const Ok(null);
  }

  @override
  Future<Result<List<BackupFile>, Failure>> list(BackupFolder folder) async {
    if (!_reachable(folder)) return const Err(BackupTarget.folderUnavailable);
    if (_faults.remove(FakeBackupOp.list)
        case (:final failure, afterBytes: _)?) {
      return Err(failure);
    }
    final files = root.listSync().whereType<File>().map(_describe).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Ok(files);
  }

  @override
  Stream<List<int>> read(BackupFolder folder, String name) {
    // The faults belong to this call, whenever its stream is listened to.
    final file = _file(name);
    final reachable = _reachable(folder);
    final fault = reachable ? _faults.remove(FakeBackupOp.read) : null;
    final corrupt = reachable && _corrupt;
    final corruptAt = _corruptAt;
    final truncate = reachable && _truncate;
    final truncateTo = _truncateTo;
    if (reachable) {
      _corrupt = _truncate = false;
      _corruptAt = _truncateTo = null;
    }
    return _read(
      file,
      reachable: reachable,
      fault: fault,
      corruptAt: corrupt ? corruptAt ?? -1 : null,
      truncateTo: truncate ? truncateTo ?? -1 : null,
    );
  }

  Stream<List<int>> _read(
    File file, {
    required bool reachable,
    required ({Failure failure, int? afterBytes})? fault,
    required int? corruptAt,
    required int? truncateTo,
  }) async* {
    if (!reachable) {
      throw const BackupTargetException(BackupTarget.folderUnavailable);
    }
    if (fault != null && fault.afterBytes == null) {
      throw BackupTargetException(fault.failure);
    }
    if (!file.existsSync()) {
      throw const BackupTargetException(BackupTarget.missing);
    }
    var data = Uint8List.fromList(await file.readAsBytes());
    if (corruptAt != null && data.isNotEmpty) {
      final at = corruptAt < 0 ? data.length ~/ 2 : corruptAt;
      data[at] ^= 0xFF;
    }
    if (truncateTo != null) {
      final keep = truncateTo < 0 ? data.length ~/ 2 : truncateTo;
      data = Uint8List.sublistView(data, 0, keep.clamp(0, data.length));
    }
    final limit = fault?.afterBytes;
    final end = limit == null ? data.length : limit.clamp(0, data.length);
    const chunk = 64 * 1024;
    for (var i = 0; i < end; i += chunk) {
      yield Uint8List.sublistView(data, i, i + chunk < end ? i + chunk : end);
    }
    if (fault != null) throw BackupTargetException(fault.failure);
  }

  Future<void> _writePartial(
    File file,
    Stream<List<int>> bytes,
    int limit,
  ) async {
    final kept = BytesBuilder(copy: false);
    await for (final chunk in bytes) {
      final room = limit - kept.length;
      kept.add(chunk.length <= room ? chunk : chunk.sublist(0, room));
      if (kept.length >= limit) break;
    }
    await file.writeAsBytes(kept.takeBytes(), flush: true);
  }

  bool _reachable(BackupFolder folder) =>
      _accessible && folder.uri == this.folder.uri;

  /// A plain file name in [root]; anything path-like is a caller's bug.
  File _file(String name) {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains(r'\')) {
      throw ArgumentError.value(name, 'name', 'not a plain file name');
    }
    return File('${root.path}/$name');
  }

  BackupFile _describe(File file) => BackupFile(
    name: file.uri.pathSegments.last,
    sizeBytes: file.lengthSync(),
    modifiedUtc: file.lastModifiedSync().toUtc(),
  );
}

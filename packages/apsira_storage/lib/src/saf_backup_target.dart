// From relay lib/data/platform/saf_backup_target.dart @ 09b28810, its
// free space asked of a StorageSpace (D-APK-015).
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_stream/saf_stream_platform_interface.dart'
    show SafWriteStreamInfo;
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart' show SafDocumentFile;

import 'backup_target.dart';
import 'channel_storage_space.dart';
import 'storage_space.dart';

/// The [BackupTarget] on the Storage Access Framework (RELAY architecture
/// §3.1 and §10.1; RELAY D-018 addendum): `saf_util` picks the folder with a persisted
/// grant, checks it, lists, renames and deletes; `saf_stream` streams files
/// in and out.
///
/// Every plugin error becomes a port failure ([failureOf]); nothing here
/// throws, except an error from the bytes a caller writes, which is its own
/// and is rethrown. SAF never replaces a file: a new or renamed file whose
/// name is taken gets a unique one instead (`name (1)`), so both calls check
/// the name first and undo the rare race where it appears in between.
final class SafBackupTarget implements BackupTarget {
  /// [plugins] are `saf_util`'s and `saf_stream`'s unless a test scripts
  /// them; [space] is the storage module's channel unless one is given.
  SafBackupTarget([SafPlugins? plugins, StorageSpace? space])
    : _saf = plugins ?? PluginSaf(),
      _space = space ?? const ChannelStorageSpace();

  final SafPlugins _saf;
  final StorageSpace _space;

  /// The storage module's channel (`StorageModule.kt`, RELAY D-116), which
  /// `ApsiraStoragePlugin` registers on the UI engine only: a background
  /// engine's [freeBytes] is null. [ChannelStorageSpace] asks it.
  static const storageChannelName = ChannelStorageSpace.channelName;

  /// The type every backup file is created with. With
  /// `application/octet-stream` the provider keeps the name as given; a
  /// typed MIME could make it append an extension to `.zip.part`.
  static const mimeType = 'application/octet-stream';

  static final _noSpace = RegExp(
    'ENOSPC|EDQUOT|No space left|quota exceeded',
    caseSensitive: false,
  );

  /// The port failure for a plugin [error]: [BackupTarget.storageFull] when
  /// the provider ran out of space, otherwise
  /// [BackupTarget.folderUnavailable], whose next step is choosing the folder
  /// again. The plugins report Java exceptions by message only (method-channel
  /// calls as `PluginError` with the message, JNI calls as the exception's
  /// text), so a full disk is told by its errno names.
  static Failure failureOf(Object error) => _noSpace.hasMatch('$error')
      ? BackupTarget.storageFull
      : BackupTarget.folderUnavailable;

  /// `null` when the user cancels, and when the picker cannot open (no
  /// activity, or another picker already open): the port has no failure
  /// for a pick.
  @override
  Future<BackupFolder?> pickFolder() async {
    try {
      final picked = await _saf.pickDirectory();
      if (picked == null) return null;
      return BackupFolder(uri: picked.uri, displayName: picked.name);
    } catch (_) {
      return null;
    }
  }

  /// True while the read and write grant is persisted and the folder is
  /// still there.
  @override
  Future<bool> hasAccess(BackupFolder folder) async {
    try {
      return await _saf.hasPersistedPermission(folder.uri) &&
          await _saf.stat(folder.uri, isDir: true) != null;
    } catch (_) {
      return false;
    }
  }

  /// From the storage module: the free bytes of the local volume a tree of
  /// Android's external storage provider is on. No provider gives them
  /// through SAF to an app (the roots' `COLUMN_AVAILABLE_BYTES` needs
  /// `MANAGE_DOCUMENTS`), so any other provider's tree, a cloud one say,
  /// is null, and so is a module (or a given [StorageSpace]) that errs or is
  /// missing.
  @override
  Future<int?> freeBytes(BackupFolder folder) async {
    try {
      return await _space.freeBytes(folder.uri);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Result<BackupFile, Failure>> write(
    BackupFolder folder,
    String name,
    Stream<List<int>> bytes,
  ) async {
    final SafWriteStreamInfo info;
    try {
      if (await _saf.child(folder.uri, name) != null) {
        return const Result.err(BackupTarget.exists);
      }
      info = await _saf.startWrite(folder.uri, name, mimeType);
    } catch (e) {
      return Result.err(failureOf(e));
    }
    final fileUri = info.fileResult.uri.toString();
    if ((info.fileResult.fileName ?? name) != name) {
      // [name] appeared after the check and SAF made the new file's name
      // unique: that file is this call's own, so it goes.
      await _quietly(() => _saf.endWrite(info.session));
      await _quietly(() => _saf.delete(fileUri));
      return const Result.err(BackupTarget.exists);
    }
    var size = 0;
    Object? failed;
    try {
      await for (final chunk in bytes) {
        try {
          await _saf.writeChunk(info.session, _asBytes(chunk));
        } catch (e) {
          failed = e;
          break; // Cancels [bytes]: nothing more is pulled.
        }
        size += chunk.length;
      }
    } catch (_) {
      // The caller's own error; the partial file is the caller's to remove.
      await _quietly(() => _saf.endWrite(info.session));
      rethrow;
    }
    if (failed != null) {
      await _quietly(() => _saf.endWrite(info.session));
      return Result.err(failureOf(failed));
    }
    try {
      await _saf.endWrite(info.session);
      final written = await _saf.stat(fileUri, isDir: false);
      if (written == null) return const Result.err(BackupTarget.missing);
      return Result.ok(_fileOf(written, sizeBytes: size));
    } catch (e) {
      return Result.err(failureOf(e));
    }
  }

  @override
  Future<Result<BackupFile, Failure>> rename(
    BackupFolder folder,
    String from,
    String to,
  ) async {
    try {
      final source = await _saf.child(folder.uri, from);
      if (source == null) return const Result.err(BackupTarget.missing);
      if (await _saf.child(folder.uri, to) != null) {
        return const Result.err(BackupTarget.exists);
      }
      final renamed = await _saf.rename(source.uri, to);
      if (renamed.name != to) {
        // [to] appeared after the check and the provider made the name
        // unique: the file goes back to [from].
        await _quietly(() => _saf.rename(renamed.uri, from));
        return const Result.err(BackupTarget.exists);
      }
      return Result.ok(_fileOf(renamed));
    } catch (e) {
      return Result.err(failureOf(e));
    }
  }

  @override
  Future<Result<void, Failure>> delete(BackupFolder folder, String name) async {
    try {
      final file = await _saf.child(folder.uri, name);
      if (file != null) await _saf.delete(file.uri);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(failureOf(e));
    }
  }

  @override
  Future<Result<List<BackupFile>, Failure>> list(BackupFolder folder) async {
    try {
      final entries = await _saf.list(folder.uri);
      return Result.ok([
        for (final entry in entries)
          if (!entry.isDir) _fileOf(entry),
      ]);
    } catch (e) {
      return Result.err(failureOf(e));
    }
  }

  @override
  Stream<List<int>> read(BackupFolder folder, String name) async* {
    try {
      final file = await _saf.child(folder.uri, name);
      if (file == null) {
        throw const BackupTargetException(BackupTarget.missing);
      }
      await for (final chunk in await _saf.read(file.uri)) {
        yield chunk;
      }
    } on BackupTargetException {
      rethrow;
    } catch (e) {
      throw BackupTargetException(failureOf(e));
    }
  }

  static BackupFile _fileOf(SafDocumentFile entry, {int? sizeBytes}) =>
      BackupFile(
        name: entry.name,
        // saf_util reports -1 when the provider gives no size.
        sizeBytes: sizeBytes ?? (entry.length < 0 ? 0 : entry.length),
        modifiedUtc: DateTime.fromMillisecondsSinceEpoch(
          entry.lastModified,
          isUtc: true,
        ),
      );

  static Uint8List _asBytes(List<int> chunk) =>
      chunk is Uint8List ? chunk : Uint8List.fromList(chunk);

  /// Clean-up after a failure, whose own failure is already being returned.
  static Future<void> _quietly(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {}
  }
}

/// The plugin calls [SafBackupTarget] makes, one member each, so a host test
/// can script them and the error mapping is tested without a device.
abstract interface class SafPlugins {
  /// The folder picker, asking for a persisted read and write grant.
  Future<SafDocumentFile?> pickDirectory();

  /// Whether the read and write grant on [treeUri] is persisted.
  Future<bool> hasPersistedPermission(String treeUri);

  /// The document at [uri]; `null` when it does not exist.
  Future<SafDocumentFile?> stat(String uri, {required bool isDir});

  Future<List<SafDocumentFile>> list(String treeUri);

  /// The direct child [name] of [treeUri]; `null` when there is none.
  Future<SafDocumentFile?> child(String treeUri, String name);

  Future<SafDocumentFile> rename(String fileUri, String newName);

  Future<void> delete(String fileUri);

  /// Creates [name] in [treeUri], never replacing a file, and opens it.
  Future<SafWriteStreamInfo> startWrite(
    String treeUri,
    String name,
    String mime,
  );

  Future<void> writeChunk(String session, Uint8List chunk);

  Future<void> endWrite(String session);

  Future<Stream<Uint8List>> read(String fileUri);
}

/// [SafPlugins] on `saf_util` 3.1 and `saf_stream` 4.0.
final class PluginSaf implements SafPlugins {
  PluginSaf();

  final _util = SafUtil();
  final _stream = SafStream();

  @override
  Future<SafDocumentFile?> pickDirectory() =>
      _util.pickDirectory(writePermission: true, persistablePermission: true);

  @override
  Future<bool> hasPersistedPermission(String treeUri) =>
      _util.hasPersistedPermission(treeUri, checkWrite: true);

  @override
  Future<SafDocumentFile?> stat(String uri, {required bool isDir}) =>
      _util.stat(uri, isDir);

  @override
  Future<List<SafDocumentFile>> list(String treeUri) => _util.list(treeUri);

  @override
  Future<SafDocumentFile?> child(String treeUri, String name) =>
      _util.child(treeUri, [name]);

  @override
  Future<SafDocumentFile> rename(String fileUri, String newName) =>
      _util.rename(fileUri, false, newName);

  @override
  Future<void> delete(String fileUri) => _util.delete(fileUri, false);

  @override
  Future<SafWriteStreamInfo> startWrite(
    String treeUri,
    String name,
    String mime,
  ) => _stream.startWriteStream(treeUri, name, mime, overwrite: false);

  @override
  Future<void> writeChunk(String session, Uint8List chunk) =>
      _stream.writeChunk(session, chunk);

  @override
  Future<void> endWrite(String session) => _stream.endWriteStream(session);

  @override
  Future<Stream<Uint8List>> read(String fileUri) =>
      _stream.readFileStream(fileUri);
}

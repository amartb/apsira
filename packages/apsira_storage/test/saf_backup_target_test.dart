// From relay test/data/platform/saf_backup_target_test.dart @ 09b28810, with
// lyceum test/data/platform/saf_backup_target_test.dart @ 9f4ff27's channel
// cases: every plugin call scripted through the `SafPlugins` seam, every
// plugin error a port failure, the folder's free space over the storage
// channel `apsira_storage/storage` (D-APK-015).
import 'dart:async';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saf_stream/saf_stream_platform_interface.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

const _tree = 'content://tree/backups';
const _folder = BackupFolder(uri: _tree, displayName: 'Backups');

/// A document URI as SAF builds it, its name percent-encoded.
String _uriOf(String name) => '$_tree/document/${Uri.encodeComponent(name)}';

SafDocumentFile _doc(
  String name, {
  int length = 0,
  int lastModified = 0,
  bool isDir = false,
}) => SafDocumentFile(
  uri: _uriOf(name),
  name: name,
  isDir: isDir,
  length: length,
  lastModified: lastModified,
);

/// The plugins as the error a native call ends with: a method-channel call
/// fails with a [PlatformException] (`PluginError` and the Java message), a
/// JNI call with the Java exception's text.
PlatformException _platform(String message) =>
    PlatformException(code: 'PluginError', message: message);

final class _JniLikeError implements Exception {
  const _JniLikeError(this.message);

  final String message;

  @override
  String toString() => 'java.io.IOException: $message';
}

/// A scripted folder: [files] are its documents by name; [errors] makes the
/// next call of a method throw; every call is recorded in [calls].
final class _Saf implements SafPlugins {
  final files = <String, SafDocumentFile>{};
  final written = <String, BytesBuilder>{};
  final calls = <String>[];
  final errors = <String, Object>{};

  SafDocumentFile? picked = _doc('Backups', isDir: true);
  bool permission = true;
  bool folderExists = true;

  /// The name SAF gives a new file; `null` keeps the name asked for.
  String? createdName;

  /// The name the provider gives a renamed file; `null` keeps it.
  String? renamedName;

  /// Fails the write chunk after this many succeeded.
  int? failChunkAfter;
  Object chunkError = const _JniLikeError('write failed');

  /// The chunks a read yields, then [readError] if it is set.
  List<Uint8List>? readChunks;
  Object? readError;

  final _sessions = <String, String>{};
  var _nextSession = 0;
  var _chunks = 0;

  Future<T> _call<T>(String name, FutureOr<T> Function() body) async {
    calls.add(name);
    if (errors.remove(name) case final error?) throw error;
    return body();
  }

  @override
  Future<SafDocumentFile?> pickDirectory() =>
      _call('pickDirectory', () => picked);

  @override
  Future<bool> hasPersistedPermission(String treeUri) =>
      _call('hasPersistedPermission', () => permission);

  @override
  Future<SafDocumentFile?> stat(String uri, {required bool isDir}) =>
      _call('stat', () {
        if (isDir) return folderExists ? picked : null;
        return files.values.where((f) => f.uri == uri).firstOrNull;
      });

  @override
  Future<List<SafDocumentFile>> list(String treeUri) =>
      _call('list', () => files.values.toList());

  @override
  Future<SafDocumentFile?> child(String treeUri, String name) =>
      _call('child $name', () => files[name]);

  @override
  Future<SafDocumentFile> rename(String fileUri, String newName) =>
      _call('rename $newName', () {
        final from = files.values.firstWhere((f) => f.uri == fileUri);
        files.remove(from.name);
        final name = renamedName ?? newName;
        renamedName = null;
        return files[name] = _doc(
          name,
          length: from.length,
          lastModified: from.lastModified,
        );
      });

  @override
  Future<void> delete(String fileUri) => _call('delete $fileUri', () {
    files.removeWhere((_, f) => f.uri == fileUri);
  });

  @override
  Future<SafWriteStreamInfo> startWrite(
    String treeUri,
    String name,
    String mime,
  ) => _call('startWrite $name $mime', () {
    final actual = createdName ?? name;
    final session = '${_nextSession++}';
    _sessions[session] = actual;
    written[actual] = BytesBuilder();
    files[actual] = _doc(actual, lastModified: 1760000000000);
    return SafWriteStreamInfo(
      session,
      SafNewFile(Uri.parse(_uriOf(actual)), actual),
    );
  });

  @override
  Future<void> writeChunk(String session, Uint8List chunk) =>
      _call('writeChunk', () {
        if (failChunkAfter case final n? when _chunks == n) throw chunkError;
        _chunks++;
        written[_sessions[session]]!.add(chunk);
      });

  @override
  Future<void> endWrite(String session) => _call('endWrite', () {
    final name = _sessions.remove(session)!;
    files[name] = _doc(
      name,
      length: written[name]!.length,
      lastModified: 1760000000000,
    );
  });

  @override
  Future<Stream<Uint8List>> read(String fileUri) => _call('read', () async* {
    for (final chunk in readChunks ?? <Uint8List>[]) {
      yield chunk;
    }
    if (readError case final error?) throw error;
  });
}

Stream<List<int>> _bytes(List<List<int>> chunks) => Stream.fromIterable(chunks);

void main() {
  late _Saf saf;
  late BackupTarget target;

  setUp(() {
    saf = _Saf();
    target = SafBackupTarget(saf);
  });

  group('failureOf', () {
    for (final (error, failure) in <(Object, Failure)>[
      (_platform('ENOSPC (No space left on device)'), BackupTarget.storageFull),
      (const _JniLikeError('write failed: ENOSPC'), BackupTarget.storageFull),
      (
        const _JniLikeError('No space left on device'),
        BackupTarget.storageFull,
      ),
      (_platform('EDQUOT (Disk quota exceeded)'), BackupTarget.storageFull),
      (
        _platform('Failed to get DocumentFile from $_tree'),
        BackupTarget.folderUnavailable,
      ),
      (
        _platform('java.lang.SecurityException: Permission Denial'),
        BackupTarget.folderUnavailable,
      ),
      (PlatformException(code: 'NO_ACTIVITY'), BackupTarget.folderUnavailable),
      (StateError('anything else'), BackupTarget.folderUnavailable),
    ]) {
      test('$error is $failure', () {
        expect(SafBackupTarget.failureOf(error), failure);
      });
    }
  });

  group('pickFolder', () {
    test('asks for a persisted write grant and returns the folder', () async {
      expect(
        await target.pickFolder(),
        BackupFolder(uri: _uriOf('Backups'), displayName: 'Backups'),
      );
      expect(saf.calls, ['pickDirectory']);
    });

    test('is null when the user cancels', () async {
      saf.picked = null;
      expect(await target.pickFolder(), isNull);
    });

    test('is null when the picker cannot open, never throwing', () async {
      saf.errors['pickDirectory'] = PlatformException(code: 'ALREADY_PICKING');
      expect(await target.pickFolder(), isNull);
    });
  });

  group('freeBytes (R-16, D-116)', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(SafBackupTarget.storageChannelName);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('asks the storage module for the tree URI\'s free bytes', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return 123456789012;
      });
      expect(await target.freeBytes(_folder), 123456789012);
      expect(calls.single.method, 'freeBytes');
      expect(calls.single.arguments, {'uri': _tree});
    });

    test('is null when the module cannot measure it, errs or is missing, '
        'never throwing', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(await target.freeBytes(_folder), isNull);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'boom'),
      );
      expect(await target.freeBytes(_folder), isNull);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await target.freeBytes(_folder), isNull);
    });

    test('the channel is the package\'s storage module\'s, shared with '
        'ChannelStorageSpace', () {
      expect(SafBackupTarget.storageChannelName, 'apsira_storage/storage');
      expect(ChannelStorageSpace.channelName, 'apsira_storage/storage');
    });

    test(
      'asks the StorageSpace it is given, and is null when that throws',
      () async {
        final space = _Space(folder: 42);
        expect(await SafBackupTarget(saf, space).freeBytes(_folder), 42);
        expect(space.asked, [_tree]);
        space.error = StateError('broken');
        expect(await SafBackupTarget(saf, space).freeBytes(_folder), isNull);
      },
    );
  });

  group('hasAccess', () {
    test('needs the persisted grant and the folder to be there', () async {
      expect(await target.hasAccess(_folder), isTrue);
      saf.folderExists = false;
      expect(await target.hasAccess(_folder), isFalse);
      saf
        ..folderExists = true
        ..permission = false;
      expect(await target.hasAccess(_folder), isFalse);
    });

    test('is false when the plugin errs, never throwing', () async {
      saf.errors['hasPersistedPermission'] = _platform('boom');
      expect(await target.hasAccess(_folder), isFalse);
      saf.errors['stat'] = _platform('boom');
      expect(await target.hasAccess(_folder), isFalse);
    });
  });

  group('write', () {
    test('streams the chunks into a new octet-stream file', () async {
      final result = await target.write(
        _folder,
        'b.zip.part',
        _bytes([
          [1, 2],
          [3],
        ]),
      );
      final file = result.valueOrNull!;
      expect(file.name, 'b.zip.part');
      expect(file.sizeBytes, 3);
      expect(
        file.modifiedUtc,
        DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true),
      );
      expect(saf.written['b.zip.part']!.toBytes(), [1, 2, 3]);
      expect(saf.calls, [
        'child b.zip.part',
        'startWrite b.zip.part ${SafBackupTarget.mimeType}',
        'writeChunk',
        'writeChunk',
        'endWrite',
        'stat',
      ]);
      expect(SafBackupTarget.mimeType, 'application/octet-stream');
    });

    test('refuses a taken name without listening to the bytes', () async {
      saf.files['b.zip'] = _doc('b.zip');
      var listened = false;
      final bytes = Stream<List<int>>.multi((c) {
        listened = true;
        c.close();
      });
      final result = await target.write(_folder, 'b.zip', bytes);
      expect(result.failureOrNull, BackupTarget.exists);
      expect(listened, isFalse);
      expect(saf.calls, ['child b.zip']);
    });

    test('a name SAF made unique in a race is removed: exists', () async {
      saf.createdName = 'b (1).zip';
      final result = await target.write(
        _folder,
        'b.zip',
        _bytes([
          [1],
        ]),
      );
      expect(result.failureOrNull, BackupTarget.exists);
      expect(saf.files, isNot(contains('b (1).zip')));
      expect(saf.calls, contains('delete ${_uriOf('b (1).zip')}'));
    });

    test('a full disk part-way is storageFull; the stream is closed and '
        'no more bytes are read', () async {
      saf
        ..failChunkAfter = 1
        ..chunkError = const _JniLikeError('ENOSPC (No space left on device)');
      var pulled = 0;
      Stream<List<int>> bytes() async* {
        for (var i = 0; i < 5; i++) {
          pulled++;
          yield [i];
        }
      }

      final result = await target.write(_folder, 'b.zip.part', bytes());
      expect(result.failureOrNull, BackupTarget.storageFull);
      expect(saf.calls.last, 'endWrite');
      expect(pulled, lessThan(5));
    });

    test('a revoked grant at the start is folderUnavailable', () async {
      saf.errors['startWrite b.zip ${SafBackupTarget.mimeType}'] = _platform(
        'java.lang.SecurityException: Permission Denial',
      );
      final result = await target.write(
        _folder,
        'b.zip',
        _bytes([
          [1],
        ]),
      );
      expect(result.failureOrNull, BackupTarget.folderUnavailable);
    });

    test('an error closing or checking the file is a failure', () async {
      saf.errors['endWrite'] = const _JniLikeError('No space left on device');
      expect(
        (await target.write(
          _folder,
          'a',
          _bytes([
            [1],
          ]),
        )).failureOrNull,
        BackupTarget.storageFull,
      );
      saf.errors['stat'] = _platform('Failed to get DocumentFile');
      expect(
        (await target.write(
          _folder,
          'b',
          _bytes([
            [1],
          ]),
        )).failureOrNull,
        BackupTarget.folderUnavailable,
      );
    });

    test(
      'an error from the bytes is rethrown after the file is closed',
      () async {
        final bytes = Stream<List<int>>.multi((c) {
          c
            ..add([1])
            ..addError(StateError('zip writer failed'))
            ..close();
        });
        await expectLater(
          target.write(_folder, 'b.zip.part', bytes),
          throwsA(isA<StateError>()),
        );
        expect(saf.calls.last, 'endWrite');
      },
    );
  });

  group('rename', () {
    setUp(() => saf.files['b.zip.part'] = _doc('b.zip.part', length: 7));

    test('renames the file and returns it under its new name', () async {
      final result = await target.rename(_folder, 'b.zip.part', 'b.zip');
      expect(result.valueOrNull?.name, 'b.zip');
      expect(result.valueOrNull?.sizeBytes, 7);
      expect(saf.files.keys, ['b.zip']);
    });

    test('missing when the source is not there', () async {
      final result = await target.rename(_folder, 'gone.part', 'gone');
      expect(result.failureOrNull, BackupTarget.missing);
      expect(saf.calls, ['child gone.part']);
    });

    test('exists when the new name is taken; nothing is renamed', () async {
      saf.files['b.zip'] = _doc('b.zip');
      final result = await target.rename(_folder, 'b.zip.part', 'b.zip');
      expect(result.failureOrNull, BackupTarget.exists);
      expect(saf.calls.where((c) => c.startsWith('rename')), isEmpty);
    });

    test(
      'a name the provider made unique in a race is put back: exists',
      () async {
        saf.renamedName = 'b (1).zip';
        final result = await target.rename(_folder, 'b.zip.part', 'b.zip');
        expect(result.failureOrNull, BackupTarget.exists);
        expect(saf.files.keys, ['b.zip.part']);
      },
    );

    test('a plugin error is a failure, never thrown', () async {
      saf.errors['rename b.zip'] = _platform('Failed to rename to b.zip');
      final result = await target.rename(_folder, 'b.zip.part', 'b.zip');
      expect(result.failureOrNull, BackupTarget.folderUnavailable);
    });
  });

  group('delete', () {
    test('deletes the named file only', () async {
      saf.files
        ..['a.zip'] = _doc('a.zip')
        ..['b.zip'] = _doc('b.zip');
      expect((await target.delete(_folder, 'a.zip')).isOk, isTrue);
      expect(saf.files.keys, ['b.zip']);
    });

    test('a name that is not there is already deleted', () async {
      expect((await target.delete(_folder, 'a.zip')).isOk, isTrue);
      expect(saf.calls, ['child a.zip']);
    });

    test('a plugin error is a failure, never thrown', () async {
      saf.files['a.zip'] = _doc('a.zip');
      saf.errors['delete ${_uriOf('a.zip')}'] = _platform('Permission Denial');
      expect(
        (await target.delete(_folder, 'a.zip')).failureOrNull,
        BackupTarget.folderUnavailable,
      );
    });
  });

  group('list', () {
    test(
      'lists the files by name, size and UTC time, without folders',
      () async {
        saf.files
          ..['a.zip'] = _doc('a.zip', length: 5, lastModified: 1000)
          ..['sub'] = _doc('sub', isDir: true);
        final files = (await target.list(_folder)).valueOrNull!;
        expect(
          [for (final f in files) (f.name, f.sizeBytes, f.modifiedUtc)],
          [
            (
              'a.zip',
              5,
              DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
            ),
          ],
        );
      },
    );

    test('a plugin error is a failure, never thrown', () async {
      saf.errors['list'] = _platform('Failed to get DocumentFile from $_tree');
      expect(
        (await target.list(_folder)).failureOrNull,
        BackupTarget.folderUnavailable,
      );
    });
  });

  group('read', () {
    setUp(() => saf.files['b.zip'] = _doc('b.zip', length: 3));

    test('streams the file', () async {
      saf.readChunks = [
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3]),
      ];
      expect(await target.read(_folder, 'b.zip').toList(), [
        [1, 2],
        [3],
      ]);
    });

    test('a missing file ends the stream with missing', () {
      expect(
        target.read(_folder, 'gone.zip').toList(),
        throwsA(_targetException(BackupTarget.missing)),
      );
    });

    test(
      'a plugin error opening or part-way ends it with the failure',
      () async {
        saf.errors['read'] = _platform('Permission Denial');
        await expectLater(
          target.read(_folder, 'b.zip').toList(),
          throwsA(_targetException(BackupTarget.folderUnavailable)),
        );
        saf
          ..readChunks = [
            Uint8List.fromList([1]),
          ]
          ..readError = const _JniLikeError('read failed');
        final seen = <List<int>>[];
        await expectLater(
          target.read(_folder, 'b.zip').forEach(seen.add),
          throwsA(_targetException(BackupTarget.folderUnavailable)),
        );
        expect(seen, [
          [1],
        ]);
      },
    );

    test('an error finding the file ends it with the failure', () {
      saf.errors['child b.zip'] = _platform('Failed to get DocumentFile');
      expect(
        target.read(_folder, 'b.zip').toList(),
        throwsA(_targetException(BackupTarget.folderUnavailable)),
      );
    });
  });
}

Matcher _targetException(Failure failure) =>
    isA<BackupTargetException>().having((e) => e.failure, 'failure', failure);

/// A [StorageSpace] that answers [folder] for any tree, or throws [error].
final class _Space implements StorageSpace {
  _Space({this.folder});

  final int? folder;
  Object? error;
  final asked = <String>[];

  @override
  Future<int?> freeBytes(String treeUri) async {
    asked.add(treeUri);
    if (error case final error?) throw error;
    return folder;
  }

  @override
  Future<int?> appFreeBytes() async => null;
}

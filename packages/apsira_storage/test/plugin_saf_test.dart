// The plugin side of the two SAF seams (D-APK-015): PluginSaf (RELAY's
// SafBackupTarget seam) and PluginPickSaf (RELAY's SafDocumentPicker seam,
// with VIATICUM's MIME filter) call saf_util and saf_stream with the
// arguments the ports rely on: a persisted write grant, never overwriting,
// a custom read session pulled a chunk at a time and always closed. The
// plugins' platform interfaces are scripted; what only a phone can show is
// a device check.
import 'dart:typed_data';

import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saf_stream/saf_stream_platform_interface.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

final _doc = SafDocumentFile(
  uri: 'content://tree/a',
  name: 'a',
  isDir: false,
  length: 3,
  lastModified: 0,
);

/// Records each saf_util call with its arguments.
final class _Util extends SafUtilPlatform {
  final calls = <String>[];

  @override
  Future<SafDocumentFile?> pickDirectory({
    String? initialUri,
    bool? writePermission,
    bool? persistablePermission,
  }) async {
    calls.add('pickDirectory $writePermission $persistablePermission');
    return _doc;
  }

  @override
  Future<SafDocumentFile?> pickFile({
    String? initialUri,
    List<String>? mimeTypes,
  }) async {
    calls.add('pickFile $mimeTypes');
    return _doc;
  }

  @override
  Future<bool> hasPersistedPermission(
    String uri, {
    bool checkRead = true,
    bool checkWrite = false,
  }) async {
    calls.add('hasPersistedPermission $uri $checkRead $checkWrite');
    return true;
  }

  @override
  Future<SafDocumentFile?> stat(String uri, bool? isDir, {bool? throws}) async {
    calls.add('stat $uri $isDir');
    return _doc;
  }

  @override
  Future<List<SafDocumentFile>> list(String uri) async {
    calls.add('list $uri');
    return [_doc];
  }

  @override
  Future<SafDocumentFile?> child(String uri, List<String> names) async {
    calls.add('child $uri $names');
    return _doc;
  }

  @override
  Future<SafDocumentFile> rename(String uri, bool isDir, String newName) async {
    calls.add('rename $uri $isDir $newName');
    return _doc;
  }

  @override
  Future<void> delete(String uri, bool isDir) async {
    calls.add('delete $uri $isDir');
  }
}

/// Records each saf_stream call; a custom read serves [chunks].
final class _Stream extends SafStreamPlatform {
  final calls = <String>[];
  var chunks = <Uint8List>[];

  @override
  Future<SafWriteStreamInfo> startWriteStream(
    String treeUri,
    String fileName,
    String mime, {
    bool? overwrite,
    bool? append,
  }) async {
    calls.add('startWriteStream $treeUri $fileName $mime $overwrite');
    return SafWriteStreamInfo('s1', SafNewFile(Uri.parse('content://f'), 'f'));
  }

  @override
  Future<void> writeChunk(String session, Uint8List data) async {
    calls.add('writeChunk $session ${data.length}');
  }

  @override
  Future<void> endWriteStream(String session) async {
    calls.add('endWriteStream $session');
  }

  @override
  Future<Stream<Uint8List>> readFileStream(
    String uri, {
    int? bufferSize,
    int? start,
  }) async {
    calls.add('readFileStream $uri');
    return Stream.value(Uint8List(2));
  }

  @override
  Future<String> startReadCustomFileStream(
    String uri, {
    int? bufferSize,
  }) async {
    calls.add('startReadCustomFileStream $uri $bufferSize');
    return 'r1';
  }

  @override
  Future<Uint8List?> readCustomFileStreamChunk(String session) async {
    calls.add('readCustomFileStreamChunk $session');
    return chunks.isEmpty ? null : chunks.removeAt(0);
  }

  @override
  Future<void> endReadCustomFileStream(String session) async {
    calls.add('endReadCustomFileStream $session');
  }
}

void main() {
  late _Util util;
  late _Stream stream;

  setUp(() {
    SafUtilPlatform.instance = util = _Util();
    SafStreamPlatform.instance = stream = _Stream();
  });

  test('PluginSaf asks for a persisted write grant, checks it with write, '
      'and passes every call through', () async {
    final saf = PluginSaf();
    expect(await saf.pickDirectory(), _doc);
    expect(await saf.hasPersistedPermission('t'), isTrue);
    await saf.stat('u', isDir: true);
    await saf.list('t');
    await saf.child('t', 'n');
    await saf.rename('u', 'm');
    await saf.delete('u');
    expect(util.calls, [
      'pickDirectory true true',
      'hasPersistedPermission t true true',
      'stat u true',
      'list t',
      'child t [n]',
      'rename u false m',
      'delete u false',
    ]);
  });

  test(
    'PluginSaf writes without overwriting and reads the file stream',
    () async {
      final saf = PluginSaf();
      final info = await saf.startWrite(
        't',
        'b.zip',
        'application/octet-stream',
      );
      await saf.writeChunk(info.session, Uint8List(5));
      await saf.endWrite(info.session);
      expect(await (await saf.read('u')).single, Uint8List(2));
      expect(stream.calls, [
        'startWriteStream t b.zip application/octet-stream false',
        'writeChunk s1 5',
        'endWriteStream s1',
        'readFileStream u',
      ]);
    },
  );

  test('PluginPickSaf picks one file, of the types asked for', () async {
    final saf = PluginPickSaf();
    expect(await saf.pickFile(), _doc);
    await saf.pickFile(mimeTypes: ['application/json']);
    expect(util.calls, ['pickFile null', 'pickFile [application/json]']);
  });

  test('PluginPickSaf reads in chunkBytes pulls until the end, and closes '
      'the session', () async {
    stream.chunks = [Uint8List(3), Uint8List(4)];
    final read = await PluginPickSaf().read('u').toList();
    expect([for (final c in read) c.length], [3, 4]);
    expect(stream.calls, [
      'startReadCustomFileStream u ${PluginPickSaf.chunkBytes}',
      'readCustomFileStreamChunk r1',
      'readCustomFileStreamChunk r1',
      'readCustomFileStreamChunk r1',
      'endReadCustomFileStream r1',
    ]);
  });

  test(
    'PluginPickSaf closes the session when the reader stops early',
    () async {
      stream.chunks = [Uint8List(3), Uint8List(4), Uint8List(5)];
      expect((await PluginPickSaf().read('u').first).length, 3);
      expect(stream.calls.last, 'endReadCustomFileStream r1');
      expect(
        stream.calls.where((c) => c.startsWith('readCustom')),
        hasLength(1),
      );
    },
  );
}

// From relay test/data/platform/saf_document_picker_test.dart @ 09b28810,
// with viaticum test/data/platform/saf_document_picker_test.dart @ 78d38e0's
// pick/readAll cases on the same seam (D-APK-015).
// The document pick on the Storage Access Framework (K-101, KAIROS `07`
// §2, AC-11.3): `saf_util` picks one document with its size, which is
// checked before a byte is read; `saf_stream` reads it a chunk at a time,
// stopping at the first chunk past the cap.
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

/// A holiday pack's cap (KAIROS `07` §3.2).
const _mib = 1048576;

const _chunk = PluginPickSaf.chunkBytes;

/// A scripted picker: [picked] is what the pick returns (null cancels),
/// [content] the document's bytes, served in [_chunk]-sized chunks;
/// [chunksServed] counts the chunks the reader pulled before it stopped.
final class _Saf implements PickSafPlugins {
  _Saf({this.picked, this.content});

  SafDocumentFile? picked;
  Uint8List? content;
  Object? pickError;
  Object? readError;
  final reads = <String>[];
  final mimeTypes = <List<String>?>[];
  var picks = 0;
  var chunksServed = 0;

  @override
  Future<SafDocumentFile?> pickFile({List<String>? mimeTypes}) async {
    picks++;
    this.mimeTypes.add(mimeTypes);
    if (pickError case final error?) throw error;
    return picked;
  }

  @override
  Stream<Uint8List> read(String uri) async* {
    reads.add(uri);
    if (readError case final error?) throw error;
    final bytes = content!;
    for (var at = 0; at < bytes.length; at += _chunk) {
      chunksServed++;
      final end = at + _chunk < bytes.length ? at + _chunk : bytes.length;
      yield Uint8List.sublistView(bytes, at, end);
    }
  }
}

SafDocumentFile _file(String name, int length) => SafDocumentFile(
  uri: 'content://docs/document/${Uri.encodeComponent(name)}',
  name: name,
  isDir: false,
  length: length,
  lastModified: 0,
);

Uint8List _bytes(int length) =>
    Uint8List.fromList(List.generate(length, (i) => i % 251));

void main() {
  test('a cancel is null, and reads nothing', () async {
    final saf = _Saf();
    final result = await SafDocumentPicker(saf).pickOne(maxBytes: _mib);
    expect(result, isA<Ok<PickedDocument?, Failure>>());
    expect((result as Ok).value, isNull);
    expect(saf.picks, 1);
    expect(saf.reads, isEmpty);
  });

  test('a picker that cannot open (no activity, one already open) is a '
      'cancel', () async {
    final saf = _Saf()..pickError = PlatformException(code: 'ALREADY_PICKING');
    final result = await SafDocumentPicker(saf).pickOne(maxBytes: _mib);
    expect((result as Ok).value, isNull);
    expect(saf.reads, isEmpty);
  });

  test('one document within the cap comes back whole, with its name', () async {
    final content = _bytes(200 * 1024 + 7);
    final saf = _Saf(
      picked: _file('es-zz.json', content.length),
      content: content,
    );
    final result = await SafDocumentPicker(saf).pickOne(maxBytes: _mib);
    final picked = (result as Ok<PickedDocument?, Failure>).value!;
    expect(picked.name, 'es-zz.json');
    expect(picked.bytes, content);
    expect(saf.reads, ['content://docs/document/es-zz.json']);
  });

  test('exactly 1 MiB is within the cap', () async {
    final content = _bytes(_mib);
    final saf = _Saf(picked: _file('pack.json', _mib), content: content);
    final result = await SafDocumentPicker(saf).pickOne(maxBytes: _mib);
    expect((result as Ok<PickedDocument?, Failure>).value!.bytes, content);
  });

  test('a document over the cap by its size is refused before a byte is '
      'read', () async {
    final saf = _Saf(
      picked: _file('big.json', _mib + 1),
      content: _bytes(_mib + 1),
    );
    final result = await SafDocumentPicker(saf).pickOne(maxBytes: _mib);
    expect((result as Err).failure.code, DocumentPicker.documentTooLarge);
    expect(saf.reads, isEmpty);
  });

  test('a document whose size is unknown or understated is refused once '
      'its bytes pass the cap, without reading it whole', () async {
    for (final length in [-1, 0, 1000]) {
      final saf = _Saf(
        picked: _file('liar.json', length),
        content: _bytes(4 * _mib),
      );
      final result = await SafDocumentPicker(saf).pickOne(maxBytes: _mib);
      expect(
        (result as Err).failure.code,
        DocumentPicker.documentTooLarge,
        reason: '$length',
      );
      // 16 chunks fill the cap; the 17th passes it and the read stops.
      expect(saf.chunksServed, _mib ~/ _chunk + 1, reason: '$length');
    }
  });

  test('a read that fails is documentUnreadable, never a throw', () async {
    final opening = _Saf(picked: _file('gone.json', 10))
      ..readError = PlatformException(code: 'PluginError', message: 'gone');
    expect(
      ((await SafDocumentPicker(
        opening,
      ).pickOne(maxBytes: _mib)) as Err).failure,
      SafDocumentPicker.documentUnreadable,
    );

    final midway = _Saf(picked: _file('cut.json', 10), content: _bytes(10));
    final failing = _FailingSaf(midway);
    expect(
      ((await SafDocumentPicker(
        failing,
      ).pickOne(maxBytes: _mib)) as Err).failure,
      SafDocumentPicker.documentUnreadable,
    );
  });

  test('the plugins are saf_util and saf_stream by default', () {
    expect(SafDocumentPicker(), isA<DocumentPicker>());
  });

  test('pickOne offers every type', () async {
    final saf = _Saf();
    await SafDocumentPicker(saf).pickOne(maxBytes: _mib);
    expect(saf.mimeTypes, [null]);
  });

  test('documentUnreadable is the port\'s one failure in both apps', () {
    expect(
      SafDocumentPicker.documentUnreadable,
      DocumentPicker.documentUnreadable,
    );
    expect(DocumentPicker.documentUnreadable.code, 'documentUnreadable');
    expect(DocumentPicker.tooLarge.code, DocumentPicker.documentTooLarge);
  });

  // VIATICUM's pick and readAll (viaticum test/data/platform/
  // saf_document_picker_test.dart @ 78d38e0), on RELAY's seam.
  group('pick and readAll', () {
    test('a cancelled pick is Ok(null), and reads nothing', () async {
      final saf = _Saf();
      expect(
        await SafDocumentPicker(saf).pick(),
        const Ok<DocumentRef?, Failure>(null),
      );
      expect(saf.reads, isEmpty);
    });

    test('a picker that cannot open is a cancel', () async {
      final saf = _Saf()..pickError = PlatformException(code: 'ALREADY');
      expect(
        await SafDocumentPicker(saf).pick(),
        const Ok<DocumentRef?, Failure>(null),
      );
    });

    test('a pick returns the document and its size, offering the types '
        'asked for (every type when none)', () async {
      final saf = _Saf(picked: _file('trip.viaticum.json', 300));
      final picked = await SafDocumentPicker(saf)
          .pick(mimeTypes: ['application/json']);
      expect(
        picked,
        const Ok<DocumentRef?, Failure>(
          DocumentRef(
            uri: 'content://docs/document/trip.viaticum.json',
            name: 'trip.viaticum.json',
            sizeBytes: 300,
          ),
        ),
      );
      await SafDocumentPicker(saf).pick();
      expect(saf.mimeTypes, [
        ['application/json'],
        null,
      ]);
      expect(saf.reads, isEmpty);
    });

    test('a DocumentRef prints its size only', () {
      const ref = DocumentRef(uri: 'content://x', name: 'secret', sizeBytes: 3);
      expect('$ref', 'DocumentRef(3 bytes)');
    });

    test('readAll streams the whole document under the limit', () async {
      final content = _bytes(3 * _mib + 5);
      final saf = _Saf(content: content);
      final ref = DocumentRef(
        uri: 'content://docs/a.json',
        name: 'a.json',
        sizeBytes: content.length,
      );
      final read = await SafDocumentPicker(saf)
          .readAll(ref, maxBytes: 4 * _mib);
      expect(read.valueOrNull, content);
      expect(saf.reads, ['content://docs/a.json']);
    });

    test('a document over the limit by its size is tooLarge, unread', () async {
      final saf = _Saf(content: _bytes(1000));
      const ref = DocumentRef(uri: 'u', name: 'big.json', sizeBytes: 1000);
      expect(
        (await SafDocumentPicker(
          saf,
        ).readAll(ref, maxBytes: 999)).failureOrNull,
        DocumentPicker.tooLarge,
      );
      expect(saf.reads, isEmpty);
    });

    test('an unknown size is refused once the read passes the limit, '
        'without reading it whole', () async {
      final saf = _Saf(content: _bytes(4 * _mib));
      const ref = DocumentRef(uri: 'u', name: 'big.json', sizeBytes: -1);
      expect(
        (await SafDocumentPicker(
          saf,
        ).readAll(ref, maxBytes: _mib)).failureOrNull,
        DocumentPicker.tooLarge,
      );
      expect(saf.chunksServed, _mib ~/ _chunk + 1);
    });

    test('a document the provider cannot read, or that fails part-way, is '
        'documentUnreadable', () async {
      const ref = DocumentRef(uri: 'u', name: 'gone.json', sizeBytes: 3);
      final gone = _Saf()
        ..readError = PlatformException(code: 'PluginError', message: 'gone');
      expect(
        (await SafDocumentPicker(
          gone,
        ).readAll(ref, maxBytes: 10)).failureOrNull,
        DocumentPicker.documentUnreadable,
      );
      final midway = _FailingSaf(_Saf(content: _bytes(10)));
      expect(
        (await SafDocumentPicker(
          midway,
        ).readAll(ref, maxBytes: 10)).failureOrNull,
        DocumentPicker.documentUnreadable,
      );
    });
  });
}

/// [_Saf] whose stream fails after its first chunk.
final class _FailingSaf implements PickSafPlugins {
  _FailingSaf(this._saf);

  final _Saf _saf;

  @override
  Future<SafDocumentFile?> pickFile({List<String>? mimeTypes}) =>
      _saf.pickFile(mimeTypes: mimeTypes);

  @override
  Stream<Uint8List> read(String uri) async* {
    yield Uint8List(4);
    throw PlatformException(code: 'PluginError', message: 'EIO');
  }
}

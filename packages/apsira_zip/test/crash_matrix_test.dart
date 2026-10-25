// The crash matrix KP-Z (D-APK-020): every way a backup or a bundle can
// come back damaged — cut short, a byte changed, the writer stopped
// mid-entry, a name that would climb out of its folder, the disk full while
// extracting, a whole archive that is not the one written — ends in a
// refusal, never in `Ok`, and nothing extracted is reported as complete.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_zip/apsira_zip.dart';
import 'package:test/test.dart';

import 'support/zips.dart';

/// Three entries, the second forced into ZIP64 by the lowered limit.
Future<(Uint8List, ZipSummary)> _three() {
  final big = randomBytes(6 * kib, 4);
  return zipOf([
    ZipEntry('a.db', chunks(pages(2 * kib, 1)), sha256: true),
    ZipEntry('media/b.bin', chunks(big, 1000), size: big.length),
    ZipEntry('manifest.json', Stream.value(utf8.encode('{"n":"ñ"}'))),
  ], zip32Max: 4 * kib);
}

Future<Result<ZipContents, ZipRefused>> _verify(
  Uint8List zip, {
  RecordingSink? sink,
  String? expectedSha256,
}) => verifyZip(
  streamOf(zip),
  keepLimit: 1 << 20,
  keep: const {'manifest.json'},
  sha256Where: (_) => true,
  expectedSha256: expectedSha256,
  extractWhere: sink == null ? null : (_) => true,
  extract: sink,
);

const _structural = {
  ZipRefusal.truncated,
  ZipRefusal.corrupt,
  ZipRefusal.crcMismatch,
  ZipRefusal.sizeMismatch,
  ZipRefusal.directoryMismatch,
  ZipRefusal.unsafeName,
};

void main() {
  test('KP-Z1: an archive cut at every byte is truncated or corrupt, never Ok, '
      'and every extracted file is closed', () async {
    final (zip, summary) = await _three();
    expect(summary.entries.map((e) => e.zip64), [false, true, false]);
    for (var n = 0; n < zip.length; n++) {
      final sink = RecordingSink();
      final r = await _verify(Uint8List.sublistView(zip, 0, n), sink: sink);
      expect(r.isErr, isTrue, reason: '$n bytes');
      expect(
        refusalOf(r),
        anyOf(ZipRefusal.truncated, ZipRefusal.corrupt),
        reason: '$n bytes',
      );
      expect(sink.closed, sink.opened, reason: '$n bytes: no open target');
    }
    expect((await _verify(zip)).isOk, isTrue, reason: 'whole, it verifies');
  });

  test('KP-Z2: one byte flipped at every offset is a refusal', () async {
    final (zip, summary) = await _three();
    bool inData(int i) => summary.entries.any((e) {
      final start =
          e.offset + 30 + utf8.encode(e.name).length + (e.zip64 ? 20 : 0);
      return i >= start && i < start + e.compressedSize;
    });
    final seen = <ZipRefusal>{};
    for (var i = 0; i < zip.length; i++) {
      final bad = Uint8List.fromList(zip)..[i] ^= 0xFF;
      final r = await _verify(bad, expectedSha256: summary.sha256);
      final why = refusalOf(r);
      expect(r.isErr, isTrue, reason: 'byte $i');
      seen.add(why!);
      if (why == ZipRefusal.digestMismatch) {
        // Deflate has bits its output does not depend on; only the digest
        // tells such a flip from the bytes written (the reader's library
        // comment).
        expect(inData(i), isTrue, reason: 'byte $i: digest only in data');
      } else {
        expect(_structural, contains(why), reason: 'byte $i: $why');
      }
    }
    expect(
      seen,
      containsAll([
        ZipRefusal.corrupt,
        ZipRefusal.crcMismatch,
        ZipRefusal.directoryMismatch,
      ]),
    );
  });

  test(
    'KP-Z3: the bytes of a writer cancelled mid-entry are truncated',
    () async {
      final source = StreamController<List<int>>();
      final writer = ZipWriter(modified: modified, chunkSize: 1);
      final got = BytesBuilder();
      final sub = writer
          .write([
            ZipEntry('a.db', Stream.value(utf8.encode('first'))),
            ZipEntry('b.db', source.stream),
          ])
          .listen(got.add);
      for (var i = 0; i < 8; i++) {
        source.add(randomBytes(4 * kib, i));
        await Future<void>.delayed(Duration.zero);
      }
      // A cancel takes effect when the source delivers its next chunk.
      final cancelled = sub.cancel();
      source.add(randomBytes(4 * kib, 99));
      await cancelled;
      await expectLater(writer.done, throwsStateError);
      final bytes = got.takeBytes();
      expect(bytes, isNotEmpty, reason: 'the first entry and part of b.db');
      final r = await verifyZip(streamOf(bytes), keepLimit: 1 << 20);
      expect(refusalOf(r), ZipRefusal.truncated);
      unawaited(source.close());
    },
  );

  test(r'KP-Z4: names ../x, /x, a\..\b, a repeated name and invalid UTF-8 are '
      'unsafeName, and none is extracted', () async {
    final (zip, _) = await zipOf([
      ZipEntry('ok/first', Stream.value(const [1])),
      ZipEntry('abcdef', Stream.value(const [2])),
    ]);
    final at = Layout(zip);
    final cases = <String, List<int>>{
      '../x': utf8.encode('../xyz'),
      '/x': utf8.encode('/xyzab'),
      r'a\..\b': utf8.encode(r'a\..\b'),
      'invalid UTF-8': [0x61, 0x62, 0xC3, 0x28, 0x65, 0x66],
    };
    for (final MapEntry(key: why, value: name) in cases.entries) {
      final sink = RecordingSink();
      final r = await _verify(at.rename(1, name), sink: sink);
      expect(refusalOf(r), ZipRefusal.unsafeName, reason: why);
      expect(sink.opened, ['ok/first'], reason: '$why: never opened');
    }
    final (twice, _) = await zipOf([
      ZipEntry('ok/first', Stream.value(const [1])),
      ZipEntry('ok/other', Stream.value(const [2])),
    ]);
    final sink = RecordingSink();
    final r = await _verify(
      Layout(twice).rename(1, utf8.encode('ok/first')),
      sink: sink,
    );
    expect(refusalOf(r), ZipRefusal.unsafeName, reason: 'repeated');
    expect(sink.opened, ['ok/first'], reason: 'the repeat is not opened');
  });

  test(
    'KP-Z5: ENOSPC from the extract sink is storageFull, at every step',
    () async {
      final (zip, _) = await _three();
      for (final step in ['open', 'add', 'flush', 'close']) {
        final sink = RecordingSink(
          fail: (name, s) {
            if (name == 'media/b.bin' && s == step) throw noSpace(name);
          },
        );
        final r = await _verify(zip, sink: sink);
        expect(refusalOf(r), ZipRefusal.storageFull, reason: step);
        expect(r.failureOrNull!.entry, 'media/b.bin', reason: step);
        expect(sink.closed, sink.opened, reason: '$step: no open target');
      }
      // Another failure to write is the caller's, rethrown as it is.
      final other = RecordingSink(
        fail: (name, s) {
          if (s == 'add') throw const FileSystemException('denied', 'x');
        },
      );
      await expectLater(
        _verify(zip, sink: other),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('KP-Z5: /dev/full through FileExtractSink is storageFull', () async {
    final (zip, _) = await _three();
    final r = await verifyZip(
      streamOf(zip),
      keepLimit: 1 << 20,
      extractWhere: (name) => name == 'media/b.bin',
      extract: FileExtractSink((_) => File('/dev/full')),
    );
    expect(refusalOf(r), ZipRefusal.storageFull);
  }, skip: File('/dev/full').existsSync() ? false : 'no /dev/full here');

  test('KP-Z6: a whole archive that is not the one expected is '
      'digestMismatch', () async {
    final (zip, summary) = await _three();
    expect((await _verify(zip, expectedSha256: summary.sha256)).isOk, isTrue);
    final r = await _verify(zip, expectedSha256: '0' * 64);
    expect(refusalOf(r), ZipRefusal.digestMismatch);
    final (other, _) = await zipOf([
      ZipEntry('a.db', Stream.value(const [1])),
    ]);
    expect(
      refusalOf(await _verify(other, expectedSha256: summary.sha256)),
      ZipRefusal.digestMismatch,
    );
  });
}

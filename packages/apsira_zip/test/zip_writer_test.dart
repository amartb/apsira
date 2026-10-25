// From relay test/data/files/backup_zip_writer_test.dart @ 09b28810, with
// LYCEUM's paused-consumer case from lyceum
// test/data/files/bundle_zip_writer_test.dart @ 9f4ff27 (its other cases are
// RELAY's, decoded there by Python's zipfile, here by `archive`). The zip
// writer (D-APK-020, RELAY ruling R-15): entries streamed from their sources through raw
// deflate, with CRC-32, data descriptors, UTF-8 names and ZIP64 records
// when a size or an offset needs them or when forced, into a stream that
// applies back-pressure. `archive` (a dev dependency) is the independent
// decoder: every test named `oracle` decodes the writer's bytes with it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:apsira_zip/apsira_zip.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';

const _kib = 1024;
const _mib = 1024 * 1024;

/// Local wall time; DOS time keeps even seconds.
final _modified = DateTime(2026, 10, 18, 12, 30, 44);

Uint8List _random(int length, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

/// Compressible bytes with some noise, like a database page file.
Uint8List _pages(int length, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(
    List.generate(length, (i) => i % 11 == 0 ? r.nextInt(256) : i ~/ 512),
  );
}

Stream<List<int>> _chunks(List<int> data, [int size = 4 * _kib]) async* {
  for (var i = 0; i < data.length; i += size) {
    yield data.sublist(i, min(i + size, data.length));
  }
}

Future<Uint8List> _collect(Stream<List<int>> s) async {
  final b = BytesBuilder(copy: false);
  await for (final c in s) {
    b.add(c);
  }
  return b.takeBytes();
}

final _manifest = utf8.encode('{"manifestVersion":1,"note":"ñandú"}');
final _db = _pages(200 * _kib, 1);
final _media = _random(5 * _kib, 2);
const _mediaName = 'media/ñandú café.bin';

List<ZipEntry> _sample() => [
  ZipEntry('relay.db', _chunks(_db), size: _db.length, sha256: true),
  ZipEntry('empty.txt', const Stream.empty()),
  ZipEntry(_mediaName, _chunks(_media, 1000)),
  ZipEntry('manifest.json', _chunks(_manifest)),
];

Map<String, List<int>> get _sampleContent => {
  'relay.db': _db,
  'empty.txt': const [],
  _mediaName: _media,
  'manifest.json': _manifest,
};

Future<(Uint8List, ZipSummary)> _zip(
  List<ZipEntry> entries, {
  bool forceZip64 = false,
  int zip32Max = zip32Limit,
}) async {
  final writer = ZipWriter(
    modified: _modified,
    forceZip64: forceZip64,
    zip32Max: zip32Max,
  );
  final bytes = await _collect(writer.write(entries));
  return (bytes, await writer.done);
}

/// The central directory as `archive` reads it.
List<ZipFileHeader> _directory(Uint8List zip) =>
    (ZipDirectory()..read(InputMemoryStream(zip))).fileHeaders;

int _u16(Uint8List b, int at) =>
    ByteData.sublistView(b).getUint16(at, Endian.little);

int _u32(Uint8List b, int at) =>
    ByteData.sublistView(b).getUint32(at, Endian.little);

/// The extra-field blocks of [extra], by id.
Map<int, Uint8List> _extras(Uint8List? extra) {
  final out = <int, Uint8List>{};
  if (extra == null) return out;
  for (var i = 0; i + 4 <= extra.length;) {
    final id = _u16(extra, i);
    final size = _u16(extra, i + 2);
    out[id] = Uint8List.sublistView(extra, i + 4, i + 4 + size);
    i += 4 + size;
  }
  return out;
}

/// Decodes [zip] with `archive` and checks every entry against [content]:
/// name and order, bytes, size, CRC-32 (recomputed by `archive`), deflate,
/// the UTF-8 flag and the modification time.
void _expectOracle(Uint8List zip, Map<String, List<int>> content) {
  final archive = ZipDecoder().decodeBytes(zip);
  expect(archive.files.map((f) => f.name), content.keys.toList());
  final headers = _directory(zip);
  for (final (i, file) in archive.files.indexed) {
    final want = content[file.name]!;
    expect(file.size, want.length, reason: file.name);
    expect(file.readBytes() ?? Uint8List(0), want, reason: file.name);
    expect(file.crc32, getCrc32(want), reason: file.name);
    expect(file.compression, CompressionType.deflate, reason: file.name);
    final header = headers[i];
    expect(header.file!.verifyCrc32(), isTrue, reason: file.name);
    expect(header.generalPurposeBitFlag, 0x0808, reason: 'descriptor, UTF-8');
    expect(header.compressionMethod, 8);
    expect(
      file.lastModDateTime,
      DateTime.utc(2026, 10, 18, 12, 30, 44),
      reason: 'DOS time holds the wall time, read back as UTC fields',
    );
  }
}

void main() {
  group('oracle', () {
    test('oracle: archive decodes every entry byte for byte', () async {
      final (zip, summary) = await _zip(_sample());
      _expectOracle(zip, _sampleContent);
      for (final h in _directory(zip)) {
        expect(h.versionNeededToExtract, 20, reason: h.filename);
        expect(h.versionMadeBy, 20, reason: h.filename);
        expect(_extras(h.extraField), isEmpty, reason: 'no ZIP64');
        expect(h.externalFileAttributes, 0);
        // The local header: no extra field, CRC and sizes zero (bit 3).
        final at = h.localHeaderOffset;
        expect(_u32(zip, at), 0x04034b50);
        expect(
          [_u32(zip, at + 14), _u32(zip, at + 18), _u32(zip, at + 22)],
          [0, 0, 0],
        );
        expect(_u16(zip, at + 28), 0, reason: 'no local extra');
      }
      expect(_u32(zip, zip.length - 22), 0x06054b50, reason: 'EOCD last');
      expect(
        _u32(zip, zip.length - 42),
        isNot(0x07064b50),
        reason: 'no ZIP64 locator',
      );
      expect(summary.length, zip.length);
      expect(summary.sha256, crypto.sha256.convert(zip).toString());
    });

    test('oracle: forced ZIP64 records decode', () async {
      final (zip, _) = await _zip(_sample(), forceZip64: true);
      _expectOracle(zip, _sampleContent);
      for (final h in _directory(zip)) {
        expect(h.versionNeededToExtract, 45, reason: h.filename);
        final zip64 = _extras(h.extraField)[1]!;
        expect(zip64.length, 24, reason: 'sizes and offset');
        final at = h.localHeaderOffset;
        expect(_u32(zip, at + 18), 0xFFFFFFFF, reason: 'local sizes in extra');
        expect(_u16(zip, at + 28), 20, reason: 'local ZIP64 extra');
        expect(_u16(zip, at + 30 + _u16(zip, at + 26)), 1);
      }
      final eocd = zip.length - 22;
      expect(_u32(zip, eocd - 20), 0x07064b50, reason: 'ZIP64 locator');
      final record = _u32(zip, eocd - 20 + 8);
      expect(_u32(zip, record), 0x06064b50, reason: 'ZIP64 end record');
      expect(_u16(zip, eocd + 10), 0xFFFF, reason: 'entries in ZIP64 record');
      expect(_u32(zip, eocd + 16), 0xFFFFFFFF, reason: 'offset in ZIP64');
    });

    test('oracle: ZIP64 records when sizes and offsets pass the limit, and '
        'only then', () async {
      // A lowered limit stands in for 4 GiB: the record layout is the same.
      final big = _random(20 * _kib, 4);
      final small = utf8.encode('small');
      final (zip, summary) = await _zip([
        ZipEntry('a.txt', _chunks(small)),
        ZipEntry('big.bin', _chunks(big), size: big.length),
        ZipEntry('later.txt', _chunks(small)),
      ], zip32Max: 4 * _kib);
      _expectOracle(zip, {'a.txt': small, 'big.bin': big, 'later.txt': small});
      final headers = _directory(zip);
      expect(headers[0].versionNeededToExtract, 20);
      expect(_extras(headers[0].extraField), isEmpty);
      expect(headers[1].versionNeededToExtract, 45);
      expect(_extras(headers[1].extraField)[1]!.length, 16, reason: 'sizes');
      expect(headers[2].versionNeededToExtract, 45);
      expect(_extras(headers[2].extraField)[1]!.length, 8, reason: 'offset');
      expect(headers[2].localHeaderOffset, greaterThan(4 * _kib));
      expect(summary.entries.map((e) => e.zip64), [false, true, false]);
      expect(_u32(zip, zip.length - 42), 0x07064b50, reason: 'CD offset');
    });

    test('oracle: an empty zip and a zip of 65,535 entries', () async {
      final (empty, _) = await _zip(const []);
      expect(empty.length, 22);
      expect(ZipDecoder().decodeBytes(empty).files, isEmpty);

      const count = 0xFFFF;
      final (zip, _) = await _zip([
        for (var i = 0; i < count; i++)
          ZipEntry('n/$i', Stream.value(utf8.encode('$i'))),
      ]);
      final archive = ZipDecoder().decodeBytes(zip);
      expect(archive.files.length, count);
      expect(utf8.decode(archive.files.last.readBytes()!), '${count - 1}');
      final eocd = zip.length - 22;
      expect(_u16(zip, eocd + 10), 0xFFFF);
      expect(_u32(zip, eocd - 20), 0x07064b50, reason: 'count needs ZIP64');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('streaming', () {
    test('a 256 MiB entry streams with back-pressure: memory within a few '
        'chunks', () async {
      // Not compressed, so the zip's bytes track the source's.
      final block = _random(64 * _kib, 5);
      const blocks = 256 * _mib ~/ (64 * _kib);
      var pulled = 0;
      final expectedCrc = Crc32();
      Stream<List<int>> source() async* {
        for (var i = 0; i < blocks; i++) {
          pulled += block.length;
          expectedCrc.add(block);
          yield block;
        }
      }

      final rssBefore = ProcessInfo.currentRss;
      var rssMax = rssBefore;
      // zlib level 0 (stored deflate blocks): the same streaming, without
      // 9 s of compressing random bytes.
      final writer = ZipWriter(modified: _modified, level: 0);
      final entry = ZipEntry('relay.db', source(), size: blocks * block.length);
      var delivered = 0;
      var maxInFlight = 0;
      var n = 0;
      await for (final chunk in writer.write([entry])) {
        delivered += chunk.length;
        maxInFlight = max(maxInFlight, pulled - delivered);
        if (++n % 64 == 0) {
          rssMax = max(rssMax, ProcessInfo.currentRss);
        }
        // A slow consumer, as the SAF sink is.
        await Future<void>.delayed(Duration.zero);
      }
      final info = await entry.written;
      expect(info.size, 256 * _mib);
      expect(info.crc32, expectedCrc.value);
      expect(info.zip64, isFalse);
      expect(
        maxInFlight,
        lessThanOrEqualTo(1 * _mib),
        reason: 'at most 16 chunks of 64 KiB read ahead of the consumer',
      );
      expect(
        rssMax - rssBefore,
        lessThan(96 * _mib),
        reason: 'the 256 MiB entry is never held in memory',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a paused zip stops reading its source', () async {
      var pulled = 0;
      final block = _random(64 * _kib, 8);
      Stream<List<int>> source() async* {
        for (var i = 0; i < 200; i++) {
          pulled++;
          yield block;
        }
      }

      final writer = ZipWriter(modified: _modified);
      final done = Completer<void>();
      late StreamSubscription<List<int>> sub;
      var paused = false;
      sub = writer.write([ZipEntry('a', source())]).listen((_) {
        if (!paused) {
          paused = true;
          sub.pause();
        }
      }, onDone: done.complete);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final atPause = pulled;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(pulled, atPause, reason: 'nothing read while paused');
      expect(pulled, lessThan(8));
      sub.resume();
      await done.future;
      await sub.cancel();
      expect(pulled, 200);
    });

    test('a paused consumer stops the reads: the writer holds at most one '
        'chunk per entry ahead of it', () async {
      // Stored deflate (level 0), so every source chunk becomes output.
      const chunk = 64 * _kib;
      const blocks = 64;
      final block = _random(chunk, 5);
      var pulled = 0;
      Stream<List<int>> source() async* {
        for (var i = 0; i < blocks; i++) {
          pulled++;
          yield block;
        }
      }

      final writer = ZipWriter(modified: _modified, level: 0);
      var delivered = 0;
      var aheadMax = 0;
      final done = Completer<void>();
      late StreamSubscription<List<int>> sub;
      final ahead = <int>[];
      sub = writer.write([ZipEntry('lyceum.json', source())]).listen((bytes) {
        delivered += bytes.length;
        // Source bytes read beyond the zip bytes that have arrived (the
        // zip's headers only make the zip longer than its source).
        final a = pulled * chunk - delivered;
        aheadMax = max(aheadMax, a);
        sub.pause();
        // A slow consumer, as the SAF sink is: while it holds the
        // chunk, the source must not be read.
        final atPause = pulled;
        Future<void>.delayed(const Duration(milliseconds: 2), () {
          ahead.add(pulled - atPause);
          sub.resume();
        });
      }, onDone: done.complete);
      await done.future;
      await sub.cancel();
      expect(pulled, blocks);
      expect(ahead, everyElement(0), reason: 'nothing read while paused');
      expect(
        aheadMax,
        lessThanOrEqualTo(chunk),
        reason: 'at most one chunk read ahead of the consumer',
      );
    });

    test('cancelling the zip cancels the source at its next chunk', () async {
      final cancelled = Completer<void>();
      var pulled = 0;
      Stream<List<int>> source() async* {
        try {
          for (;;) {
            pulled++;
            yield _random(4 * _kib, pulled);
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
        } finally {
          cancelled.complete();
        }
      }

      final writer = ZipWriter(modified: _modified, chunkSize: 1);
      final sub = writer.write([ZipEntry('a', source())]).listen(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      await cancelled.future.timeout(const Duration(seconds: 5));
      final atCancel = pulled;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(pulled, atCancel);
      await expectLater(writer.done, throwsStateError);
    });

    test('an error from a source ends the zip with that error', () async {
      final writer = ZipWriter(modified: _modified);
      final entry = ZipEntry(
        'a',
        Stream<List<int>>.error(const FileSystemException('gone')),
      );
      await expectLater(
        _collect(writer.write([entry])),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(entry.written, throwsA(isA<FileSystemException>()));
      await expectLater(writer.done, throwsA(isA<FileSystemException>()));
    });

    test('written reports each entry once it is zipped, so a later entry can '
        'name its checksum', () async {
      final db = ZipEntry(
        'relay.db',
        _chunks(_db),
        size: _db.length,
        sha256: true,
      );
      final manifest = ZipEntry(
        'manifest.json',
        Stream.fromFuture(db.written.then((info) => utf8.encode(info.sha256!))),
      );
      final (zip, summary) = await _zip([db, manifest]);
      final info = await db.written;
      expect(info.name, 'relay.db');
      expect(info.size, _db.length);
      expect(info.crc32, getCrc32(_db));
      expect(info.sha256, crypto.sha256.convert(_db).toString());
      expect(info.offset, 0);
      expect((await manifest.written).sha256, isNull, reason: 'not asked');
      _expectOracle(zip, {
        'relay.db': _db,
        'manifest.json': utf8.encode(crypto.sha256.convert(_db).toString()),
      });
      expect(summary.entries.map((e) => e.name), ['relay.db', 'manifest.json']);
      expect(summary.entries[1].offset, greaterThan(0));
    });

    test('the output comes in chunks of about the chunk size', () async {
      final writer = ZipWriter(modified: _modified, chunkSize: 16 * _kib);
      final sizes = <int>[];
      await for (final c in writer.write(_sample())) {
        sizes.add(c.length);
      }
      expect(sizes.length, greaterThan(1));
      for (final s in sizes.take(sizes.length - 1)) {
        expect(s, greaterThanOrEqualTo(16 * _kib));
        expect(s, lessThan(16 * _kib + 128 * _kib));
      }
    });
  });

  group('refusals', () {
    test('a declared size that is not the bytes fails the zip', () async {
      for (final size in [_db.length - 1, _db.length + 1]) {
        final writer = ZipWriter(modified: _modified);
        await expectLater(
          _collect(
            writer.write([ZipEntry('relay.db', _chunks(_db), size: size)]),
          ),
          throwsA(isA<StateError>()),
        );
      }
    });

    test('an undeclared entry past the limit fails instead of writing sizes '
        'it cannot hold', () async {
      final writer = ZipWriter(modified: _modified, zip32Max: 4 * _kib);
      await expectLater(
        _collect(
          writer.write([ZipEntry('big', _chunks(_random(8 * _kib, 7)))]),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('names that are not plain relative UTF-8 paths are refused before '
        'anything is read', () {
      for (final name in [
        '',
        '/abs',
        'a/../b',
        '..',
        './a',
        'a//b',
        'dir/',
        r'a\b',
        'nul\u0000',
        'x' * 0x10000,
      ]) {
        final writer = ZipWriter(modified: _modified);
        expect(
          () => writer.write([ZipEntry(name, const Stream.empty())]),
          throwsArgumentError,
          reason: name.length > 20 ? 'long' : name,
        );
      }
      expect(
        () => ZipWriter(modified: _modified).write([
          ZipEntry('a', const Stream.empty()),
          ZipEntry('a', const Stream.empty()),
        ]),
        throwsArgumentError,
        reason: 'duplicate',
      );
    });

    test('a writer writes one zip', () {
      final writer = ZipWriter(modified: _modified);
      writer.write(const []);
      expect(() => writer.write(const []), throwsStateError);
    });
  });

  test('DOS time: even seconds; before 1980 is 1980-01-01', () async {
    for (final (at, want) in [
      (DateTime(2026, 1, 2, 3, 4, 5), DateTime.utc(2026, 1, 2, 3, 4, 4)),
      (DateTime(1979, 12, 31, 23, 59, 59), DateTime.utc(1980)),
      (
        DateTime(2107, 12, 31, 23, 59, 58),
        DateTime.utc(2107, 12, 31, 23, 59, 58),
      ),
    ]) {
      final writer = ZipWriter(modified: at);
      final zip = await _collect(
        writer.write([
          ZipEntry('a', Stream.value(const [1])),
        ]),
      );
      expect(
        ZipDecoder().decodeBytes(zip).files.single.lastModDateTime,
        want,
        reason: '$at',
      );
    }
  });
}

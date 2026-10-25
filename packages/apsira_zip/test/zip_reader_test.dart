// From relay test/data/files/backup_zip_reader_test.dart @ 09b28810. The zip
// verifier (D-APK-020, RELAY ruling R-15): one pass over a stream checks every local
// header, inflates every entry, checks its CRC-32 and sizes against its
// data descriptor, hashes the entries it is asked to, and checks the
// central directory and the end records against what it read; anything
// else fails with a ZipRefusal, never an exception. The codes asserted are
// RELAY's ZipCode names, which ZipRefused carries unchanged.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_zip/apsira_zip.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';

const _kib = 1024;
const _mib = 1024 * 1024;

final _modified = DateTime(2026, 10, 18, 12, 30, 44);

Uint8List _random(int length, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

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

List<ZipEntry> _sample({int db = 200 * _kib}) => [
  ZipEntry('relay.db', _chunks(_pages(db, 1)), size: db, sha256: true),
  ZipEntry('empty.txt', const Stream.empty()),
  ZipEntry('media/ñandú café.bin', _chunks(_random(db ~/ 40, 2), 1000)),
  ZipEntry('manifest.json', _chunks(_manifest)),
];

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

/// [bytes] as a single-subscription stream cut into [cuts]-sized chunks
/// (cycled), counting its listeners in [listens].
Stream<List<int>> _stream(
  Uint8List bytes, {
  List<int> cuts = const [64 * _kib],
  List<int>? listens,
}) {
  late StreamController<List<int>> c;
  c = StreamController<List<int>>(
    onListen: () async {
      listens?.add(1);
      var i = 0;
      for (var at = 0; at < bytes.length; i++) {
        final end = min(at + cuts[i % cuts.length], bytes.length);
        c.add(Uint8List.sublistView(bytes, at, end));
        at = end;
        if (i % 64 == 0) await Future<void>.delayed(Duration.zero);
      }
      await c.close();
    },
  );
  return c.stream;
}

Future<Result<ZipContents, ZipRefused>> _verify(
  Uint8List zip, {
  Set<String> sha256Of = const {},
  Set<String> keep = const {},
  int keepLimit = 1 << 20,
  String? expectedSha256,
}) => verifyZip(
  _stream(zip),
  sha256Where: sha256Of.contains,
  keep: keep,
  keepLimit: keepLimit,
  expectedSha256: expectedSha256,
);

String? _code(Result<ZipContents, ZipRefused> r) => r.failureOrNull?.code;

int _u16(Uint8List b, int at) =>
    ByteData.sublistView(b).getUint16(at, Endian.little);

int _u32(Uint8List b, int at) =>
    ByteData.sublistView(b).getUint32(at, Endian.little);

void _put32(Uint8List b, int at, int v) =>
    ByteData.sublistView(b).setUint32(at, v, Endian.little);

void _put16(Uint8List b, int at, int v) =>
    ByteData.sublistView(b).setUint16(at, v, Endian.little);

/// Where things are in a zip without ZIP64: each central header's offset,
/// with its entry's local header, data and descriptor offsets.
final class _Layout {
  _Layout(this.zip) {
    final eocd = zip.length - 22;
    cdOffset = _u32(zip, eocd + 16);
    var at = cdOffset;
    for (var i = 0; i < _u16(zip, eocd + 10); i++) {
      central.add(at);
      final local = _u32(zip, at + 42);
      locals.add(local);
      final data = local + 30 + _u16(zip, local + 26) + _u16(zip, local + 28);
      descriptors.add(data + _u32(zip, at + 20));
      at += 46 + _u16(zip, at + 28) + _u16(zip, at + 30) + _u16(zip, at + 32);
    }
  }

  final Uint8List zip;
  late final int cdOffset;
  final central = <int>[];
  final locals = <int>[];
  final descriptors = <int>[];

  int get eocd => zip.length - 22;
}

void main() {
  group('a zip the writer wrote', () {
    test('verifies in one pass, however the stream is cut', () async {
      final (zip, summary) = await _zip(_sample());
      for (final cuts in [
        [zip.length],
        [1],
        [7, 3, 4096, 1, 65536],
        [64 * _kib],
      ]) {
        final listens = <int>[];
        final result = await verifyZip(
          _stream(zip, cuts: cuts, listens: listens),
          keepLimit: 1 << 20,
          sha256Where: {'relay.db'}.contains,
          keep: {'manifest.json'},
        );
        final contents = result.valueOrNull!;
        expect(listens, [1], reason: 'one listen, one pass');
        expect(contents.length, zip.length);
        expect(contents.sha256, summary.sha256);
        expect(
          [
            for (final e in contents.entries)
              (e.name, e.size, e.compressedSize, e.crc32, e.offset, e.zip64),
          ],
          [
            for (final e in summary.entries)
              (e.name, e.size, e.compressedSize, e.crc32, e.offset, e.zip64),
          ],
          reason: '$cuts',
        );
        expect(contents.entry('relay.db')!.sha256, summary.entries[0].sha256);
        expect(
          contents.entry('relay.db')!.sha256,
          crypto.sha256.convert(_pages(200 * _kib, 1)).toString(),
        );
        expect(
          contents.entry('empty.txt')!.sha256,
          isNull,
          reason: 'not asked',
        );
        expect(contents.kept.keys, ['manifest.json']);
        expect(contents.kept['manifest.json'], _manifest);
      }
    });

    test('forced and needed ZIP64 zips verify', () async {
      final (forced, s1) = await _zip(_sample(), forceZip64: true);
      final r1 = await _verify(forced, expectedSha256: s1.sha256);
      expect(r1.valueOrNull!.entries.map((e) => e.zip64), everyElement(isTrue));

      final big = _random(20 * _kib, 4);
      final (needed, s2) = await _zip([
        ZipEntry('a.txt', Stream.value(utf8.encode('small'))),
        ZipEntry('big.bin', _chunks(big), size: big.length, sha256: true),
        ZipEntry('later.txt', Stream.value(utf8.encode('small'))),
      ], zip32Max: 4 * _kib);
      final r2 = await _verify(needed, sha256Of: {'big.bin'});
      final c2 = r2.valueOrNull!;
      expect(c2.entries.map((e) => e.zip64), [false, true, false]);
      expect(c2.entry('big.bin')!.sha256, s2.entries[1].sha256);
      expect(c2.entry('later.txt')!.offset, greaterThan(4 * _kib));
    });

    test('an empty zip verifies', () async {
      final (zip, _) = await _zip(const []);
      expect((await _verify(zip)).valueOrNull!.entries, isEmpty);
      final (zip64, _) = await _zip(const [], forceZip64: true);
      expect((await _verify(zip64)).valueOrNull!.entries, isEmpty);
    });

    test('a 64 MiB backup streams from the writer into the reader', () async {
      final block = _random(64 * _kib, 9);
      Stream<List<int>> source() async* {
        for (var i = 0; i < 1024; i++) {
          yield block;
        }
      }

      final writer = ZipWriter(modified: _modified, level: 0);
      final entry = ZipEntry(
        'relay.db',
        source(),
        size: 64 * _mib,
        sha256: true,
      );
      final result = await verifyZip(
        writer.write([entry]),
        keepLimit: 1 << 20,
        sha256Where: {'relay.db'}.contains,
      );
      final summary = await writer.done;
      expect(result.valueOrNull!.sha256, summary.sha256);
      expect(
        result.valueOrNull!.entry('relay.db')!.sha256,
        summary.entries[0].sha256,
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('fails with a code', () {
    test('every flipped byte outside the deflate data, and every one inside '
        'it that changes what it inflates to', () async {
      final entries = _sample(db: 3 * _kib);
      final (zip, summary) = await _zip(entries);
      final names = {for (final e in summary.entries) e.name};
      final want = (await _verify(zip, sha256Of: names)).valueOrNull!.entries;
      // dart:io's inflater does not say where a deflate stream ends, and
      // deflate has bits that do not change the output (a final-block
      // flag, padding, some table bits): a flip there inflates to the same
      // bytes. Only the expected sha256 (next test) catches those.
      bool inData(int i) => summary.entries.any((e) {
        final start =
            e.offset + 30 + utf8.encode(e.name).length + (e.zip64 ? 20 : 0);
        return i >= start && i < start + e.compressedSize;
      });
      final seen = <String>{};
      final same = <int>[];
      for (var i = 0; i < zip.length; i++) {
        final bad = Uint8List.fromList(zip)..[i] ^= 0xFF;
        final result = await _verify(bad, sha256Of: names);
        switch (result) {
          case Err(:final failure):
            seen.add(failure.code);
          case Ok(:final value):
            expect(inData(i), isTrue, reason: 'byte $i is not deflate data');
            expect(
              [for (final e in value.entries) (e.name, e.size, e.sha256)],
              [for (final e in want) (e.name, e.size, e.sha256)],
              reason: 'byte $i: the same content, or a failure',
            );
            same.add(i);
        }
      }
      expect(same.length, lessThan(zip.length ~/ 100), reason: '$same');
      expect(
        seen,
        containsAll([
          'zipCorrupt',
          'zipCrcMismatch',
          'zipDirectoryMismatch',
          'zipTruncated',
        ]),
      );
    });

    test('with the expected sha256, every flipped bit', () async {
      final (zip, summary) = await _zip(_sample(db: 2 * _kib));
      for (var i = 0; i < zip.length; i++) {
        for (var bit = 0; bit < 8; bit++) {
          final bad = Uint8List.fromList(zip)..[i] ^= 1 << bit;
          final result = await _verify(bad, expectedSha256: summary.sha256);
          expect(result.isErr, isTrue, reason: 'byte $i bit $bit');
        }
      }
      final other = '0' * 64;
      expect(
        _code(await _verify(zip, expectedSha256: other)),
        'zipDigestMismatch',
      );
    });

    test('every truncation is zipTruncated; trailing bytes are '
        'zipCorrupt', () async {
      final (zip, _) = await _zip(_sample(db: 3 * _kib));
      for (var n = 0; n < zip.length; n++) {
        final cut = Uint8List.sublistView(zip, 0, n);
        expect(_code(await _verify(cut)), 'zipTruncated', reason: '$n bytes');
      }
      final (forced, _) = await _zip(_sample(db: 1 * _kib), forceZip64: true);
      for (var n = forced.length - 120; n < forced.length; n++) {
        final cut = Uint8List.sublistView(forced, 0, n);
        expect(_code(await _verify(cut)), 'zipTruncated', reason: 'ZIP64 $n');
      }
      expect(
        _code(await _verify(Uint8List.fromList([...zip, 0]))),
        'zipCorrupt',
      );
    });

    test('data that is not its CRC-32 or its size', () async {
      final (zip, _) = await _zip(_sample(db: 3 * _kib));
      final at = _Layout(zip);
      // The same wrong CRC in the descriptor and the central directory:
      // only the data disagrees with it.
      final crc = Uint8List.fromList(zip);
      _put32(crc, at.descriptors[0] + 4, _u32(zip, at.descriptors[0] + 4) ^ 1);
      _put32(crc, at.central[0] + 16, _u32(zip, at.central[0] + 16) ^ 1);
      expect(_code(await _verify(crc)), 'zipCrcMismatch');

      final size = Uint8List.fromList(zip);
      _put32(size, at.descriptors[0] + 12, 3 * _kib + 1);
      _put32(size, at.central[0] + 24, 3 * _kib + 1);
      expect(_code(await _verify(size)), 'zipSizeMismatch');
    });

    test('a central directory that disagrees with the entries', () async {
      final (zip, _) = await _zip(_sample(db: 3 * _kib));
      final at = _Layout(zip);
      Future<String?> patched(void Function(Uint8List) patch) async =>
          _code(await _verify(Uint8List.fromList(zip)..apply(patch)));

      final cd = at.central[1];
      final cases = <String, void Function(Uint8List)>{
        'crc': (b) => _put32(b, cd + 16, _u32(b, cd + 16) + 1),
        'compressed size': (b) => _put32(b, cd + 20, _u32(b, cd + 20) + 1),
        'size': (b) => _put32(b, cd + 24, _u32(b, cd + 24) + 1),
        'name': (b) => b[cd + 46] ^= 0x01,
        'offset': (b) => _put32(b, cd + 42, _u32(b, cd + 42) + 1),
        'time': (b) => _put16(b, cd + 12, _u16(b, cd + 12) + 1),
        'method': (b) => _put16(b, cd + 10, 0),
        'attributes': (b) => _put32(b, cd + 38, 0x81A40000),
        'local time': (b) => _put16(b, at.locals[1] + 10, 0),
        'entry count': (b) {
          _put16(b, at.eocd + 8, 3);
          _put16(b, at.eocd + 10, 3);
        },
        'directory size': (b) =>
            _put32(b, at.eocd + 12, _u32(b, at.eocd + 12) - 1),
        'directory offset': (b) =>
            _put32(b, at.eocd + 16, _u32(b, at.eocd + 16) + 1),
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        expect(await patched(value), 'zipDirectoryMismatch', reason: key);
      }

      // A directory that leaves out the last entry, its end record fixed.
      final last = at.central[3];
      final dropped = Uint8List.fromList([
        ...zip.sublist(0, last),
        ...zip.sublist(at.eocd),
      ]);
      final eocd = dropped.length - 22;
      _put16(dropped, eocd + 8, 3);
      _put16(dropped, eocd + 10, 3);
      _put32(dropped, eocd + 12, last - at.cdOffset);
      expect(_code(await _verify(dropped)), 'zipDirectoryMismatch');
    });

    test('an unsafe, repeated or non-UTF-8 name', () async {
      final (zip, _) = await _zip([
        ZipEntry('ab/cd', Stream.value(const [1])),
        ZipEntry('ab/ce', Stream.value(const [2])),
      ]);
      final at = _Layout(zip);
      Uint8List rename(int entry, List<int> name) {
        final b = Uint8List.fromList(zip);
        b.setRange(at.locals[entry] + 30, at.locals[entry] + 35, name);
        b.setRange(at.central[entry] + 46, at.central[entry] + 51, name);
        return b;
      }

      for (final name in ['../cd', '/b/cd', 'ab/./', r'ab\cd', 'ab/ce']) {
        expect(
          _code(await _verify(rename(0, utf8.encode(name)))),
          'zipUnsafeName',
          reason: name,
        );
      }
      expect(
        _code(await _verify(rename(0, [0x61, 0x62, 0x2F, 0xFF, 0x64]))),
        'zipUnsafeName',
        reason: 'not UTF-8',
      );
    });

    test('a kept entry over its limit', () async {
      final (zip, _) = await _zip(_sample(db: 3 * _kib));
      final r = await _verify(zip, keep: {'manifest.json'}, keepLimit: 10);
      expect(_code(r), 'zipEntryTooLarge');
    });

    test("a zip outside Relay's profile", () async {
      final other = ZipEncoder().encodeBytes(
        Archive()..add(ArchiveFile.bytes('a.txt', utf8.encode('hello'))),
      );
      expect(_code(await _verify(other)), 'zipCorrupt');
      expect(
        _code(await _verify(Uint8List.fromList(utf8.encode('not a zip')))),
        'zipCorrupt',
      );
    });
  });

  test('an error of the stream is rethrown, not a code', () async {
    final (zip, _) = await _zip(_sample(db: 3 * _kib));
    Stream<List<int>> failing() async* {
      yield zip.sublist(0, 100);
      throw const FileSystemException('folder gone');
    }

    await expectLater(
      verifyZip(failing(), keepLimit: 1 << 20),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('codes are message keys', () {
    for (final r in ZipRefusal.values) {
      expect(Failure.isValidCode(r.code), isTrue, reason: r.code);
      final f = ZipRefused(r);
      expect(f.code, r.code);
      expect(f, ZipRefused(r));
      expect(f, isNot(Failure(r.code)));
      expect(f, isNot(ZipRefused(r, entry: 'a')));
      expect('${ZipRefused(r, entry: 'secret')}', isNot(contains('secret')));
    }
  });
}

extension on Uint8List {
  void apply(void Function(Uint8List) patch) => patch(this);
}

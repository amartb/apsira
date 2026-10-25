// From lyceum test/data/files/crc32_test.dart @ 9f4ff27, with RELAY's
// `crc32` group from relay test/data/files/backup_zip_writer_test.dart @
// 09b28810: the standard check vectors, chunked input equal to one call,
// List<int> input taken modulo 256, and `archive`'s CRC as the oracle. The
// zip writer and reader sum every entry with it, chunk by chunk.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:apsira_zip/apsira_zip.dart';
import 'package:archive/archive.dart';
import 'package:test/test.dart';

/// A plain bit-at-a-time CRC-32 (reflected 0xEDB88320), independent of the
/// sliced tables under test.
int _reference(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b & 0xff;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

void main() {
  test('the standard check vectors', () {
    expect(Crc32.of(ascii.encode('123456789')), 0xCBF43926);
    expect(Crc32.of(const []), 0);
    expect(Crc32.of(ascii.encode('a')), 0xE8B7BE43);
    expect(
      Crc32.of(ascii.encode('The quick brown fox jumps over the lazy dog')),
      0x414FA339,
    );
  });

  test('chunks of any length sum to the one-call value', () {
    final r = Random(3);
    final data = Uint8List.fromList(
      List.generate(100003, (_) => r.nextInt(256)),
    );
    for (final step in [1, 7, 8, 9, 777, 65536]) {
      final crc = Crc32();
      for (var i = 0; i < data.length; i += step) {
        crc.add(Uint8List.sublistView(data, i, min(i + step, data.length)));
      }
      expect(crc.value, _reference(data), reason: 'step $step');
    }
  });

  test('a List<int> is taken modulo 256, as a Uint8List would hold it', () {
    expect(
      Crc32.of([0x131, -1, 0x39]),
      Crc32.of(Uint8List.fromList([0x31, 0xff, 0x39])),
    );
    expect(
      Crc32.of(List<int>.generate(300, (i) => i)),
      _reference(List<int>.generate(300, (i) => i & 0xff)),
    );
  });

  test('the zip CRC-32: check value and the oracle on odd chunks', () {
    expect(Crc32.of(ascii.encode('123456789')), 0xCBF43926);
    expect(crc32(ascii.encode('123456789')), 0xCBF43926);
    expect(Crc32.of(const []), 0);
    final r = Random(3);
    final data = Uint8List.fromList(
      List.generate(100003, (_) => r.nextInt(256)),
    );
    final crc = Crc32();
    for (var i = 0; i < data.length; i += 777) {
      crc.add(data.sublist(i, min(i + 777, data.length)));
    }
    expect(crc.value, getCrc32(data));
    expect(Crc32.of(data.toList()), getCrc32(data), reason: 'a List<int>');
  });
}

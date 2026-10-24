// From relay lib/data/files/crc32.dart @ 09b28810
/// CRC-32 as zip files use it (APPNOTE 4.4.7): the IEEE 802.3 polynomial
/// 0x04C11DB7, reflected (0xEDB88320), initial value and final XOR
/// 0xFFFFFFFF. The check value of `123456789` is 0xCBF43926.
///
/// The zip writer and reader (D-APK-020; RELAY ruling R-15) feed it chunk
/// by chunk, so an entry of any size is summed without being held in
/// memory. It uses slicing by 8 (eight 256-entry tables, one 8-byte step
/// per loop), about three times the speed of the byte-at-a-time table on
/// the Dart VM.
library;

import 'dart:typed_data';

/// The CRC-32 of [bytes] in one call ([Crc32.of]).
int crc32(List<int> bytes) => Crc32.of(bytes);

/// A running CRC-32: [add] chunks in order, then read [value].
final class Crc32 {
  int _crc = 0xFFFFFFFF;

  /// The CRC-32 of [bytes] in one call.
  static int of(List<int> bytes) => (Crc32()..add(bytes)).value;

  /// The CRC-32 of everything added so far, as an unsigned 32-bit value.
  int get value => _crc ^ 0xFFFFFFFF;

  /// Adds [bytes] (each taken modulo 256 when not a [Uint8List]).
  void add(List<int> bytes) {
    final b = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final t = _tables;
    var c = _crc;
    var i = 0;
    final last8 = b.length - 8;
    while (i <= last8) {
      final lo = c ^ (b[i] | b[i + 1] << 8 | b[i + 2] << 16 | b[i + 3] << 24);
      c =
          t[0x700 | (lo & 0xff)] ^
          t[0x600 | ((lo >>> 8) & 0xff)] ^
          t[0x500 | ((lo >>> 16) & 0xff)] ^
          t[0x400 | (lo >>> 24)] ^
          t[0x300 | b[i + 4]] ^
          t[0x200 | b[i + 5]] ^
          t[0x100 | b[i + 6]] ^
          t[b[i + 7]];
      i += 8;
    }
    for (; i < b.length; i++) {
      c = t[(c ^ b[i]) & 0xff] ^ (c >>> 8);
    }
    _crc = c;
  }
}

/// Table `k` (entries `k * 256 …`) advances the CRC of a byte by `k` more
/// zero bytes; table 0 is the classic byte-at-a-time table.
final Uint32List _tables = () {
  final t = Uint32List(256 * 8);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    t[n] = c;
  }
  for (var n = 0; n < 256; n++) {
    var c = t[n];
    for (var k = 1; k < 8; k++) {
      c = t[c & 0xff] ^ (c >>> 8);
      t[k * 256 + n] = c;
    }
  }
  return t;
}();

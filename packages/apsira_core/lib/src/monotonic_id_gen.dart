// From relay lib/data/platform/uuid_id_gen.dart @ 09b28810
/// UUIDv7 (D-014) from a secure random source and the injected [Clock],
/// without the `uuid` package: the 16 bytes are laid out here.
library;

import 'dart:math';

import 'clock.dart';
import 'id_gen.dart';

/// UUIDs strictly increasing within a process (RFC 9562 §6.2, method 1):
/// the 12 `rand_a` bits are a counter, seeded at random each millisecond and
/// incremented within one; a clock that steps back keeps the last
/// timestamp, and a counter overflow borrows the next millisecond.
///
/// The random draws are RELAY's, in RELAY's order, so a seeded [Random]
/// gives RELAY's exact identifiers.
final class MonotonicIdGen implements IdGen {
  MonotonicIdGen(this._clock, {Random? random})
    : _random = random ?? Random.secure();

  final Clock _clock;
  final Random _random;

  static const _counterMax = 0xFFF;

  /// Seeds leave half the counter's range free for same-millisecond IDs.
  static const _counterSeedRange = 0x800;

  int _lastMs = -1;
  int _counter = 0;

  @override
  String uuid() {
    final ms = _clock.nowUtc().millisecondsSinceEpoch;
    if (ms > _lastMs) {
      _lastMs = ms;
      _counter = _random.nextInt(_counterSeedRange);
    } else if (_counter < _counterMax) {
      _counter++;
    } else {
      _lastMs++;
      _counter = _random.nextInt(_counterSeedRange);
    }
    final tail = List<int>.generate(10, (_) => _random.nextInt(256));
    final bytes = [
      // 48-bit big-endian Unix milliseconds.
      for (var shift = 40; shift >= 0; shift -= 8) (_lastMs >> shift) & 0xFF,
      // Bytes 6–7: the version nibble, then the 12-bit counter.
      0x70 | ((_counter >> 8) & 0x0F),
      _counter & 0xFF,
      // Byte 8: the RFC variant (0b10), then 62 random bits.
      0x80 | (tail[2] & 0x3F),
      ...tail.sublist(3),
    ];
    return _format(bytes);
  }

  /// Lowercase canonical form: 8-4-4-4-12 hex digits.
  static String _format(List<int> bytes) {
    final hex = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) hex.write('-');
      hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return hex.toString();
  }
}

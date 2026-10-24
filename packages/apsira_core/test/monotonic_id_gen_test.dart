// From relay test/data/platform/uuid_id_gen_test.dart @ 09b28810 (the
// UuidIdGen.uuid group), with FakeClock in place of RELAY's SystemClock; the
// blockId and FakeIdGen groups stay in RELAY with block IDs. The groups after
// it pin AC-2.1: overflow, the counter's bytes and RELAY's exact output.
import 'dart:math';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:test/test.dart';

final _uuidV7 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

int _timestampMs(String uuid) =>
    int.parse(uuid.replaceAll('-', '').substring(0, 12), radix: 16);

/// The 12 `rand_a` bits: byte 6's low nibble and byte 7.
int _counter(String uuid) =>
    int.parse(uuid.replaceAll('-', '').substring(13, 16), radix: 16);

void _expectStrictlyIncreasing(List<String> ids) {
  for (var i = 1; i < ids.length; i++) {
    expect(
      ids[i].compareTo(ids[i - 1]),
      greaterThan(0),
      reason: '${ids[i - 1]} then ${ids[i]}',
    );
  }
}

/// A random source that always draws 0: every counter seed is 0 and every
/// random byte is 0x00, so a test can name each bit of an ID.
final class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void main() {
  group('MonotonicIdGen.uuid (D-014)', () {
    test('is a UUIDv7: version 7, RFC variant, lowercase canonical form', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 17));
      final ids = MonotonicIdGen(clock);
      for (var i = 0; i < 200; i++) {
        expect(ids.uuid(), matches(_uuidV7));
        clock.advance(const Duration(microseconds: 300));
      }
    });

    test('carries the clock instant in its 48-bit timestamp', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 17, 9, 15, 30, 123));
      final ids = MonotonicIdGen(clock);
      expect(_timestampMs(ids.uuid()), clock.nowUtc().millisecondsSinceEpoch);
    });

    test('is time-ordered as the clock advances', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 17));
      final ids = MonotonicIdGen(clock);
      final out = <String>[];
      for (var i = 0; i < 50; i++) {
        out.add(ids.uuid());
        clock.advance(const Duration(milliseconds: 1));
      }
      _expectStrictlyIncreasing(out);
    });

    test('stays strictly increasing within one millisecond and when the clock steps back', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 17));
      final ids = MonotonicIdGen(clock, random: Random(7));
      final out = [for (var i = 0; i < 5000; i++) ids.uuid()];
      clock.advance(const Duration(seconds: -5));
      out.addAll([for (var i = 0; i < 10; i++) ids.uuid()]);
      _expectStrictlyIncreasing(out);
      expect(out.toSet(), hasLength(out.length));
    });
  });

  group('MonotonicIdGen, RFC 9562 §6.2 method 1 (AC-2.1)', () {
    test('(a) 10 000 ids under a frozen clock are strictly increasing', () {
      final ids = MonotonicIdGen(FakeClock(DateTime.utc(2026, 10, 24)));
      final out = [for (var i = 0; i < 10000; i++) ids.uuid()];
      _expectStrictlyIncreasing(out);
      expect(out, everyElement(matches(_uuidV7)));
    });

    test('(b) a clock stepped back 5 s keeps the last timestamp', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 24));
      final ids = MonotonicIdGen(clock, random: _ZeroRandom());
      final before = ids.uuid();
      clock.advance(const Duration(seconds: -5));
      final after = ids.uuid();
      expect(after.compareTo(before), greaterThan(0));
      expect(_timestampMs(after), _timestampMs(before));
      expect(_counter(after), _counter(before) + 1);
    });

    test(
      '(c) 4 096 + 1 ids in one millisecond borrow the next millisecond',
      () {
        final clock = FakeClock(DateTime.utc(2026, 10, 24));
        final ms = clock.nowUtc().millisecondsSinceEpoch;
        final ids = MonotonicIdGen(clock, random: _ZeroRandom());
        final out = [for (var i = 0; i < 4097; i++) ids.uuid()];
        expect(out.take(4096).map(_timestampMs), everyElement(ms));
        expect(_counter(out[4095]), 0xFFF);
        expect(_timestampMs(out[4096]), ms + 1);
        expect(_counter(out[4096]), 0);
        _expectStrictlyIncreasing(out);
        // The borrowed millisecond is the last one: the clock's own next
        // reading of it continues the counter.
        clock.advance(const Duration(milliseconds: 1));
        expect(_timestampMs(ids.uuid()), ms + 1);
      },
    );

    test('(c) a seed leaves at least half the counter for one millisecond', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 24));
      final ms = clock.nowUtc().millisecondsSinceEpoch;
      for (var seed = 0; seed < 50; seed++) {
        final ids = MonotonicIdGen(clock, random: Random(seed));
        final out = [for (var i = 0; i < 2048; i++) ids.uuid()];
        expect(out.map(_timestampMs), everyElement(ms), reason: 'seed $seed');
        expect(_counter(out.first), lessThan(0x800), reason: 'seed $seed');
      }
    });

    test('(d) each id is version 7 with the RFC variant', () {
      final ids = MonotonicIdGen(FakeClock(DateTime.utc(2026, 10, 24)));
      for (var i = 0; i < 1000; i++) {
        expect(ids.uuid(), matches(_uuidV7));
      }
    });

    test('(e) the 48-bit timestamp field is the clock in milliseconds', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 24, 23, 59, 59, 999));
      final ids = MonotonicIdGen(clock, random: _ZeroRandom());
      final id = ids.uuid();
      expect(_timestampMs(id), clock.nowUtc().millisecondsSinceEpoch);
      expect(id, startsWith('01a1705b-63ff-'));
      final epoch = MonotonicIdGen(
        FakeClock(DateTime.utc(1970)),
        random: _ZeroRandom(),
      );
      expect(epoch.uuid(), '00000000-0000-7000-8000-000000000000');
    });

    test('(f) bytes 6–7 carry the version nibble, then the 12-bit counter', () {
      final ids = MonotonicIdGen(
        FakeClock(DateTime.utc(1970)),
        random: _ZeroRandom(),
      );
      final out = [for (var i = 0; i < 0x1000; i++) ids.uuid()];
      for (var i = 0; i < out.length; i++) {
        expect(_counter(out[i]), i);
      }
      expect(out[0x123], '00000000-0000-7123-8000-000000000000');
      expect(out[0xFFF], '00000000-0000-7fff-8000-000000000000');
    });

    test('(f) RELAY UuidIdGen @ 09b28810 gives these exact ids for '
        'Random(7)', () {
      // Produced by RELAY's algorithm with package:uuid 4.6.0 (RELAY's
      // lock) over the same clock readings: three in one millisecond, one
      // in the next, one with the clock 5 s back.
      final clock = FakeClock(DateTime.utc(2026, 10, 17));
      final ids = MonotonicIdGen(clock, random: Random(7));
      final out = [ids.uuid(), ids.uuid(), ids.uuid()];
      clock.advance(const Duration(milliseconds: 1));
      out.add(ids.uuid());
      clock.advance(const Duration(milliseconds: -5001));
      out.add(ids.uuid());
      expect(out, [
        '01a14728-8400-761c-9592-5eea177bd477',
        '01a14728-8400-761d-9ae5-500548ddf33c',
        '01a14728-8400-761e-ad92-7c3455693ea8',
        '01a14728-8401-77d2-80ab-86b482266fae',
        '01a14728-8401-77d3-b85a-677b75253b40',
      ]);
    });
  });
}

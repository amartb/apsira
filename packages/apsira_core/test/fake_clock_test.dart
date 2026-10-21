// From relay test/fakes/fake_clock_test.dart @ 5f606e9
import 'package:apsira_core/testing.dart';
import 'package:test/test.dart';

void main() {
  // The Clock port reads whole milliseconds (D-023); the fake keeps that
  // contract unless a precision test opts out.
  group('FakeClock at millisecond precision', () {
    final subMs = DateTime.utc(2026, 10, 18, 9, 0, 0, 123, 456);
    final ms = DateTime.utc(2026, 10, 18, 9, 0, 0, 123);

    test('truncates readings to whole milliseconds by default', () {
      final clock = FakeClock(subMs);
      expect(clock.nowUtc(), ms);
      expect(clock.nowUtc().microsecond, 0);
      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.localNow().microsecond, 0);
      clock.set(DateTime.utc(2026, 10, 18, 12, 0, 0, 0, 789));
      expect(clock.nowUtc(), DateTime.utc(2026, 10, 18, 12));
    });

    test('keeps the sub-millisecond time it travels by', () {
      final clock = FakeClock(DateTime.utc(2026, 10, 18, 12, 0, 0, 0, 789))
        ..advance(const Duration(microseconds: 1500));
      expect(clock.nowUtc(), DateTime.utc(2026, 10, 18, 12, 0, 0, 2));
      clock.advance(const Duration(microseconds: 711));
      expect(clock.nowUtc(), DateTime.utc(2026, 10, 18, 12, 0, 0, 3));
    });

    test('the Madrid clock truncates too', () {
      expect(FakeClock.madrid(subMs).nowUtc(), ms);
    });

    test('subMillisecond: true keeps sub-millisecond readings', () {
      final clock = FakeClock(subMs, subMillisecond: true);
      expect(clock.nowUtc(), subMs);
      clock.advance(const Duration(microseconds: 1));
      expect(clock.nowUtc().microsecond, 457);
      expect(FakeClock.madrid(subMs, subMillisecond: true).nowUtc(), subMs);
    });

    test('the opt-in can be switched on for a clock already in use', () {
      final clock = FakeClock(subMs);
      expect(clock.nowUtc(), ms);
      clock.subMillisecond = true;
      expect(clock.nowUtc(), subMs);
    });
  });
}

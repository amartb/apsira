// From relay test/domain/reminders/clock_utc_for_test.dart @ 5f606e9
// `Clock.utcFor` (P3b-06; data model §6.8, D-024): the UTC instant at which
// a floating date-time happens on the device's local calendar. Across a
// daylight-saving gap the time moves forward to the jump; across an
// overlap it is the first occurrence. Both clocks share `utcForWallTime`,
// so the fake's Madrid timeline proves the rule the device's clock uses.
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FakeClock.utcFor on the Madrid timeline', () {
    final clock = FakeClock.madrid(DateTime.utc(2026, 1, 1));

    test('a winter wall time is an hour ahead of UTC, a summer one two', () {
      expect(
        clock.utcFor(DateTime.utc(2026, 1, 15, 9)),
        DateTime.utc(2026, 1, 15, 8),
      );
      expect(
        clock.utcFor(DateTime.utc(2026, 7, 15, 9)),
        DateTime.utc(2026, 7, 15, 7),
      );
    });

    test('keeps seconds and milliseconds, drops microseconds', () {
      expect(
        clock.utcFor(DateTime.utc(2026, 1, 15, 9, 30, 15, 250, 999)),
        DateTime.utc(2026, 1, 15, 8, 30, 15, 250),
      );
    });

    test('a time inside the spring-forward gap moves forward to the jump', () {
      // 29 March 2026: 02:00 CET becomes 03:00 CEST at 01:00 UTC, so 02:00
      // to 02:59 never happen; 02:30 fires at 03:00 local.
      final jump = DateTime.utc(2026, 3, 29, 1);
      expect(clock.utcFor(DateTime.utc(2026, 3, 29, 2, 30)), jump);
      expect(clock.utcFor(DateTime.utc(2026, 3, 29, 2)), jump);
      expect(clock.utcFor(DateTime.utc(2026, 3, 29, 2, 59, 59, 999)), jump);
      expect(_madridWall(jump), DateTime.utc(2026, 3, 29, 3));
    });

    test('the edges of the gap are exact', () {
      expect(
        clock.utcFor(DateTime.utc(2026, 3, 29, 1, 59, 59, 999)),
        DateTime.utc(2026, 3, 29, 0, 59, 59, 999),
      );
      expect(
        clock.utcFor(DateTime.utc(2026, 3, 29, 3)),
        DateTime.utc(2026, 3, 29, 1),
      );
      expect(
        clock.utcFor(DateTime.utc(2026, 3, 29, 3, 30)),
        DateTime.utc(2026, 3, 29, 1, 30),
      );
    });

    test('a time inside the fall-back overlap is its first occurrence', () {
      // 25 October 2026: 03:00 CEST becomes 02:00 CET at 01:00 UTC, so 02:00
      // to 02:59 happen twice; the first is still summer time.
      expect(
        clock.utcFor(DateTime.utc(2026, 10, 25, 2, 30)),
        DateTime.utc(2026, 10, 25, 0, 30),
      );
      expect(
        clock.utcFor(DateTime.utc(2026, 10, 25, 2)),
        DateTime.utc(2026, 10, 25, 0),
      );
      expect(
        clock.utcFor(DateTime.utc(2026, 10, 25, 3)),
        DateTime.utc(2026, 10, 25, 2),
        reason: 'after the overlap, winter time',
      );
    });

    test('every half hour of 2026 maps back to its wall time, except in the '
        'gap', () {
      var wall = DateTime.utc(2026, 1, 1);
      var gaps = 0;
      while (wall.year == 2026) {
        final utc = clock.utcFor(wall);
        expect(utc.isUtc, isTrue);
        final back = _madridWall(utc);
        if (back != wall) {
          gaps++;
          expect(back, DateTime.utc(2026, 3, 29, 3), reason: '$wall');
        }
        wall = wall.add(const Duration(minutes: 30));
      }
      expect(gaps, 2, reason: '02:00 and 02:30 on 29 March');
    });
  });

  group('FakeClock.localAt', () {
    test('is the wall time at an instant, the inverse of utcFor', () {
      final clock = FakeClock.madrid(DateTime.utc(2026, 1, 1));
      expect(
        clock.localAt(DateTime.utc(2026, 3, 29, 0, 59)),
        DateTime.utc(2026, 3, 29, 1, 59),
      );
      expect(
        clock.localAt(DateTime.utc(2026, 3, 29, 1)),
        DateTime.utc(2026, 3, 29, 3),
      );
      expect(
        clock.localAt(DateTime.utc(2026, 10, 25, 0, 30)),
        DateTime.utc(2026, 10, 25, 2, 30),
      );
      expect(
        clock.localAt(DateTime.utc(2026, 10, 25, 1, 30)),
        DateTime.utc(2026, 10, 25, 2, 30),
        reason: 'the second 02:30',
      );
      final wall = DateTime.utc(2026, 7, 15, 9, 30, 15, 250);
      expect(clock.localAt(clock.utcFor(wall)), wall);
      expect(clock.localAt(clock.nowUtc()), clock.localNow());
    });
  });

  group('FakeClock.utcFor on a fixed offset', () {
    test('subtracts the offset, and follows a zone change', () {
      final clock = FakeClock(
        DateTime.utc(2026, 1, 1),
        timeZoneName: 'America/Mexico_City',
        utcOffset: const Duration(hours: -6),
      );
      expect(
        clock.utcFor(DateTime.utc(2026, 3, 29, 2, 30)),
        DateTime.utc(2026, 3, 29, 8, 30),
      );
      clock.setZone('Asia/Kolkata', const Duration(hours: 5, minutes: 30));
      expect(
        clock.utcFor(DateTime.utc(2026, 3, 29, 2, 30)),
        DateTime.utc(2026, 3, 28, 21),
      );
    });
  });

  group('utcForWallTime', () {
    test('a gap of 30 minutes (Lord Howe style) moves to the jump', () {
      // UTC+10:30 until 2026-10-03 15:30 UTC, then UTC+11.
      final change = DateTime.utc(2026, 10, 3, 15, 30);
      Duration offsetAt(DateTime utc) => utc.isBefore(change)
          ? const Duration(hours: 10, minutes: 30)
          : const Duration(hours: 11);
      expect(
        utcForWallTime(DateTime.utc(2026, 10, 4, 2, 15), offsetAt),
        change,
      );
      expect(
        utcForWallTime(DateTime.utc(2026, 10, 4, 2, 30), offsetAt),
        DateTime.utc(2026, 10, 3, 15, 30),
      );
      expect(
        utcForWallTime(DateTime.utc(2026, 10, 4, 1, 59), offsetAt),
        DateTime.utc(2026, 10, 3, 15, 29),
      );
    });

    test('an overlap at midnight takes the first midnight', () {
      // UTC-3 until 2026-04-05 03:00 UTC (midnight local), then UTC-4: the
      // hour from 23:00 to midnight happens twice.
      final change = DateTime.utc(2026, 4, 5, 3);
      Duration offsetAt(DateTime utc) => utc.isBefore(change)
          ? const Duration(hours: -3)
          : const Duration(hours: -4);
      expect(
        utcForWallTime(DateTime.utc(2026, 4, 4, 23, 30), offsetAt),
        DateTime.utc(2026, 4, 5, 2, 30),
      );
    });
  });
}

/// Madrid's wall time at [utc].
DateTime _madridWall(DateTime utc) => utc.add(FakeClock.madridOffsetAt(utc));

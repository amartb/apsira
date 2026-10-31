// From relay test/data/platform/system_clock_test.dart @ 09b28810 (the
// SystemClock group, moved from apsira_app with the class; run on the Dart VM).
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/system_clock.dart';
import 'package:test/test.dart';

void main() {
  group('SystemClock', () {
    const Clock clock = SystemClock();

    test('nowUtc is the current instant, in UTC', () {
      // Truncated to milliseconds, like nowUtc, so the bound holds within
      // the same millisecond.
      final before = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      );
      final now = clock.nowUtc();
      final after = DateTime.now().toUtc();
      expect(now.isUtc, isTrue);
      expect(now.isBefore(before), isFalse);
      expect(now.isAfter(after), isFalse);
    });

    test('nowUtc has the millisecond precision the database stores', () {
      // created_at, updated_at and deleted_at are INTEGER milliseconds
      // (04 §1, D-023): a fresh instant must equal itself read back, or an
      // Undo that compares the two always refuses (P1-07g).
      for (var i = 0; i < 50; i++) {
        final now = clock.nowUtc();
        expect(now.microsecond, 0, reason: '$now');
        expect(
          DateTime.fromMillisecondsSinceEpoch(
            now.millisecondsSinceEpoch,
            isUtc: true,
          ),
          now,
        );
      }
    });

    test('today is the local calendar date, as a floating date', () {
      final before = DateTime.now();
      final today = clock.today();
      final after = DateTime.now();
      expect(today.isUtc, isTrue, reason: 'floating dates carry no zone');
      expect([
        today.hour,
        today.minute,
        today.second,
        today.millisecond,
        today.microsecond,
      ], everyElement(0));
      final candidates = {
        DateTime.utc(before.year, before.month, before.day),
        DateTime.utc(after.year, after.month, after.day),
      };
      expect(candidates, contains(today));
    });

    test('localNow is the local wall time, as a floating date-time', () {
      final before = DateTime.now();
      final now = clock.localNow();
      final after = DateTime.now();
      expect(now.isUtc, isTrue, reason: 'floating times carry no zone');
      DateTime floating(DateTime l) => DateTime.utc(
        l.year,
        l.month,
        l.day,
        l.hour,
        l.minute,
        l.second,
        l.millisecond,
        l.microsecond,
      );
      expect(now.isBefore(floating(before)), isFalse);
      expect(now.isAfter(floating(after)), isFalse);
      expect(
        DateTime.utc(now.year, now.month, now.day),
        anyOf(
          DateTime.utc(before.year, before.month, before.day),
          DateTime.utc(after.year, after.month, after.day),
        ),
      );
    });

    test('localDayStartUtc is the UTC instant of local midnight', () {
      final start = clock.localDayStartUtc(DateTime.utc(2026, 3, 29));
      expect(start.isUtc, isTrue);
      expect(start, DateTime(2026, 3, 29).toUtc());
      final local = start.toLocal();
      expect([local.year, local.month, local.day], [2026, 3, 29]);
      expect([local.hour, local.minute, local.second], everyElement(0));
    });

    test('localDayStartUtc ignores the time of day of its argument', () {
      expect(
        clock.localDayStartUtc(DateTime.utc(2026, 10, 25, 17, 45)),
        clock.localDayStartUtc(DateTime.utc(2026, 10, 25)),
      );
    });

    test('every local day of 2026 starts where the previous one ends', () {
      // In the device zone, a day lasts 24 hours, or 23 / 25 across a
      // daylight-saving change; the bounds tile the year with no gap.
      var day = DateTime.utc(2026, 1, 1);
      var start = clock.localDayStartUtc(day);
      final lengths = <Duration>{};
      for (var i = 0; i < 365; i++) {
        final next = DateTime.utc(day.year, day.month, day.day + 1);
        final nextStart = clock.localDayStartUtc(next);
        final length = nextStart.difference(start);
        lengths.add(length);
        expect(
          length >= const Duration(hours: 22) &&
              length <= const Duration(hours: 26),
          isTrue,
          reason: '$day lasts $length',
        );
        expect(start.toLocal().day, day.day, reason: '$day');
        day = next;
        start = nextStart;
      }
      expect(lengths, contains(const Duration(hours: 24)));
    });

    test('utcFor is the instant of a local wall time, in any zone', () {
      final wall = DateTime.utc(2026, 7, 15, 9, 30, 15, 250);
      final utc = clock.utcFor(wall);
      expect(utc.isUtc, isTrue);
      expect(utc, DateTime(2026, 7, 15, 9, 30, 15, 250).toUtc());
    });

    test('utcFor maps every half hour of 2026 back to its wall time, or '
        'forward to the jump of a gap', () {
      var wall = DateTime.utc(2026, 1, 1);
      while (wall.year == 2026) {
        final local = clock.utcFor(wall).toLocal();
        final back = DateTime.utc(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
        );
        if (back != wall) {
          // Skipped by the clocks: the first instant past it, so the
          // millisecond before shows a wall time before it.
          expect(back.isAfter(wall), isTrue, reason: '$wall');
          final justBefore = clock
              .utcFor(wall)
              .subtract(const Duration(milliseconds: 1))
              .toLocal();
          expect(
            DateTime.utc(
              justBefore.year,
              justBefore.month,
              justBefore.day,
              justBefore.hour,
              justBefore.minute,
            ).isBefore(wall),
            isTrue,
            reason: '$wall',
          );
        }
        wall = wall.add(const Duration(minutes: 30));
      }
    });

    test('localAt is the wall time at an instant, as a floating '
        'date-time', () {
      final utc = DateTime.utc(2026, 7, 15, 7, 30, 15, 250);
      final local = utc.toLocal();
      expect(
        clock.localAt(utc),
        DateTime.utc(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
          local.millisecond,
        ),
      );
      expect(clock.localAt(utc).isUtc, isTrue);
      final wall = DateTime.utc(2026, 1, 20, 18, 5);
      expect(clock.localAt(clock.utcFor(wall)), wall);
    });

    final madridRules =
        DateTime(2026, 1, 15).timeZoneOffset == const Duration(hours: 1) &&
        DateTime(2026, 7, 15).timeZoneOffset == const Duration(hours: 2);
    test('utcFor under Europe/Madrid: the gap moves to the jump, the overlap '
        'is its first occurrence (run with TZ=Europe/Madrid)', () {
      expect(
        clock.utcFor(DateTime.utc(2026, 3, 29, 2, 30)),
        DateTime.utc(2026, 3, 29, 1),
      );
      expect(
        clock.utcFor(DateTime.utc(2026, 10, 25, 2, 30)),
        DateTime.utc(2026, 10, 25, 0, 30),
      );
    }, skip: madridRules ? false : 'the host zone does not follow CET/CEST');

    test('the IANA zone is a StateError until this isolate reads one, then '
        'the zone kept (D-115)', () {
      SystemClock.forgetZone();
      addTearDown(SystemClock.forgetZone);
      expect(clock.timeZoneName, throwsStateError);
      SystemClock.useZone('Europe/Madrid');
      expect(clock.timeZoneName(), 'Europe/Madrid');
    });

    test('refreshZone keeps the zone its read returns; a failed read keeps '
        'the last one', () async {
      SystemClock.forgetZone();
      addTearDown(SystemClock.forgetZone);
      await SystemClock.refreshZone(() async => 'Atlantic/Canary');
      expect(clock.timeZoneName(), 'Atlantic/Canary');
      await expectLater(
        SystemClock.refreshZone(() async => throw StateError('no channel')),
        throwsStateError,
      );
      expect(clock.timeZoneName(), 'Atlantic/Canary');
    });
  });
}

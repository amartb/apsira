// From relay test/fakes/fake_clock.dart @ 5f606e9
import '../src/clock.dart';

/// The zone offset in force at a UTC instant: a named timeline's rules.
typedef OffsetAt = Duration Function(DateTime utc);

/// A clock that moves only when told: time travel for recurrence, reminder
/// and trash tests (architecture §3.1).
///
/// The zone is a name and either a fixed offset or an [OffsetAt] timeline,
/// for the named daylight-saving scenarios of 08 §4 ([FakeClock.madrid]).
///
/// Readings keep the port's contract: whole milliseconds (D-023). The clock
/// itself keeps any sub-millisecond time it is set to or travels by, so
/// small steps add up as on a device, but [nowUtc], [today] and [localNow]
/// read it truncated. A precision test that needs a clock breaking that
/// contract, to prove a service copes with one, opts in with
/// `subMillisecond: true` or by setting [subMillisecond].
final class FakeClock implements Clock {
  FakeClock(
    DateTime nowUtc, {
    String timeZoneName = 'UTC',
    Duration utcOffset = Duration.zero,
    OffsetAt? offsetAt,
    this.subMillisecond = false,
  }) : _now = _checkUtc(nowUtc),
       _zone = timeZoneName,
       _offset = utcOffset,
       _timeline = offsetAt;

  /// A clock in `Europe/Madrid`, on the timeline of [madridOffsetAt].
  factory FakeClock.madrid(DateTime nowUtc, {bool subMillisecond = false}) =>
      FakeClock(
        nowUtc,
        timeZoneName: 'Europe/Madrid',
        offsetAt: madridOffsetAt,
        subMillisecond: subMillisecond,
      );

  /// Whether readings keep microseconds instead of truncating to whole
  /// milliseconds: only for precision tests (see the class comment). A
  /// group can switch it on for a clock its services already hold.
  bool subMillisecond;

  DateTime _now;
  String _zone;
  Duration _offset;
  OffsetAt? _timeline;

  /// Madrid's offset under the EU rule: UTC+2 from 01:00 UTC on the last
  /// Sunday of March to 01:00 UTC on the last Sunday of October, UTC+1
  /// otherwise.
  static Duration madridOffsetAt(DateTime utc) {
    final instant = utc.toUtc();
    final springForward = _lastSundayAt1Utc(instant.year, 3);
    final fallBack = _lastSundayAt1Utc(instant.year, 10);
    final summer =
        !instant.isBefore(springForward) && instant.isBefore(fallBack);
    return Duration(hours: summer ? 2 : 1);
  }

  static DateTime _lastSundayAt1Utc(int year, int month) {
    final last = DateTime.utc(year, month + 1, 0);
    return DateTime.utc(year, month, last.day - last.weekday % 7, 1);
  }

  static DateTime _checkUtc(DateTime instant) {
    if (!instant.isUtc) {
      throw ArgumentError.value(instant, 'instant', 'must be UTC');
    }
    return instant;
  }

  Duration _offsetFor(DateTime utc) => _timeline?.call(utc) ?? _offset;

  /// The instant a reading returns: [_now], truncated to whole milliseconds
  /// unless [subMillisecond] is set.
  DateTime get _reading => subMillisecond
      ? _now
      : DateTime.fromMillisecondsSinceEpoch(
          _now.millisecondsSinceEpoch,
          isUtc: true,
        );

  DateTime _wallTime(DateTime utc) => utc.add(_offsetFor(utc));

  /// Moves the clock by [delta], which may be negative.
  void advance(Duration delta) => _now = _now.add(delta);

  /// Jumps to [nowUtc].
  void set(DateTime nowUtc) => _now = _checkUtc(nowUtc);

  /// Changes the device's zone, as a time-zone change would: to a fixed
  /// [utcOffset], or to the [offsetAt] timeline when one is given.
  void setZone(String timeZoneName, Duration utcOffset, {OffsetAt? offsetAt}) {
    _zone = timeZoneName;
    _offset = utcOffset;
    _timeline = offsetAt;
  }

  @override
  DateTime nowUtc() => _reading;

  @override
  String timeZoneName() => _zone;

  @override
  DateTime today() {
    final local = _wallTime(_reading);
    return DateTime.utc(local.year, local.month, local.day);
  }

  @override
  DateTime localNow() => _wallTime(_reading);

  @override
  DateTime localAt(DateTime utc) => _wallTime(_checkUtc(utc));

  /// [utcForWallTime] on the zone's timeline or fixed offset.
  @override
  DateTime utcFor(DateTime floating) => utcForWallTime(floating, _offsetFor);

  /// Tries the offsets in force around the day; the earliest instant whose
  /// wall time is local midnight wins, and when midnight is skipped, the
  /// earliest instant already past it (the jump).
  @override
  DateTime localDayStartUtc(DateTime floatingDate) {
    final midnight = DateTime.utc(
      floatingDate.year,
      floatingDate.month,
      floatingDate.day,
    );
    final candidates = {
      for (final probe in [
        midnight.subtract(const Duration(days: 1)),
        midnight,
        midnight.add(const Duration(days: 1)),
      ])
        midnight.subtract(_offsetFor(probe)),
    }.toList()..sort();
    for (final candidate in candidates) {
      if (_wallTime(candidate) == midnight) return candidate;
    }
    return candidates.firstWhere((c) => _wallTime(c).isAfter(midnight));
  }
}

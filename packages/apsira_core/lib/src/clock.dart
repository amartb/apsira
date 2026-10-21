// From relay lib/core/ports/clock.dart @ 5f606e9
/// The only source of time (architecture §3.1; CLAUDE.md §1.5).
///
/// Domain and service code never read the system clock: they take a
/// [Clock], so tests can travel in time.
abstract interface class Clock {
  /// The current instant, in UTC, at whole-millisecond precision: the unit
  /// every stored instant has (`created_at`, `updated_at`, `deleted_at` are
  /// INTEGER milliseconds since the epoch: data model §1, D-023).
  /// Implementations truncate any finer reading, so an instant a service
  /// writes equals the one it reads back, and domain factories never see
  /// sub-millisecond times.
  DateTime nowUtc();

  /// The device's IANA time-zone name, such as `Europe/Madrid`. Reminders
  /// store it beside their UTC instant (D-024).
  String timeZoneName();

  /// Today's date on the device's local calendar, as a floating date
  /// (D-024): a UTC `DateTime` at midnight whose year, month and day are the
  /// local ones. Floating dates carry no zone, so they never shift.
  DateTime today();

  /// The current local wall time, as a floating date-time: a UTC `DateTime`
  /// whose fields are the local ones (like [today], with the time of day).
  /// Backup file names use it (A-25).
  DateTime localNow();

  /// The UTC instant at which the local calendar day of [floatingDate]
  /// starts in the device's zone, exact across daylight saving: the day
  /// lasts until the next day's start, 23 or 25 hours when the clocks
  /// change (A-24).
  ///
  /// Only the year, month and day of [floatingDate] count. When a zone
  /// skips local midnight, the day starts at the jump; when midnight comes
  /// twice, at its first occurrence.
  DateTime localDayStartUtc(DateTime floatingDate);

  /// The UTC instant at which the floating date-time [floating] (a UTC
  /// `DateTime` whose fields are a local wall time, like [localNow]'s)
  /// happens in the device's zone, to the millisecond: how a reminder on a
  /// floating due date and time becomes an instant (data model §6.8,
  /// D-024).
  ///
  /// Exact across daylight saving ([utcForWallTime]): a wall time the
  /// clocks skip moves forward to the jump (02:30 on a spring-forward day
  /// at 02:00 is 03:00), and one that happens twice is its first
  /// occurrence.
  DateTime utcFor(DateTime floating);

  /// The local wall time at the UTC instant [utc], as a floating date-time
  /// (what [localNow] reads at that instant): how an absolute reminder
  /// keeps its time of day when its task's occurrence moves.
  DateTime localAt(DateTime utc);
}

/// The rule every [Clock.utcFor] follows, over a zone's [offsetAt] (the
/// offset from UTC in force at a UTC instant).
///
/// The instant is the earliest whose wall time is [floating] (its
/// microseconds dropped). When no instant has that wall time, because the
/// clocks jump over it, it is the jump: the first instant whose wall time
/// is later. The zone's offsets are read around [floating], a day either
/// way, so one change of offset near it is always seen.
DateTime utcForWallTime(
  DateTime floating,
  Duration Function(DateTime utc) offsetAt,
) {
  final wall = DateTime.utc(
    floating.year,
    floating.month,
    floating.day,
    floating.hour,
    floating.minute,
    floating.second,
    floating.millisecond,
  );
  DateTime wallAt(DateTime utc) => utc.add(offsetAt(utc));
  final candidates = {
    for (final hours in const [-24, -12, 0, 12, 24])
      wall.subtract(offsetAt(wall.add(Duration(hours: hours)))),
  }.toList()..sort();
  for (final candidate in candidates) {
    if (wallAt(candidate) == wall) return candidate;
  }
  // A gap: the jump lies between the latest candidate still before the
  // wall time and the earliest one past it. Wall time only rises across a
  // gap, so a search to the millisecond finds the first instant past it.
  final before = candidates.lastWhere(
    (c) => wallAt(c).isBefore(wall),
    orElse: () => candidates.first,
  );
  final after = candidates.firstWhere(
    (c) => wallAt(c).isAfter(wall),
    orElse: () => candidates.last,
  );
  var lo = before.millisecondsSinceEpoch;
  var hi = after.millisecondsSinceEpoch;
  DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  if (!wallAt(at(hi)).isAfter(wall)) return at(hi);
  while (hi - lo > 1) {
    final mid = lo + (hi - lo) ~/ 2;
    if (wallAt(at(mid)).isAfter(wall)) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return at(hi);
}

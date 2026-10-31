// From relay lib/data/platform/system_clock.dart @ 09b28810
import 'package:apsira_core/apsira_core.dart';

/// The device clock. Pure Dart: it imports no Flutter library, so a plain
/// Dart process (a test's child process) can use it; the composition root
/// passes the zone module's read in.
///
/// Its IANA zone name is one value per isolate (each engine runs its own):
/// the UI isolate reads it from the zone module at bootstrap and on resume
/// ([refreshZone]); a background entry point sets it from its job's input
/// or from the zone the last resync stored ([useZone]).
final class SystemClock implements Clock {
  const SystemClock();

  static String? _zoneId;

  /// Reads the device's zone with [read] (the UI engine's zone module,
  /// `ZoneChannel.zoneId`) and keeps it for [timeZoneName]. Throws what
  /// [read] throws; the last zone read stays.
  static Future<void> refreshZone(Future<String> Function() read) async {
    _zoneId = await read();
  }

  /// Keeps [zoneId] for [timeZoneName], in an engine without the zone
  /// module.
  static void useZone(String zoneId) => _zoneId = zoneId;

  /// Forgets the zone, so a test starts with none (tests only).
  static void forgetZone() => _zoneId = null;

  /// Truncated to whole milliseconds, the unit every stored instant has
  /// (`created_at`, `updated_at`, `deleted_at` are INTEGER milliseconds
  /// since the epoch, UTC: data model §1, D-023). A fresh instant then
  /// equals itself read back, so a service that compares the time it wrote
  /// with the row it reads (an Undo's still-as-left check) sees a match.
  @override
  DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch,
    isUtc: true,
  );

  @override
  DateTime today() {
    final local = DateTime.now();
    return DateTime.utc(local.year, local.month, local.day);
  }

  @override
  DateTime localNow() {
    final local = DateTime.now();
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  /// Dart's local `DateTime` uses the device zone's rules for that date, so
  /// daylight-saving days come out 23 or 25 hours long.
  @override
  DateTime localDayStartUtc(DateTime floatingDate) =>
      DateTime(floatingDate.year, floatingDate.month, floatingDate.day).toUtc();

  /// [utcForWallTime] over the offsets Dart's local `DateTime` reports,
  /// which follow the device zone's rules for each instant.
  @override
  DateTime utcFor(DateTime floating) =>
      utcForWallTime(floating, (utc) => utc.toLocal().timeZoneOffset);

  @override
  DateTime localAt(DateTime utc) {
    final local = utc.toLocal();
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  /// Dart reports only an abbreviation and an offset, so the IANA name is
  /// the one [refreshZone] or [useZone] kept. Synchronous, as the port is;
  /// a StateError when this isolate has none yet, never a guess.
  @override
  String timeZoneName() =>
      _zoneId ??
      (throw StateError(
        'Clock.timeZoneName: no zone in this isolate yet '
        '(SystemClock.refreshZone or SystemClock.useZone)',
      ));
}

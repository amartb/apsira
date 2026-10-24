// From viaticum lib/core/ports/background_jobs.dart @ 78d38e0 (BackgroundJobs,
// with firstRunIn and replace) and relay lib/core/ports/background_jobs.dart
// @ 09b28810 (JobConstraints, with deviceIdle and every default false).

/// What must hold before a job runs. WorkManager waits until they do.
final class JobConstraints {
  const JobConstraints({
    this.batteryNotLow = false,
    this.storageNotLow = false,
    this.deviceIdle = false,
  });

  /// The battery is not low (Android's `ACTION_BATTERY_OKAY` state).
  final bool batteryNotLow;

  /// Free storage is not low (Android's `ACTION_DEVICE_STORAGE_OK` state).
  final bool storageNotLow;

  /// The device is idle (Doze maintenance windows).
  final bool deviceIdle;

  @override
  bool operator ==(Object other) =>
      other is JobConstraints &&
      other.batteryNotLow == batteryNotLow &&
      other.storageNotLow == storageNotLow &&
      other.deviceIdle == deviceIdle;

  @override
  int get hashCode => Object.hash(batteryNotLow, storageNotLow, deviceIdle);

  @override
  String toString() =>
      'JobConstraints(batteryNotLow: $batteryNotLow, '
      'storageNotLow: $storageNotLow, deviceIdle: $deviceIdle)';
}

/// Schedules and cancels the named periodic jobs.
///
/// Jobs are named; the app's background entry point maps each name to what it
/// runs. A job that reports it did not run (a restore pending, the database
/// not ready, a run already in progress) is retried by WorkManager with
/// backoff; one that ran, whatever its outcome, waits for its next period.
abstract interface class BackgroundJobs {
  /// Schedules [jobName] to run about every [every] (15 minutes at the
  /// least) once [constraints] hold, the first run [firstRunIn] from now
  /// (null: as soon as the constraints hold). A schedule of the same name
  /// is kept as it is, its next run included, so scheduling at every start
  /// never postpones a job; with [replace] it is cancelled and scheduled
  /// afresh, the way a changed time of day takes effect.
  Future<void> schedulePeriodic(
    String jobName, {
    required Duration every,
    JobConstraints constraints = const JobConstraints(),
    Duration? firstRunIn,
    bool replace = false,
  });

  /// Cancels [jobName]; cancelling a job that is not scheduled does nothing.
  Future<void> cancel(String jobName);
}

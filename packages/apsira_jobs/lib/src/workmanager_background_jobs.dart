// From viaticum lib/data/platform/workmanager_background_jobs.dart @ 78d38e0
// (the keep/replace policy and initialDelay), with relay
// lib/data/platform/workmanager_background_jobs.dart @ 09b28810's
// requiresDeviceIdle mapping.
import 'package:workmanager/workmanager.dart';

import 'background_jobs.dart';

/// The [BackgroundJobs] on `workmanager`: each job is a unique periodic work
/// request named after it, with no network constraint and exponential
/// backoff. Scheduling it again keeps the existing request untouched
/// (WorkManager's `keep` policy), so a start never moves its next run; a
/// replacement (a changed time of day) cancels it and enqueues it afresh
/// with its first run delayed (`replace`, `initialDelay`). WorkManager's
/// `update` policy is not used: it would apply a new first-run delay from
/// the old enqueue time to a job that has not run yet, pulling that run
/// earlier at every start.
///
/// WorkManager starts the background engine at the dispatcher, a top-level
/// `@pragma('vm:entry-point')` function of the app; it is handed to the
/// plugin once, before the first schedule or cancel. A failed `initialize`
/// is retried by the next call.
final class WorkManagerBackgroundJobs implements BackgroundJobs {
  WorkManagerBackgroundJobs(this._dispatcher, {Workmanager? plugin})
    : _plugin = plugin ?? Workmanager();

  /// The first retry of a job that did not run waits this long, doubling
  /// after each further one (WorkManager's exponential backoff).
  static const Duration retryDelay = Duration(minutes: 30);

  final void Function() _dispatcher;
  final Workmanager _plugin;
  Future<void>? _initialized;

  Future<void> _ready() =>
      _initialized ??= _plugin.initialize(_dispatcher).catchError((Object e) {
        _initialized = null;
        throw e;
      });

  @override
  Future<void> schedulePeriodic(
    String jobName, {
    required Duration every,
    JobConstraints constraints = const JobConstraints(),
    Duration? firstRunIn,
    bool replace = false,
  }) async {
    await _ready();
    await _plugin.registerPeriodicTask(
      jobName,
      jobName,
      frequency: every,
      initialDelay: firstRunIn ?? Duration.zero,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: constraints.batteryNotLow,
        requiresCharging: false,
        requiresDeviceIdle: constraints.deviceIdle,
        requiresStorageNotLow: constraints.storageNotLow,
      ),
      existingWorkPolicy: replace
          ? ExistingPeriodicWorkPolicy.replace
          : ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: retryDelay,
    );
  }

  @override
  Future<void> cancel(String jobName) async {
    await _ready();
    await _plugin.cancelByUniqueName(jobName);
  }
}

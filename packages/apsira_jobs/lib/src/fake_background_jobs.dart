// From viaticum test/fakes/fake_background_jobs.dart @ 78d38e0 (the keep/replace
// record), with relay test/fakes/fake_background_jobs.dart @ 09b28810's
// handler result. VIATICUM's clock-timed runs (RecordedBackgroundJobs, the
// Spike lab's) stay in VIATICUM: this package depends on no apsira package.
import '../apsira_jobs.dart';

/// Records the schedule and runs jobs on demand: tests invoke a job directly
/// with [runNow] instead of waiting for the system. Each schedule keeps its
/// period ([scheduled]), its constraints ([constraintsOf]) and its first-run
/// delay ([firstRunInOf]). As WorkManager's keep policy, scheduling a job that
/// is already scheduled changes nothing unless `replace` is true ([replaced]
/// lists those). Not final, so an app can extend it with records of its own.
class FakeBackgroundJobs implements BackgroundJobs {
  FakeBackgroundJobs({Map<String, Future<bool> Function()>? handlers})
    : handlers = handlers ?? {};

  /// What each job name runs, as the app registers it; true when it ran,
  /// false when WorkManager would retry it.
  final Map<String, Future<bool> Function()> handlers;

  final Map<String, Duration> _scheduled = {};
  final Map<String, JobConstraints> _constraints = {};
  final Map<String, Duration?> _firstRunIn = {};

  /// The names scheduled afresh with `replace: true`, in order.
  final List<String> replaced = [];

  /// The names of the scheduled jobs and their periods.
  Future<Map<String, Duration>> scheduled() async => Map.of(_scheduled);

  /// How long [jobName]'s current schedule waits before its first run, as
  /// it was scheduled; null when it runs as soon as its constraints hold,
  /// or when it is not scheduled.
  Duration? firstRunInOf(String jobName) => _firstRunIn[jobName];

  /// The constraints [jobName] was last scheduled with; null when it is not
  /// scheduled.
  JobConstraints? constraintsOf(String jobName) => _constraints[jobName];

  /// Runs [jobName] now, as the system would; true when it ran, false when
  /// WorkManager would retry it.
  Future<bool> runNow(String jobName) {
    final handler = handlers[jobName];
    if (handler == null) throw StateError('no handler for job $jobName');
    return handler();
  }

  @override
  Future<void> schedulePeriodic(
    String jobName, {
    required Duration every,
    JobConstraints constraints = const JobConstraints(),
    Duration? firstRunIn,
    bool replace = false,
  }) async {
    if (_scheduled.containsKey(jobName) && !replace) return;
    if (replace) replaced.add(jobName);
    _scheduled[jobName] = every;
    _constraints[jobName] = constraints;
    _firstRunIn[jobName] = firstRunIn;
  }

  @override
  Future<void> cancel(String jobName) async {
    _scheduled.remove(jobName);
    _constraints.remove(jobName);
    _firstRunIn.remove(jobName);
  }
}

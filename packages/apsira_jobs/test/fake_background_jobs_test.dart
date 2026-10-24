// From viaticum test/core/fakes_test.dart @ 78d38e0 (the FakeBackgroundJobs
// group), with RELAY's handler result (true: it ran; false: retry).
import 'package:apsira_jobs/apsira_jobs.dart';
import 'package:apsira_jobs/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is a BackgroundJobs', () {
    expect(FakeBackgroundJobs(), isA<BackgroundJobs>());
  });

  test('records the schedule', () async {
    final jobs = FakeBackgroundJobs();
    await jobs.schedulePeriodic('nightlyCopy', every: const Duration(days: 1));
    await jobs.schedulePeriodic('reconcile', every: const Duration(hours: 6));
    await jobs.cancel('reconcile');
    expect(await jobs.scheduled(), {'nightlyCopy': const Duration(days: 1)});
  });

  test('keeps each schedule\'s constraints until it is cancelled', () async {
    final jobs = FakeBackgroundJobs();
    await jobs.schedulePeriodic('daily', every: const Duration(days: 1));
    await jobs.schedulePeriodic(
      'idle',
      every: const Duration(days: 1),
      constraints: const JobConstraints(deviceIdle: true),
    );
    expect(jobs.constraintsOf('daily'), const JobConstraints());
    expect(jobs.constraintsOf('idle'), const JobConstraints(deviceIdle: true));
    await jobs.cancel('daily');
    expect(jobs.constraintsOf('daily'), isNull);
  });

  test('keeps an existing schedule unless replace is true, as keep', () async {
    final jobs = FakeBackgroundJobs();
    await jobs.schedulePeriodic(
      'daily',
      every: const Duration(days: 1),
      firstRunIn: const Duration(hours: 3),
    );
    await jobs.schedulePeriodic(
      'daily',
      every: const Duration(hours: 12),
      firstRunIn: const Duration(hours: 1),
      constraints: const JobConstraints(batteryNotLow: true),
    );
    expect(jobs.replaced, isEmpty);
    expect(await jobs.scheduled(), {'daily': const Duration(days: 1)});
    expect(jobs.firstRunInOf('daily'), const Duration(hours: 3));
    expect(jobs.constraintsOf('daily'), const JobConstraints());

    await jobs.schedulePeriodic(
      'daily',
      every: const Duration(hours: 12),
      firstRunIn: const Duration(hours: 1),
      replace: true,
    );
    expect(jobs.replaced, ['daily']);
    expect(await jobs.scheduled(), {'daily': const Duration(hours: 12)});
    expect(jobs.firstRunInOf('daily'), const Duration(hours: 1));
  });

  test('a cancelled job is scheduled afresh without replace', () async {
    final jobs = FakeBackgroundJobs();
    await jobs.schedulePeriodic('daily', every: const Duration(days: 1));
    await jobs.cancel('daily');
    await jobs.schedulePeriodic(
      'daily',
      every: const Duration(hours: 6),
      firstRunIn: const Duration(minutes: 5),
    );
    expect(await jobs.scheduled(), {'daily': const Duration(hours: 6)});
    expect(jobs.firstRunInOf('daily'), const Duration(minutes: 5));
    expect(jobs.firstRunInOf('never'), isNull);
  });

  test('runNow runs the job directly and answers its result', () async {
    var ran = 0;
    final jobs = FakeBackgroundJobs(
      handlers: {
        'nightlyCopy': () async {
          ran++;
          return true;
        },
        'blocked': () async => false,
      },
    );
    expect(await jobs.runNow('nightlyCopy'), isTrue);
    expect(await jobs.runNow('blocked'), isFalse);
    expect(ran, 1);
    expect(() => jobs.runNow('unknown'), throwsStateError);
  });
}

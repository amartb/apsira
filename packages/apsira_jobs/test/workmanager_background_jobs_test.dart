// From relay test/app/services/background_work_test.dart @ 09b28810 (the
// recording `Workmanager`) and viaticum lib/data/platform/
// workmanager_background_jobs.dart @ 78d38e0 (the policy it checks): every
// combination of `replace`, `firstRunIn` and the constraints reaches the plugin
// as VIATICUM's keep/replace policy with RELAY's device-idle mapping.
import 'package:apsira_jobs/apsira_jobs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

/// The plugin's surface the adapter calls, recorded.
final class _Plugin implements Workmanager {
  final calls = <String>[];

  /// How many of the next `initialize` calls throw, as with no plugin on the
  /// platform.
  int failInitialize = 0;
  Duration? frequency;
  Duration? initialDelay;
  Constraints? constraints;
  ExistingPeriodicWorkPolicy? policy;
  BackoffPolicy? backoff;
  Duration? backoffDelay;
  Map<String, dynamic>? inputData;

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    if (failInitialize > 0) {
      failInitialize--;
      throw StateError('no plugin');
    }
    calls.add('initialize');
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    calls.add('register $uniqueName $taskName');
    this.frequency = frequency;
    this.initialDelay = initialDelay;
    this.constraints = constraints;
    this.inputData = inputData;
    policy = existingWorkPolicy;
    backoff = backoffPolicy;
    backoffDelay = backoffPolicyDelay;
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async =>
      calls.add('cancel $uniqueName');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void _noDispatcher() {}

void main() {
  late _Plugin plugin;
  late WorkManagerBackgroundJobs jobs;

  setUp(() {
    plugin = _Plugin();
    jobs = WorkManagerBackgroundJobs(_noDispatcher, plugin: plugin);
  });

  group('the policy, for each combination of replace and firstRunIn', () {
    const delay = Duration(hours: 7, minutes: 30);
    for (final replace in [false, true]) {
      for (final firstRunIn in [null, delay]) {
        test('replace: $replace, firstRunIn: $firstRunIn', () async {
          await jobs.schedulePeriodic(
            'nightlyCopy',
            every: const Duration(days: 1),
            firstRunIn: firstRunIn,
            replace: replace,
          );
          expect(plugin.calls, [
            'initialize',
            'register nightlyCopy nightlyCopy',
          ]);
          expect(
            plugin.policy,
            replace
                ? ExistingPeriodicWorkPolicy.replace
                : ExistingPeriodicWorkPolicy.keep,
          );
          expect(plugin.initialDelay, firstRunIn ?? Duration.zero);
          expect(plugin.frequency, const Duration(days: 1));
          expect(plugin.backoff, BackoffPolicy.exponential);
          expect(plugin.backoffDelay, const Duration(minutes: 30));
          expect(plugin.inputData, isNull);
        });
      }
    }

    test('the default is keep, which never moves a scheduled run', () async {
      await jobs.schedulePeriodic('daily', every: const Duration(days: 1));
      expect(plugin.policy, ExistingPeriodicWorkPolicy.keep);
      expect(plugin.initialDelay, Duration.zero);
    });

    test('only keep and replace are ever used, never update', () async {
      for (final replace in [false, true]) {
        await jobs.schedulePeriodic(
          'daily',
          every: const Duration(days: 1),
          firstRunIn: const Duration(hours: 1),
          replace: replace,
        );
        expect(
          plugin.policy,
          isIn([
            ExistingPeriodicWorkPolicy.keep,
            ExistingPeriodicWorkPolicy.replace,
          ]),
        );
      }
    });
  });

  group('the constraints, for each combination of the three', () {
    for (final batteryNotLow in [false, true]) {
      for (final storageNotLow in [false, true]) {
        for (final deviceIdle in [false, true]) {
          final constraints = JobConstraints(
            batteryNotLow: batteryNotLow,
            storageNotLow: storageNotLow,
            deviceIdle: deviceIdle,
          );
          test('$constraints', () async {
            await jobs.schedulePeriodic(
              'purge',
              every: const Duration(hours: 6),
              constraints: constraints,
            );
            final passed = plugin.constraints!;
            expect(passed.networkType, NetworkType.notRequired);
            expect(passed.requiresBatteryNotLow, batteryNotLow);
            expect(passed.requiresStorageNotLow, storageNotLow);
            expect(passed.requiresDeviceIdle, deviceIdle);
            expect(passed.requiresCharging, isFalse);
          });
        }
      }
    }

    test('the default constraints require nothing (RELAY)', () async {
      await jobs.schedulePeriodic('purge', every: const Duration(hours: 6));
      final passed = plugin.constraints!;
      expect(passed.requiresBatteryNotLow, isFalse);
      expect(passed.requiresStorageNotLow, isFalse);
      expect(passed.requiresDeviceIdle, isFalse);
      expect(passed.requiresCharging, isFalse);
      expect(passed.networkType, NetworkType.notRequired);
    });
  });

  group('initialize', () {
    test('runs once, before the first schedule or cancel', () async {
      await jobs.cancel('daily');
      await jobs.schedulePeriodic('daily', every: const Duration(days: 1));
      await jobs.cancel('daily');
      expect(plugin.calls, [
        'initialize',
        'cancel daily',
        'register daily daily',
        'cancel daily',
      ]);
    });

    test('is retried on the next call after it failed', () async {
      plugin.failInitialize = 1;
      await expectLater(
        jobs.schedulePeriodic('daily', every: const Duration(days: 1)),
        throwsStateError,
      );
      expect(plugin.calls, isEmpty);
      await jobs.schedulePeriodic('daily', every: const Duration(days: 1));
      expect(plugin.calls, ['initialize', 'register daily daily']);
    });

    test('a failed cancel is retried too', () async {
      plugin.failInitialize = 1;
      await expectLater(jobs.cancel('daily'), throwsStateError);
      await jobs.cancel('daily');
      expect(plugin.calls, ['initialize', 'cancel daily']);
    });
  });

  test('the retry delay is 30 minutes, doubling (exponential)', () {
    expect(WorkManagerBackgroundJobs.retryDelay, const Duration(minutes: 30));
  });
}

// From viaticum lib/app/services/reminder_sync_service.dart @ 78d38e0 (the
// diff against the per-install registry, never the database, one operation
// at a time) and relay lib/domain/reminders/window.dart @ 09b28810 (the
// window); every wanted alarm is armed again and snoozes are kept (D-APK-022).
import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'alarm_registry.dart';
import 'alarm_scheduler.dart';
import 'alarm_window.dart';
import 'snooze_store.dart';

/// What one [AlarmSync.resync] did: alarms armed ([scheduled]), entries and
/// codes cancelled, and alarms the platform refused or skipped.
final class AlarmSyncReport {
  const AlarmSyncReport({
    required this.scheduled,
    required this.cancelled,
    this.refused = 0,
  });

  final int scheduled;
  final int cancelled;
  final int refused;

  @override
  String toString() =>
      'AlarmSyncReport(scheduled $scheduled, cancelled $cancelled, '
      'refused $refused)';
}

/// Brings the platform's alarms to what the app wants, through the
/// per-install [AlarmRegistry] (D-APK-022).
///
/// [resync] takes the wanted alarms from the app's data and:
/// 1. applies the [SnoozeStore]: a snooze stands in for its alarm's time
///    while the alarm is wanted and the snooze is ahead; the others are
///    pruned (Done, an expired snooze, another install's file);
/// 2. leaves out an alarm that fired at that very instant (the registry's
///    fire record) and, with [lateGrace], one more than [lateGrace] past
///    (LYCEUM's notification alarms, which the platform never fires late:
///    zero); without it a past alarm is armed and goes off at once;
/// 3. takes the window ([planAlarms]: the [windowSize] nearest);
/// 4. cancels on the platform every registry entry outside the window and
///    every pending code, and only then unregisters them;
/// 5. registers the whole window in one write and only then arms every alarm
///    in it, the unchanged ones included. A refused alarm is cancelled and
///    unregistered.
///
/// The registry decides only what to cancel, so neither a crash nor a copied
/// registry can leave a wanted alarm unarmed. Operations of one [AlarmSync]
/// run one after another; an app keeps one per isolate.
final class AlarmSync {
  AlarmSync(
    this._scheduler,
    this._registry, {
    this._snoozes,
    this.lateGrace,
    this.windowSize = reminderWindowSize,
  }) {
    if (lateGrace case final grace? when grace.isNegative) {
      throw ArgumentError.value(grace, 'lateGrace', 'must not be negative');
    }
  }

  final AlarmScheduler _scheduler;
  final AlarmRegistry _registry;
  final SnoozeStore? _snoozes;

  /// How late an alarm may still be armed; null for any lateness.
  final Duration? lateGrace;

  /// How many alarms the window arms.
  final int windowSize;

  /// Told each step of a resync (`cancelled`, `unregistered`, `registered`,
  /// `scheduled`): the crash matrix's kill points.
  @visibleForTesting
  void Function(String step)? afterStep;

  Future<void> _tail = Future.value();

  /// Runs [body] after every operation already queued on this object.
  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// The resync (see the class comment) at [now]. Two wanted alarms with one
  /// id are an [ArgumentError].
  Future<AlarmSyncReport> resync({
    required Iterable<ScheduledAlarm> wanted,
    required DateTime now,
  }) => _serial(() => _resync(wanted, now));

  /// Snoozes [alarm] until [until] and arms it there at once (registered
  /// first), as a notification's +10 min does in the background; the next
  /// [resync] keeps it while [alarm] is wanted. False when the platform
  /// refused it (the snooze is kept for the next resync). [until] is a UTC
  /// instant; with no [SnoozeStore] it is a [StateError].
  Future<bool> snooze(ScheduledAlarm alarm, {required DateTime until}) =>
      _serial(() async {
        final store = _snoozes;
        if (store == null) {
          throw StateError('this AlarmSync has no SnoozeStore');
        }
        await store.snooze(alarm.alarmId, until);
        final entry = await _registry.register(
          ScheduledAlarm(
            alarmId: alarm.alarmId,
            atUtc: until,
            content: alarm.content,
          ),
        );
        return _scheduler.schedule(entry);
      });

  Future<AlarmSyncReport> _resync(
    Iterable<ScheduledAlarm> wanted,
    DateTime now,
  ) async {
    final byId = <String, ScheduledAlarm>{};
    for (final alarm in wanted) {
      alarm.validate();
      if (byId.containsKey(alarm.alarmId)) {
        throw ArgumentError.value(alarm.alarmId, 'wanted', 'a second alarm');
      }
      byId[alarm.alarmId] = alarm;
    }
    if (_snoozes case final store?) {
      for (final s in await store.retain(byId.keys.toSet(), now: now)) {
        final alarm = byId[s.alarmId]!;
        byId[s.alarmId] = ScheduledAlarm(
          alarmId: s.alarmId,
          atUtc: s.untilUtc,
          content: s.content ?? alarm.content,
        );
      }
    }
    final fired = {
      for (final f in await _registry.fires())
        (f.alarmId, f.scheduledAtUtc.millisecondsSinceEpoch),
    };
    final grace = lateGrace;
    final eligible = [
      for (final alarm in byId.values)
        if (!fired.contains((
              alarm.alarmId,
              alarm.atUtc.millisecondsSinceEpoch,
            )) &&
            (grace == null || now.difference(alarm.atUtc) <= grace))
          alarm,
    ];
    final plan = planAlarms(
      wanted: eligible,
      registered: await _registry.entries(),
      size: windowSize,
    );

    final codes = await _registry.pendingCancels();
    for (final entry in plan.cancel) {
      await _scheduler.cancel(entry.platformId);
    }
    for (final code in codes) {
      await _scheduler.cancel(code);
    }
    afterStep?.call('cancelled');
    await _registry.unregisterAll([
      for (final e in plan.cancel) e.alarmId,
    ], pendingCancels: codes);
    afterStep?.call('unregistered');

    final entries = await _registry.registerAll(plan.arm);
    afterStep?.call('registered');
    final refused = <RegisteredAlarm>[];
    for (final entry in entries) {
      if (!await _scheduler.schedule(entry)) refused.add(entry);
    }
    afterStep?.call('scheduled');
    if (refused.isNotEmpty) {
      for (final entry in refused) {
        await _scheduler.cancel(entry.platformId);
      }
      await _registry.unregisterAll([for (final e in refused) e.alarmId]);
    }
    return AlarmSyncReport(
      scheduled: entries.length - refused.length,
      cancelled: plan.cancel.length + codes.length,
      refused: refused.length,
    );
  }
}

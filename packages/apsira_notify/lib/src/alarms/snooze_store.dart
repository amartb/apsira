// New in apsira_notify (D-APK-022, ruling R-4 Q2-b-install): the per-install
// home of LYCEUM's snoozes, with the registry's file discipline (viaticum
// lib/data/platform/alarm_manager_scheduler.dart @ 78d38e0).
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'alarm_scheduler.dart';
import 'json_file.dart';

/// A snooze: the alarm [alarmId] fires at [untilUtc] in place of its own
/// time, with [content] when the snooze carries its own.
final class Snooze {
  const Snooze({required this.alarmId, required this.untilUtc, this.content});

  final String alarmId;
  final DateTime untilUtc;
  final Map<String, Object?>? content;

  @override
  String toString() => 'Snooze($alarmId until ${untilUtc.toIso8601String()})';
}

/// The snoozes made from a notification (+10 min, Snooze…), per install: a
/// file under app storage beside the alarm registry, never in the database
/// or a backup, so a restore never brings one back (D-APK-022).
///
/// `AlarmSync` applies a snooze while its alarm is wanted and the snooze is
/// ahead, so a resync never cancels it, and prunes the rest. Written whole
/// (`.tmp`, flush, rename), one file `{snoozes[]}`.
final class SnoozeStore {
  /// [storage] is app storage: the app's private support directory.
  SnoozeStore(this._storage, {this.path = defaultPath});

  /// Beside the alarm registry, in the folder the backup rules exclude.
  static const defaultPath = 'alarms/snoozes.json';

  final Future<Directory> Function() _storage;

  /// The store's path under app storage.
  final String path;

  /// Told each step of a write (`tmpWritten`, `renamed`).
  @visibleForTesting
  void Function(String step)? afterStep;

  Future<File> _file() async => File('${(await _storage()).path}/$path');

  /// Snoozes [alarmId] until [untilUtc] (a UTC instant), replacing any snooze
  /// of it; [content] is the fire's content when it differs from the
  /// alarm's own.
  Future<void> snooze(
    String alarmId,
    DateTime untilUtc, {
    Map<String, Object?>? content,
  }) async {
    ScheduledAlarm(
      alarmId: alarmId,
      atUtc: untilUtc,
      content: content ?? const {},
    ).validate();
    final all = {for (final s in await this.all()) s.alarmId: s};
    all[alarmId] = Snooze(
      alarmId: alarmId,
      untilUtc: untilUtc,
      content: content,
    );
    await _write(all.values);
  }

  /// Every snooze, expired ones included.
  Future<List<Snooze>> all() async {
    final json = await readJsonObject(await _file(), 'snooze store');
    if (json == null) return const [];
    try {
      return [
        for (final e in (json['snoozes']! as List).cast<Map<String, Object?>>())
          Snooze(
            alarmId: e['alarmId']! as String,
            untilUtc: DateTime.fromMillisecondsSinceEpoch(
              e['untilUtcMs']! as int,
              isUtc: true,
            ),
            content: (e['content'] as Map?)?.cast<String, Object?>(),
          ),
      ];
    } on TypeError {
      throw const FormatException('snooze store: a field is missing');
    }
  }

  /// The snoozes still ahead of [now].
  Future<List<Snooze>> active(DateTime now) async => [
    for (final s in await all())
      if (s.untilUtc.isAfter(now)) s,
  ];

  /// Drops the snooze of [alarmId] (Done from the notification).
  Future<void> clear(String alarmId) async {
    final all = await this.all();
    if (all.every((s) => s.alarmId != alarmId)) return;
    await _write(all.where((s) => s.alarmId != alarmId));
  }

  /// Keeps only the snoozes ahead of [now] whose alarm is in [alarmIds], and
  /// answers them; nothing is written when none goes.
  Future<List<Snooze>> retain(
    Set<String> alarmIds, {
    required DateTime now,
  }) async {
    final all = await this.all();
    final kept = [
      for (final s in all)
        if (s.untilUtc.isAfter(now) && alarmIds.contains(s.alarmId)) s,
    ];
    if (kept.length != all.length) await _write(kept);
    return kept;
  }

  Future<void> _write(Iterable<Snooze> snoozes) async =>
      writeJsonWhole(await _file(), {
        'snoozes': [
          for (final s in snoozes)
            {
              'alarmId': s.alarmId,
              'untilUtcMs': s.untilUtc.millisecondsSinceEpoch,
              'content': ?s.content,
            },
        ],
      }, afterStep: afterStep);
}

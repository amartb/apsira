// From viaticum lib/data/platform/alarm_manager_scheduler.dart @ 78d38e0
// (AlarmStore, AlarmRegistry, RegisteredAlarm, FiredAlarm: the registry's
// path, format and file discipline kept), with RELAY's request codes handed
// over once as pending cancels (D-APK-022).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'alarm_scheduler.dart';
import 'json_file.dart';

/// The alarms this install armed: a file under app storage, never in the
/// database or a backup, so a restored database never re-arms an alarm and
/// another phone's alarms never travel here (D-APK-022). The app's Android
/// backup rules exclude its folder (`expectExcludedFromDeviceBackup`).
///
/// Two files in the folder of [path], one writer each:
/// - the registry ([path], `{nextPlatformId, alarms[], pendingCancels[]}`),
///   which only the app's engine writes, whole (`.tmp`, flush, rename);
/// - the fire record (`fired.jsonl` beside it), to which only alarm engines
///   append, one JSON line per fire ([markFired]).
///
/// Each platform id is handed out once ([RegisteredAlarm.platformId]): an
/// alarm id keeps its id while it stays registered, and a new one takes
/// `nextPlatformId`. `AlarmSync` is the registry's only writer of entries.
final class AlarmRegistry {
  /// [storage] is app storage: the app's private support directory.
  AlarmRegistry(this._storage, {this.path = defaultPath});

  /// VIATICUM's registry, kept where its installs have it.
  static const defaultPath = 'alarms/registry.json';

  /// The fire record's name, beside the registry.
  static const firedName = 'fired.jsonl';

  final Future<Directory> Function() _storage;

  /// The registry's path under app storage.
  final String path;

  /// Told each step of a registry write (`tmpWritten`, `renamed`): the crash
  /// matrix's kill points.
  @visibleForTesting
  void Function(String step)? afterStep;

  Future<File> _registry() async => File('${(await _storage()).path}/$path');

  Future<File> _fired() async =>
      File('${(await _registry()).parent.path}/$firedName');

  /// Every entry, fired ones included, in the file's order.
  Future<List<RegisteredAlarm>> entries() async => [
    ...(await _read()).alarms.values,
  ];

  /// The entries that have not fired at the instant they are registered for,
  /// soonest first (by id at the same instant): what is armed.
  Future<List<RegisteredAlarm>> registered() async {
    final fired = await _firedAt();
    return [
      for (final e in (await _read()).alarms.values)
        if (!fired.contains((e.alarmId, e.atUtc.millisecondsSinceEpoch))) e,
    ]..sort(_soonestFirst);
  }

  /// Registers [alarm] and answers its entry; written before the caller arms
  /// it, so the registry always names every armed alarm.
  Future<RegisteredAlarm> register(ScheduledAlarm alarm) async =>
      (await registerAll([alarm])).single;

  /// Registers every alarm of [alarms] in one write; their entries in order.
  /// Nothing is written when the registry already holds them as they are.
  Future<List<RegisteredAlarm>> registerAll(
    Iterable<ScheduledAlarm> alarms,
  ) async {
    final file = await _registry();
    final registry = await _readFile(file);
    final entries = {...registry.alarms};
    var next = registry.nextPlatformId;
    final out = <RegisteredAlarm>[];
    for (final alarm in alarms) {
      alarm.validate();
      final kept = entries[alarm.alarmId]?.platformId;
      final platformId = kept ?? next;
      if (!RegisteredAlarm.isValidPlatformId(platformId)) {
        throw StateError('the alarm registry has no platform id left');
      }
      if (kept == null) next = platformId + 1;
      final entry = RegisteredAlarm(
        alarmId: alarm.alarmId,
        platformId: platformId,
        atUtc: alarm.atUtc,
        content: alarm.content,
      );
      entries[alarm.alarmId] = entry;
      out.add(entry);
    }
    await _writeIfChanged(
      file,
      registry,
      _Registry(
        alarms: entries,
        nextPlatformId: next,
        pendingCancels: registry.pendingCancels,
      ),
    );
    return out;
  }

  /// Drops [alarmId]; written after the caller cancelled it on the platform.
  Future<void> unregister(String alarmId) => unregisterAll([alarmId]);

  /// Drops every alarm of [alarmIds], and the codes of [pendingCancels], in
  /// one write; nothing is written when none is there.
  Future<void> unregisterAll(
    Iterable<String> alarmIds, {
    Iterable<int> pendingCancels = const [],
  }) async {
    final file = await _registry();
    final registry = await _readFile(file);
    final drop = alarmIds.toSet();
    final cleared = pendingCancels.toSet();
    await _writeIfChanged(
      file,
      registry,
      _Registry(
        alarms: {
          for (final MapEntry(:key, :value) in registry.alarms.entries)
            if (!drop.contains(key)) key: value,
        },
        nextPlatformId: registry.nextPlatformId,
        pendingCancels: [
          for (final code in registry.pendingCancels)
            if (!cleared.contains(code)) code,
        ],
      ),
    );
  }

  /// Platform codes to cancel once, with no alarm of the registry's behind
  /// them: RELAY's request codes from before the registry (its schema v12
  /// step hands them over). `AlarmSync` cancels them before it arms anything.
  Future<void> addPendingCancels(Iterable<int> legacyCodes) async {
    final file = await _registry();
    final registry = await _readFile(file);
    final codes = [...registry.pendingCancels];
    for (final code in legacyCodes) {
      if (!RegisteredAlarm.isValidPlatformId(code)) {
        throw ArgumentError.value(code, 'legacyCodes', 'not a platform id');
      }
      if (!codes.contains(code)) codes.add(code);
    }
    await _writeIfChanged(
      file,
      registry,
      _Registry(
        alarms: registry.alarms,
        nextPlatformId: registry.nextPlatformId,
        pendingCancels: codes,
      ),
    );
  }

  /// The codes [addPendingCancels] left to cancel.
  Future<List<int>> pendingCancels() async => (await _read()).pendingCancels;

  /// Appends [fire] to the fire record: an alarm engine's only write, so it
  /// never touches the registry the app's engine writes.
  Future<void> markFired(FiredAlarm fire) async {
    final file = await _fired();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode({'alarmId': fire.alarmId, 'platformId': fire.platformId, 'scheduledAtUtcMs': fire.scheduledAtUtc.millisecondsSinceEpoch, 'firedAtUtcMs': fire.firedAtUtc.millisecondsSinceEpoch})}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// The fires recorded, in order; a line that does not parse (a write cut
  /// short) is skipped.
  Future<List<FiredAlarm>> fires() async {
    final file = await _fired();
    if (!await file.exists()) return const [];
    DateTime at(Object? ms) =>
        DateTime.fromMillisecondsSinceEpoch(ms! as int, isUtc: true);
    return [
      for (final line in await file.readAsLines())
        if (_parseFire(line) case final json?)
          FiredAlarm(
            alarmId: json['alarmId']! as String,
            platformId: json['platformId']! as int,
            scheduledAtUtc: at(json['scheduledAtUtcMs']),
            firedAtUtc: at(json['firedAtUtcMs']),
          ),
    ];
  }

  Future<Set<(String, int)>> _firedAt() async => {
    for (final f in await fires())
      (f.alarmId, f.scheduledAtUtc.millisecondsSinceEpoch),
  };

  Future<_Registry> _read() async => _readFile(await _registry());

  /// The registry in [file], or an empty one when there is none yet. One
  /// that does not read is a [FormatException]: the app learns of it rather
  /// than arming over a registry it cannot see.
  Future<_Registry> _readFile(File file) async {
    final json = await readJsonObject(file, 'alarm registry');
    if (json == null) return _Registry.empty;
    try {
      final alarms = <String, RegisteredAlarm>{};
      for (final e in (json['alarms']! as List).cast<Map<String, Object?>>()) {
        final entry = RegisteredAlarm(
          alarmId: e['alarmId']! as String,
          platformId: e['platformId']! as int,
          atUtc: DateTime.fromMillisecondsSinceEpoch(
            e['atUtcMs']! as int,
            isUtc: true,
          ),
          content: {
            for (final MapEntry(:key, :value) in e.entries)
              if (!reservedAlarmKeys.contains(key)) key: value,
          },
        );
        alarms[entry.alarmId] = entry;
      }
      return _Registry(
        alarms: alarms,
        nextPlatformId: json['nextPlatformId']! as int,
        pendingCancels: [
          ...((json['pendingCancels'] as List?) ?? const []).cast<int>(),
        ],
      );
    } on TypeError {
      throw const FormatException('alarm registry: a field is missing');
    }
  }

  Future<void> _writeIfChanged(File file, _Registry was, _Registry now) async {
    final json = now.toJson();
    if (jsonEncode(json) == jsonEncode(was.toJson()) && await file.exists()) {
      return;
    }
    await writeJsonWhole(file, json, afterStep: afterStep);
  }

  static Map<String, Object?>? _parseFire(String line) {
    try {
      final json = jsonDecode(line);
      return json is Map<String, Object?> &&
              json['alarmId'] is String &&
              json['platformId'] is int &&
              json['scheduledAtUtcMs'] is int &&
              json['firedAtUtcMs'] is int
          ? json
          : null;
    } on FormatException {
      return null;
    }
  }
}

int _soonestFirst(RegisteredAlarm a, RegisteredAlarm b) {
  final byTime = a.atUtc.compareTo(b.atUtc);
  return byTime != 0 ? byTime : a.alarmId.compareTo(b.alarmId);
}

/// The registry file's content.
final class _Registry {
  const _Registry({
    required this.alarms,
    required this.nextPlatformId,
    required this.pendingCancels,
  });

  static const empty = _Registry(
    alarms: {},
    nextPlatformId: 1,
    pendingCancels: [],
  );

  final Map<String, RegisteredAlarm> alarms;
  final int nextPlatformId;
  final List<int> pendingCancels;

  /// VIATICUM's format: `pendingCancels` only when it holds a code.
  Map<String, Object?> toJson() => {
    'nextPlatformId': nextPlatformId,
    'alarms': [
      for (final r in alarms.values)
        {
          'alarmId': r.alarmId,
          'atUtcMs': r.atUtc.millisecondsSinceEpoch,
          ...r.content,
          'platformId': r.platformId,
        },
    ],
    if (pendingCancels.isNotEmpty) 'pendingCancels': pendingCancels,
  };
}

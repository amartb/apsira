// Rename durability, ported from viaticum
// test/data/db/rename_durability_test.dart @ 78d38e0 onto RELAY's opener,
// which adds the migrating marker (D-APK-018, AC-13.3): every rename the
// opener makes (the pre-migration snapshot's `.partial` into place, a
// marker into place, the restored copy over the database) and every
// marker's removal is followed by a sync of its directory before the open
// goes on, and a sync that fails stops it. The sync is a recorder that looks
// at the files when it is called.
import 'dart:io';

import 'package:apsira_db/apsira_db.dart';
import 'package:apsira_db/testing.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixture_database.dart';
import 'support/memory_log.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('apsira_db_rename_'));

  tearDown(() => dir.deleteSync(recursive: true));

  String path(String name) => '${dir.path}/$name';

  String seen(String name) =>
      '$name=${File(path(name)).existsSync() ? 'present' : 'absent'}';

  /// Records each sync with the state of the files the renames touch.
  RecordingSync recorder({bool Function(Directory)? failWhen}) => RecordingSync(
    root: dir,
    failWhen: failWhen,
    observe: (_) => [
      seen('snapshots/fixture.pre-v1.db'),
      seen('snapshots/fixture.pre-v1.db.partial'),
      seen('fixture.db.restore'),
      seen('fixture.db.restoring'),
      seen('fixture.db.migrating'),
    ].join(' '),
  );

  Future<DatabaseOpening<FixtureDatabase>> openAt(
    int version,
    RecordingSync sync, {
    int? failAt,
  }) => openWithSnapshot(
    directory: dir,
    name: 'fixture',
    targetVersion: version,
    open: (e) => FixtureDatabase(
      e,
      schemaVersion: version,
      failAt: failAt,
      onStep: (v) => sync.events.add('step ${(v as int) - 1}->$v'),
    ),
    log: MemoryLog().log,
    syncDirectory: sync.call,
  );

  Future<void> createV1() =>
      createFixture(File(path('fixture.db')), version: 1);

  const before =
      'snapshots/fixture.pre-v1.db=present '
      'snapshots/fixture.pre-v1.db.partial=absent '
      'fixture.db.restore=absent';

  test("the snapshot's rename and the migrating marker are synced before "
      "the migration runs, and the marker's removal after it", () async {
    await createV1();
    final sync = recorder();

    final opening = await openAt(2, sync);
    await (opening as Opened<FixtureDatabase>).database.close();

    expect(sync.events, [
      'sync:snapshots $before fixture.db.restoring=absent '
          'fixture.db.migrating=absent',
      'sync:. $before fixture.db.restoring=absent fixture.db.migrating=present',
      'step 1->2',
      'sync:. $before fixture.db.restoring=absent fixture.db.migrating=absent',
    ]);
  });

  test('a restore syncs after its marker, after the copy\'s rename over the '
      "database, and after the markers' removal", () async {
    await createV1();
    final sync = recorder();

    final opening = await openAt(2, sync, failAt: 2);

    expect(
      (opening as SafeMode<FixtureDatabase>).reason,
      SafeModeReason.migrationFailed,
    );
    await opening.reader?.close();
    expect(sync.events, [
      'sync:snapshots $before fixture.db.restoring=absent '
          'fixture.db.migrating=absent',
      'sync:. $before fixture.db.restoring=absent fixture.db.migrating=present',
      'step 1->2',
      // The marker is durable before the copy goes over the file.
      'sync:. $before fixture.db.restoring=present fixture.db.migrating=present',
      // The rename is durable before the markers go.
      'sync:. $before fixture.db.restoring=present fixture.db.migrating=present',
      // The markers' removal is durable before anything writes again.
      'sync:. $before fixture.db.restoring=absent fixture.db.migrating=absent',
    ]);
    expect(
      File(path('fixture.db')).readAsBytesSync(),
      File(path('snapshots/fixture.pre-v1.db')).readAsBytesSync(),
    );
  });

  test(
    'a snapshot whose rename cannot be synced stops the migration',
    () async {
      await createV1();
      final sync = recorder(failWhen: (_) => true);

      final opening = await openAt(2, sync);

      final safe = opening as SafeMode<FixtureDatabase>;
      expect(safe.reason, SafeModeReason.snapshotFailed);
      await safe.reader?.close();
      expect(sync.events, isNot(contains('step 1->2')));
    },
  );

  test('a restore whose rename cannot be synced keeps its marker, so the next '
      'open finishes it', () async {
    await createV1();
    var syncs = 0;
    // The snapshot's, the migrating marker's and the restore marker's syncs
    // succeed; the rename's fails.
    final sync = recorder(failWhen: (_) => ++syncs >= 4);

    final opening = await openAt(2, sync, failAt: 2);

    final safe = opening as SafeMode<FixtureDatabase>;
    expect(safe.reason, SafeModeReason.restoreFailed);
    await safe.reader?.close();
    expect(File(path('fixture.db.restoring')).existsSync(), isTrue);

    final next = recorder();
    final reopened = await openAt(2, next);
    await (reopened as Opened<FixtureDatabase>).database.close();
    expect(File(path('fixture.db.restoring')).existsSync(), isFalse);
    expect(next.events, contains('step 1->2'));
  });
}

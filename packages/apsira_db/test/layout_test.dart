// The on-disk names (D-APK-018, AC-13.7): RELAY's and VIATICUM's standard
// layout and LYCEUM's own both name the `.migrating` marker; the markers are
// the per-install paths an app keeps out of Android backup; pruning to
// keepSnapshots counts pre-migration snapshots only, never a safety copy.
import 'dart:io';

import 'package:apsira_db/apsira_db.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixture_database.dart';
import 'support/memory_log.dart';

/// LYCEUM's on-disk names (`restore_swap.dart` @ 9f4ff27).
const _lyceum = DatabaseLayout(
  database: 'lyceum.sqlite',
  restoringMarker: 'lyceum.sqlite.restoring',
  migratingMarker: 'lyceum.sqlite.migrating',
  staged: 'restore/lyceum.staged.sqlite',
  safetyCopy: 'snapshots/lyceum.safety.db',
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('apsira_db_layout_'));

  tearDown(() => dir.deleteSync(recursive: true));

  String rel(File f) => f.path.substring(dir.path.length + 1);

  test("the standard layout is RELAY's and VIATICUM's names", () {
    for (final name in ['relay', 'viaticum']) {
      final files = DatabaseFiles(dir, name: name);
      expect(rel(files.database), '$name.db');
      expect(rel(files.restoreMarker), '$name.db.restoring');
      expect(rel(files.restoreMarkerTmp), '$name.db.restoring.tmp');
      expect(rel(files.migratingMarker), '$name.db.migrating');
      expect(rel(files.migratingMarkerTmp), '$name.db.migrating.tmp');
      expect(rel(files.restoreCopy), '$name.db.restore');
      expect(rel(files.safetyCopy), 'snapshots/$name.safety.db');
      expect(files.safetyCopyName, '$name.safety.db');
      expect(rel(files.stagedDatabase), 'restore/$name.staged.db');
      expect(rel(files.snapshot(3)), 'snapshots/$name.pre-v3.db');
      expect(files.layout.perInstallPaths, [
        '$name.db.restoring',
        '$name.db.restoring.tmp',
        '$name.db.migrating',
        '$name.db.migrating.tmp',
      ]);
    }
  });

  test("LYCEUM's layout keeps its names and names its .migrating marker", () {
    final files = DatabaseFiles(dir, name: 'lyceum', layout: _lyceum);
    expect(rel(files.database), 'lyceum.sqlite');
    expect(rel(files.restoreMarker), 'lyceum.sqlite.restoring');
    expect(rel(files.migratingMarker), 'lyceum.sqlite.migrating');
    expect(rel(files.stagedDatabase), 'restore/lyceum.staged.sqlite');
    expect(files.staging.path, '${dir.path}/restore');
    expect(rel(files.safetyCopy), 'snapshots/lyceum.safety.db');
    expect(rel(files.snapshot(2)), 'snapshots/lyceum.pre-v2.db');
    expect(_lyceum.perInstallPaths, [
      'lyceum.sqlite.restoring',
      'lyceum.sqlite.restoring.tmp',
      'lyceum.sqlite.migrating',
      'lyceum.sqlite.migrating.tmp',
    ]);
  });

  for (final keep in [2, 3]) {
    test('keepSnapshots ($keep) prunes pre-migration snapshots only: the '
        'safety copy and the newest $keep stay', () async {
      final files = DatabaseFiles(dir, name: 'lyceum', layout: _lyceum);
      await createFixture(files.database, version: 3);
      files.snapshots.createSync(recursive: true);
      final now = DateTime.now();
      for (final (v, hours) in [(0, 5), (1, 4), (2, 3)]) {
        File('${files.snapshots.path}/lyceum.pre-v$v.db')
          ..writeAsStringSync('older')
          ..setLastModifiedSync(now.subtract(Duration(hours: hours)));
      }
      files.safetyCopy
        ..writeAsStringSync('safety')
        ..setLastModifiedSync(now.subtract(const Duration(hours: 9)));

      final opening = await openWithSnapshot(
        directory: dir,
        name: 'lyceum',
        layout: _lyceum,
        targetVersion: fixtureVersion,
        open: FixtureDatabase.new,
        log: MemoryLog().log,
        keepSnapshots: keep,
      );
      await (opening as Opened<FixtureDatabase>).database.close();

      final left = [
        for (final f in files.snapshots.listSync().whereType<File>())
          f.uri.pathSegments.last,
      ]..sort();
      expect(left, [
        if (keep == 3) 'lyceum.pre-v1.db',
        'lyceum.pre-v2.db',
        'lyceum.pre-v3.db',
        'lyceum.safety.db',
      ]);
      expect(files.safetyCopy.readAsStringSync(), 'safety');
    });
  }
}

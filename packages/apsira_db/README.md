# apsira_db

The database plumbing the Apsira apps share, over each app's own drift database: the opener
with its pre-migration snapshot and read-only safe mode, the background open, the drift
server other isolates connect to, the restore swap, the backup snapshot, directory fsync and
the migration wrapper. RELAY `09b28810`'s code, with VIATICUM `78d38e0`'s integrity check and
snapshot reader and LYCEUM `9f4ff27`'s step hook and file names (D-APK-018); every file names
its source.

## Consuming

Pin by the shared tag, the same ref for every apsira package (D-APK-007, `../README.md`):

```yaml
dependencies:
  apsira_db: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.6.0, path: packages/apsira_db } }
```

`package:apsira_db/apsira_db.dart` is the public surface; `package:apsira_db/testing.dart`
holds the crash-matrix helpers. It depends on `apsira_core` (the `Log`), `drift ^2.35.2`,
`sqlite3 ^3.7.1` and Flutter. Only the opener and the server reach Flutter;
`package:apsira_db/plain.dart` exports everything else (connection, `migrateWithForeignKeysOff`,
snapshot, swap, layout, fsync, `StepHook`) for a plain Dart process or isolate that cannot load
`dart:ui`: an app database library a child process shares, a test's hard-kill child. Import it
there instead of `src/`; the app keeps the barrel, which exports the same symbols. No
`build_runner`, no generated code.

```dart
final server = DatabaseServer(registry: const IsolatePortRegistry(),
    portName: databasePortName('relay'));                 // relay.database
final opening = await openWithSnapshot(
  directory: appSupport, name: 'relay', targetVersion: RelayDatabase.currentVersion,
  open: RelayDatabase.new, log: log, connect: server.connect);
switch (opening) {
  case Opened(:final database): await server.publish();  // ready
  case SafeMode(:final reason, :final reader): ...        // read-only, resetFromSnapshot / eraseDatabase
}
```

The package's own tests use the host's `libsqlite3` (`hooks: user_defines: sqlite3: source:
system` in its pubspec), at Fedora's `/usr/lib64/libsqlite3.so.0`: `sqlite-libs` ships only
the versioned name, and the bare `libsqlite3.so` needs `sqlite-devel`. Hooks read that from the
root package only, so an app keeps the library `sqlite3`'s build hook bundles.

## File names: `DatabaseLayout`

`DatabaseLayout.standard(name)` is RELAY's and VIATICUM's: `<name>.db`, `<name>.db.restoring`,
`<name>.db.migrating`, `restore/<name>.staged.db`, `snapshots/<name>.safety.db`, with the
pre-migration snapshots at `snapshots/<name>.pre-v<N>.db`. LYCEUM passes its own, so no file
an installed version wrote moves:

```dart
const lyceumLayout = DatabaseLayout(
  database: 'lyceum.sqlite',
  restoringMarker: 'lyceum.sqlite.restoring',
  migratingMarker: 'lyceum.sqlite.migrating',
  staged: 'restore/lyceum.staged.sqlite',
  safetyCopy: 'snapshots/lyceum.safety.db',
);
// openWithSnapshot(directory: docs, name: 'lyceum', layout: lyceumLayout, ...)
```

`layout.perInstallPaths` lists the markers and their `.tmp`, which every app excludes from
Android's cloud backup and device transfer (adoption .6). `keepSnapshots` (default 2) counts
pre-migration snapshots only: a safety copy is never counted or removed by the rotation.

## The restore

RELAY's protocol, each step durable before the next: `beginRestore` (the marker's `.tmp`, while
the database is open), `writeSafetyCopy` (closed), `armRestore`, `swapIn`, the restore's own
`openWithSnapshot(restoring: true)` with the app's rebuild and integrity check, then
`finishRestore`, or `rollBack` on a failure. The restored file stands only once
`finishRestore` has removed the marker; a crash before that puts the safety copy back at the
next open. Safety copies stay until `dropCoveredSafetyCopies` finds a later successful backup.
The opener, and `recoverInterruptedRestore` without one, also read a LYCEUM 1.0.x marker
(`swap`, `rollback`) by LYCEUM's own rules.

## Kill points and `testing.dart`

Every swap, roll back, snapshot and migration step calls `onStep` with its step
(`SwapStep`, `RollBackStep`, `SnapshotStep`, `OpenStep`) once it is done. An app's crash
matrix passes `crashAfter(step)`, which throws `SimulatedCrash`; the code lets it through
untouched, so the test drops its handles and opens again from the files. `testing.dart` also
gives `RecordingSync` (the order of steps and syncs), `expectOneWholeDatabase(files,
versions:)`, `killEveryMigrationStep(...)` (a crash after each step of the app's upgrade, then
a whole reopen), `hardKill(step, script:)` (SIGKILL of a plain Dart child at a step) and
`FakePortRegistry`. The package's own matrix is `test/crash_matrix_test.dart` (KP-M1…M6,
KP-R1…R11, KP-S1…S4, KP-X1).

## What replaces what

| Symbol | Replaces |
|---|---|
| `openWithSnapshot`, `DatabaseOpening`, `Opened`, `SafeMode`, `SafeModeReason`, `ReadOnlyDatabase`, `OpenStep` | RELAY and VIATICUM `lib/data/db/opener.dart`; LYCEUM `lib/data/db/opener.dart`'s `openLyceumConnection` (`LazyDatabase` + recovery) |
| `openForBackground`, `BackgroundOpening`, `OpenedInBackground`, `NotReady`, `NotReadyReason` | RELAY and VIATICUM `lib/data/db/opener.dart` |
| `restoreSafetyCopy`, `hasSnapshot`, `resetFromSnapshot`, `eraseDatabase`, `defaultKeepSnapshots` | RELAY and VIATICUM `lib/data/db/opener.dart` |
| `DatabaseLayout`, `DatabaseFiles` | RELAY and VIATICUM `DatabaseFiles` (`opener.dart`); LYCEUM `RestoreFiles` (`restore_swap.dart`) |
| `beginRestore`, `writeSafetyCopy`, `armRestore`, `swapIn`, `finishRestore`, `abandonRestore`, `safetyCopies`, `dropCoveredSafetyCopies`, `discardStaging`, `databaseHeaderVersion` | RELAY and VIATICUM `lib/data/db/restore_swap.dart`; LYCEUM `restore_swap.dart`'s `swapIn`, `safetyCopies`, `dropCoveredSafetyCopies` (an `int` of milliseconds, RELAY's) |
| `rollBack`, `recoverInterruptedRestore`, `RecoveryOutcome`, `SwapStep`, `RollBackStep` | LYCEUM `lib/data/db/restore_swap.dart` (RELAY's protocol under LYCEUM's names) |
| `integrityCheckPasses` | VIATICUM `lib/data/db/restore_swap.dart` |
| `snapshot` (`leavesOut`), `SnapshotStep`, `SnapshotTargetIsLive`, `openSnapshot`, `tableCounts` | RELAY, VIATICUM and LYCEUM `lib/data/db/backup_snapshot.dart` (RELAY's `snapshotLeavesOut` is the app's `leavesOut`; `entityCounts` is `tableCounts(db, tables)`) |
| `readSnapshot`, `SnapshotInfo` | VIATICUM `lib/data/db/backup_snapshot.dart` (`app_meta` through `schemaVersionQuery`) |
| `DatabaseServer`, `connectByName`, `databasePortName`, `PortRegistry`, `IsolatePortRegistry`, `DatabaseServerGone` | RELAY and VIATICUM `lib/data/db/server.dart` (RELAY's, with `2520b90b`) |
| `SyncDirectory`, `fsyncDirectory` | RELAY `opener.dart`, LYCEUM `restore_swap.dart`; VIATICUM `DirectorySync`, `syncDirectoryToDisk` |
| `Connect`, `openDatabaseFile`, `applyPragmas` | RELAY `openRelayDatabase`, VIATICUM `openViaticumDatabase`, LYCEUM `openLyceumDatabase` (`connection.dart`) |
| `migrateWithForeignKeysOff` | RELAY and VIATICUM `lib/data/db/migrations/migrate.dart` |
| `StepHook`, `SimulatedCrash`, `crashAfter`, `RecordingSync`, `FakePortRegistry` | LYCEUM's `afterStep` seam and `_Crash`; VIATICUM's rename recorder; RELAY `test/data/db/fake_port_registry.dart` |

VIATICUM's `DbLog` goes: the opener logs through `apsira_core`'s `Log` with RELAY's event codes
(`db.snapshot`, `db.opened`, `db.migrationFailed`, `db.restored`, …; one more, LYCEUM's
`db.restoreRecovered`), which VIATICUM's codes already were.

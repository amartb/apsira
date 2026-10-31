# apsira_db changelog

One section per release, naming any migration a consumer must make. Every package shares
one tag, `apsira-vX.Y.Z` (D-APK-007).

## 0.5.0 — 2026-10-31

- test-only: the sqlite3 hook names Fedora's `/usr/lib64/libsqlite3.so.0`; consumers unaffected
  (hooks read `user_defines` from the root package only). No migration.

## 0.4.0 — 2026-10-24

First release (D-APK-018): RELAY `09b28810`'s opener, background open, server (with
`2520b90b`), restore swap, backup snapshot, `fsyncDirectory` and `migrateWithForeignKeysOff`,
generic over the app's database and its `DatabaseLayout`; VIATICUM's `integrityCheckPasses`
and `readSnapshot`; LYCEUM's step hook on every step, and its recovery of a 1.0.x marker. The
backup snapshot is now written through `<path>.tmp`, flushed, renamed and synced (KP-S1).
`package:apsira_db/plain.dart` is the Flutter-free part (everything but the opener and the
server), for plain Dart child processes (F6).

**Every app.** Delete the copies this package holds (README, "What replaces what") and pass
the database's `name` to every opener call; exclude `layout.perInstallPaths` from Android's
cloud backup and device transfer.

**Migration for RELAY.** `databasePortName` is `databasePortName('relay')`;
`DatabaseServer(registry:, portName:)`; `connectByName(registry, portName)`;
`snapshotLeavesOut` becomes `snapshot(..., leavesOut: [...])` and `entityCounts(db)`
becomes `tableCounts(db, names)`; `openSnapshot(path, RelayDatabase.new)`. No stored file or
log code changes.

**Migration for VIATICUM.** `DbLog` goes for `apsira_core`'s `Log` (the same codes); the
async `syncDirectoryToDisk` goes for the sync `fsyncDirectory` (call sites drop `await`; a
failed sync throws); `dropCoveredSafetyCopies` takes `latestOkBackupStart` in milliseconds;
`readSnapshot` reads `app_meta` through `schemaVersionQuery`. The opener gains the
`.migrating` marker, so a background open backs off during a migration; the server gains
`2520b90b`.

**Migration for LYCEUM.** The opener becomes `openWithSnapshot` on `lyceumLayout` (README),
with pre-migration snapshots and safe mode (ruling R-5 Q3-a), and the swap RELAY's protocol
(`beginRestore` … `finishRestore`, `rollBack`), which copies the live file into the safety
copy where LYCEUM renamed it. A restore cut short by a 1.0.x build is still recovered by
LYCEUM's rules. `lyceum.sqlite.migrating` joins the backup exclusions.

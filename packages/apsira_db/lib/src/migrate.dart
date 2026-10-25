// From relay lib/data/db/migrations/migrate.dart @ 09b28810 (VIATICUM's
// lib/data/db/migrations/migrate.dart @ 78d38e0 is the same but a comment).
/// The migration wrapper. Plain Dart.
library;

import 'package:drift/drift.dart';

/// Runs [steps] as one transaction with foreign keys off.
///
/// `PRAGMA foreign_keys` is a no-op inside a transaction, so it is turned
/// off here, before the transaction opens: rebuilding a parent table (drift's
/// `alterTable`, or a hand-written copy-drop-rename) then never cascades
/// into its children. `PRAGMA foreign_key_check` runs before the commit, so
/// a migration that leaves a dangling reference rolls back whole. Foreign
/// keys are back on afterwards, whatever happened.
Future<void> migrateWithForeignKeysOff(
  GeneratedDatabase db,
  Future<void> Function() steps,
) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  try {
    await db.transaction(() async {
      await steps();
      final dangling = await db.customSelect('PRAGMA foreign_key_check').get();
      if (dangling.isNotEmpty) {
        throw StateError(
          'migration left ${dangling.length} dangling foreign keys',
        );
      }
    });
  } finally {
    await db.customStatement('PRAGMA foreign_keys = ON');
  }
}

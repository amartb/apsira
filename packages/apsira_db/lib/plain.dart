/// `apsira_db` without Flutter, for a plain Dart process or isolate that
/// cannot load `dart:ui`: RELAY's database child processes (its kill-writer
/// and kill-snapshot tests) and the app database library they share with the
/// app. The connection and its pragmas, the migration wrapper, the snapshot,
/// the restore swap, the file layout and directory fsync; the opener and the
/// drift server reach Flutter and stay in `apsira_db.dart`. Keep it so:
/// plain_library_test.dart runs it under the Dart VM.
///
/// `package:apsira_db/apsira_db.dart` exports the same symbols, for the app.
library;

export 'src/connection.dart';
export 'src/fsync.dart' show SyncDirectory, fsyncDirectory;
export 'src/layout.dart';
export 'src/migrate.dart';
export 'src/snapshot.dart';
export 'src/step_hook.dart' show StepHook;
export 'src/swap.dart'
    show
        RecoveryOutcome,
        RollBackStep,
        SwapStep,
        abandonRestore,
        armRestore,
        beginRestore,
        databaseHeaderVersion,
        discardStaging,
        dropCoveredSafetyCopies,
        finishRestore,
        integrityCheckPasses,
        recoverInterruptedRestore,
        rollBack,
        safetyCopies,
        swapIn,
        writeSafetyCopy;

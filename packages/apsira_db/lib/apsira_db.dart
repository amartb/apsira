/// The database plumbing every Apsira app shares (D-APK-018): the opener
/// with its pre-migration snapshot and safe mode, the background open, the
/// drift server, the restore swap, the backup snapshot, directory fsync and
/// the migration wrapper, over the app's own drift database and its file
/// names ([DatabaseLayout]). RELAY's code; see the README for what each
/// symbol replaces in each app.
library;

export 'src/connection.dart';
export 'src/fsync.dart' show SyncDirectory, fsyncDirectory;
export 'src/layout.dart';
export 'src/migrate.dart';
export 'src/opener.dart';
export 'src/server.dart';
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

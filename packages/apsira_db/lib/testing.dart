/// The test side of `apsira_db`, for the package's own crash matrix and the
/// apps' (D-APK-018): the simulated crash and its step hook, the recording
/// sync, the whole-database check, the kill of every migration step, the
/// hard kill of a child process, and the fake port registry. For tests only.
library;

export 'src/step_hook.dart' show SimulatedCrash, StepHook;
export 'src/testing/checks.dart';
export 'src/testing/crash.dart';
export 'src/testing/fake_port_registry.dart';
export 'src/testing/hard_kill.dart';
export 'src/testing/recording_sync.dart';

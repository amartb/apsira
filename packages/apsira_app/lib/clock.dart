/// [SystemClock] alone, for a plain Dart process or isolate that cannot load
/// Flutter (no `dart:ui`): RELAY's kill-during-typing child process, for one.
/// It reaches only `apsira_core`; keep it so (clock_library_test.dart runs
/// it under the Dart VM).
///
/// `package:apsira_app/apsira_app.dart` exports the same class, for the app.
library;

export 'src/system_clock.dart';

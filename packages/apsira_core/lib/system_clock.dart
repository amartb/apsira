/// [SystemClock], the device's [Clock]: pure Dart (no Flutter, no
/// `dart:ui`), so a plain Dart process or a background isolate can use it.
///
/// A library of its own, not exported by `apsira_core.dart`, so an app that
/// still declares its own `SystemClock` never meets an ambiguous import.
/// `package:apsira_app` re-exports this same class.
library;

import 'apsira_core.dart' show Clock;

export 'src/system_clock.dart';

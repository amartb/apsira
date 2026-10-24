// A plain Dart program (no Flutter), like RELAY's kill_writer child process:
// clock_library_test.dart runs it under the Dart VM, which has no dart:ui, so
// it starts only if package:apsira_app/clock.dart reaches no Flutter library.
import 'dart:io';

import 'package:apsira_app/clock.dart';

void main() {
  const clock = SystemClock();
  SystemClock.useZone('Europe/Madrid');
  stdout.writeln('zone=${clock.timeZoneName()} utc=${clock.nowUtc().isUtc}');
}

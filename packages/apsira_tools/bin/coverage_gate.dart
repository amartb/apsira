// From relay tool/coverage_gate.dart @ 5f606e9 (its main)
import 'dart:io';

import 'package:apsira_tools/src/coverage_gate.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCoverageGate(args);
}

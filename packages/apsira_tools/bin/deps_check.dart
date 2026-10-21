// From relay tool/privacy/deps_check.dart @ 5f606e9 (its main)
import 'dart:io';

import 'package:apsira_tools/src/deps_check.dart';

Future<void> main(List<String> args) async {
  exitCode = await runDepsCheck(args);
}

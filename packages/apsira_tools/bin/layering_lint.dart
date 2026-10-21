// From relay tool/layering_lint.dart @ 5f606e9 (its main)
import 'dart:io';

import 'package:apsira_tools/src/layering_lint.dart';

Future<void> main(List<String> args) async {
  exitCode = await runLayeringLint(args);
}

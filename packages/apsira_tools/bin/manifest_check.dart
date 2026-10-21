// From relay tool/privacy/manifest_check.dart @ 5f606e9 (its main)
import 'dart:io';

import 'package:apsira_tools/src/manifest_check.dart';

Future<void> main(List<String> args) async {
  exitCode = await runManifestCheck(args);
}

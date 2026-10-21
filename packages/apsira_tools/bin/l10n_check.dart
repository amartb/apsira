// From relay tool/l10n_check.dart @ 5f606e9 (its main)
import 'dart:io';

import 'package:apsira_tools/src/l10n_check.dart';

Future<void> main(List<String> args) async {
  exitCode = await runL10nCheck(args);
}

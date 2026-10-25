// The control for envelope_main.dart: the barrel, which holds the dump and
// the loader, reaches drift, sqlite3 and dart:io, so a walk that missed them
// would fail envelope_library_test.dart here.
// ignore: unused_import
import 'package:apsira_exchange/apsira_exchange.dart';

import 'reach.dart';

void main() => printReach('package:apsira_exchange/apsira_exchange.dart');

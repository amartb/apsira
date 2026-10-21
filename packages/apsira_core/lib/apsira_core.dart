/// The pure-Dart core every Apsira app shares: expected failures as values
/// ([Result], [Failure]), the content-free log model ([Log]), and the only
/// sources of time ([Clock]) and identifiers ([IdGen]).
///
/// Test fakes for the ports are in `package:apsira_core/testing.dart`.
library;

export 'src/clock.dart';
export 'src/id_gen.dart';
export 'src/log.dart';
export 'src/result.dart';

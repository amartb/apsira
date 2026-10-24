/// The pure-Dart core every Apsira app shares: expected failures as values
/// ([Result], [Failure]), the content-free log model ([Log]), the only
/// sources of time ([Clock]) and identifiers ([IdGen], with the monotonic
/// UUIDv7 [MonotonicIdGen]), the FTS5 MATCH string of a text search
/// ([ftsMatch]) and canonical JSON ([encodeSortedJson]).
///
/// Test fakes for the ports are in `package:apsira_core/testing.dart`.
library;

export 'src/canonical_json.dart';
export 'src/clock.dart';
export 'src/fts_match.dart';
export 'src/id_gen.dart';
export 'src/log.dart';
export 'src/monotonic_id_gen.dart';
export 'src/result.dart';

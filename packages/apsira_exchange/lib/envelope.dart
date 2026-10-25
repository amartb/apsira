/// The envelope alone (D-APK-019, ruling R-11): [ExportEnvelope],
/// [Producer], [formatInstant] and the reader [checkEnvelope] /
/// [checkEnvelopeUtf8] with its outcomes and [LegacyShape], for an app's
/// pure-Dart domain layer (VIATICUM's exchange readers). It reaches only
/// `apsira_core` and the Dart SDK's core libraries, never drift, sqlite3,
/// `dart:io` or Flutter; keep it so (envelope_library_test.dart runs it in a
/// plain Dart program and lists what it reaches).
///
/// `package:apsira_exchange/apsira_exchange.dart` exports the same, with the
/// dump and the loader, for the data layer.
library;

export 'src/envelope.dart';
export 'src/envelope_check.dart';

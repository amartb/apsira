// A plain Dart program for an app's pure-Dart domain layer (VIATICUM's
// exchange readers): envelope_library_test.dart runs it under the Dart VM.
// It writes and reads an envelope through package:apsira_exchange/envelope.dart
// alone, then lists every library that one reaches, so the test can tell
// that none of them is drift, sqlite3, dart:io or Flutter.
// A program's output, kept free of dart:io: print is dart:core's.
// ignore_for_file: avoid_print

import 'package:apsira_exchange/envelope.dart';

import 'reach.dart';

void main() {
  final read = checkEnvelope(
    {
      'format': 'viaticum.results',
      'format_version': '1.0',
      'produced_at': '2026-10-24T10:00:00Z',
      'producer': {'app': 'viaticum', 'app_version': '1.0.0'},
    },
    formats: {'viaticum.results'},
    currentSchemaVersion: 1,
    legacy: const [LegacyShape.viaticumExchangeV1],
  );
  final readAs = read is EnvelopeOk ? read.readAs?.name : 'refused';
  final written = ExportEnvelope(
    format: 'viaticum.results',
    producedAt: DateTime.utc(2026, 10, 24, 10),
    producer: const Producer('viaticum', '1.0.0'),
    schemaVersion: 1,
  ).encode();
  printReach('package:apsira_exchange/envelope.dart');
  print('readAs=$readAs written=${written.isNotEmpty}');
}

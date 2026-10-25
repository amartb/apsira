// From lyceum lib/domain/export/envelope.dart @ 9f4ff27
/// The export envelope (ruling C2, D-APK-019): every key of an export
/// document but `tables`, sorted, so `tables` comes last and a dump can
/// stream it between [ExportEnvelope.writeHead] and [ExportEnvelope.tail].
///
/// ```text
/// {"format":"lyceum-export","format_version":"1.0",
///  "produced_at":"2026-10-22T21:09:30Z",
///  "producer":{"app":"lyceum","app_version":"0.4.0+7"},
///  "schema_version":2,"tables":{"<table>":[<row>,…],…}}
/// ```
///
/// An app may add keys of its own ([ExportEnvelope.extra]: LYCEUM's
/// top-level `app_version`, VIATICUM's `artifact_id`); readers ignore the
/// keys they do not know (`checkEnvelope`).
library;

import 'package:apsira_core/apsira_core.dart';

/// The `format_version` every app writes. A reader takes every `1.x`.
const String exportFormatVersion = '1.0';

/// The keys the envelope itself writes; [ExportEnvelope.extra] may not use
/// them.
const Set<String> envelopeKeys = {
  'format',
  'format_version',
  'produced_at',
  'producer',
  'schema_version',
  'tables',
};

/// `producer`: the app that wrote the document, and its version
/// (`apsira_core`'s `appVersion`).
final class Producer {
  const Producer(this.app, this.appVersion);

  final String app;
  final String appVersion;

  Map<String, Object?> toJson() => {'app': app, 'app_version': appVersion};

  @override
  bool operator ==(Object other) =>
      other is Producer && other.app == app && other.appVersion == appVersion;

  @override
  int get hashCode => Object.hash(app, appVersion);

  @override
  String toString() => 'Producer($app $appVersion)';
}

/// The envelope an app writes.
final class ExportEnvelope {
  /// [producedAt] is the export's start, from `Clock`; it is written as its
  /// UTC instant to the second. [extra] holds the app's own keys: none may
  /// be one of [envelopeKeys], and none may sort after `tables`, which the
  /// head leaves last; an [ArgumentError] otherwise.
  ExportEnvelope({
    required this.format,
    this.formatVersion = exportFormatVersion,
    required DateTime producedAt,
    required this.producer,
    required this.schemaVersion,
    this.extra = const {},
  }) : producedAt = producedAt.toUtc() {
    for (final key in extra.keys) {
      if (envelopeKeys.contains(key) || key.compareTo('tables') > 0) {
        throw ArgumentError.value(key, 'extra', 'not an extra key');
      }
    }
  }

  /// The document's kind (`lyceum-export`, `relay-export`,
  /// `viaticum.results`).
  final String format;

  final String formatVersion;

  /// UTC.
  final DateTime producedAt;

  final Producer producer;

  /// The app's database schema version when the document was written.
  final int schemaVersion;

  final Map<String, Object?> extra;

  /// Closes the document [writeHead] opened, once the tables are written.
  static const String tail = '}\n';

  /// The envelope's fields, `tables` aside.
  Map<String, Object?> toJson() => {
    ...extra,
    'format': format,
    'format_version': formatVersion,
    'produced_at': formatInstant(producedAt),
    'producer': producer.toJson(),
    'schema_version': schemaVersion,
  };

  /// Writes the document up to the `tables` value: `{` … `"tables":`. The
  /// caller writes the tables object, then [tail].
  void writeHead(StringSink out) {
    final head = encodeSortedJson(toJson());
    out
      ..write(head.substring(0, head.length - 1))
      ..write(',"tables":');
  }

  /// The whole document with [tables], LF-terminated.
  String encode({Map<String, Object?> tables = const {}}) {
    final out = StringBuffer();
    writeHead(out);
    writeSortedJson(tables, out);
    out.write(tail);
    return out.toString();
  }
}

/// [t]'s UTC instant to the second: `YYYY-MM-DDTHH:MM:SSZ`.
String formatInstant(DateTime t) {
  final u = t.toUtc();
  String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
  return '${pad(u.year, 4)}-${pad(u.month)}-${pad(u.day)}T'
      '${pad(u.hour)}:${pad(u.minute)}:${pad(u.second)}Z';
}

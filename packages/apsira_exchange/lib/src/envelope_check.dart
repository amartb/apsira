// From lyceum lib/domain/export/envelope.dart @ 9f4ff27 (checkEnvelope)
/// Reading an export document's envelope back (ruling C2, D-APK-019):
/// [checkEnvelope] takes the envelope `ExportEnvelope` writes, a `1.x`
/// version, and a schema not newer than the app's; and, when the app passes
/// them, the older shapes its released versions wrote ([LegacyShape]). It
/// never throws: every outcome is an [EnvelopeCheck], which the app maps to
/// its own failure codes.
library;

import 'dart:convert';

import 'envelope.dart';

/// A shape a released app wrote before the shared envelope.
enum LegacyShape {
  /// RELAY v1.0.0…v2.0.x `relay.json`: `{appVersion, format, schemaVersion,
  /// tables, version: 1}`, no `produced_at`, no `producer`.
  relayExportV1,

  /// VIATICUM's exchange files up to v1.0.x, and VELLUM's seed and package:
  /// the envelope without `schema_version`.
  viaticumExchangeV1,
}

/// What [checkEnvelope] read from an envelope it accepts.
final class EnvelopeInfo {
  const EnvelopeInfo({
    required this.format,
    required this.formatVersion,
    required this.producedAt,
    required this.producer,
    required this.schemaVersion,
    this.extra = const {},
  });

  final String format;

  /// `format_version`; RELAY's `relay.json` v1 gives its `version` (`"1"`).
  final String formatVersion;

  /// UTC; null for [LegacyShape.relayExportV1], which has none.
  final DateTime? producedAt;

  /// RELAY's v1 gives `Producer('relay', appVersion)`.
  final Producer? producer;

  /// Null for [LegacyShape.viaticumExchangeV1], which has none.
  final int? schemaVersion;

  /// The document's other top-level keys, `tables` aside (LYCEUM's
  /// `app_version`, VIATICUM's `artifact_id`).
  final Map<String, Object?> extra;
}

/// The outcome of [checkEnvelope].
sealed class EnvelopeCheck {
  const EnvelopeCheck();
}

/// The envelope is readable; [readAs] names the legacy shape it was read
/// as, null for the shared envelope.
final class EnvelopeOk extends EnvelopeCheck {
  const EnvelopeOk(this.envelope, {this.readAs});

  final EnvelopeInfo envelope;
  final LegacyShape? readAs;

  @override
  String toString() => 'EnvelopeOk(${envelope.format}, readAs: $readAs)';
}

/// Not a document of the app's formats: another file, another format, an
/// envelope without its fields, or bytes that are not UTF-8 JSON.
/// [reason] names the first field at fault, for tests and logs; it holds no
/// content.
final class NotABundle extends EnvelopeCheck {
  const NotABundle(this.reason);

  final String reason;

  @override
  String toString() => 'NotABundle($reason)';
}

/// A document of the app's format in a version this build does not read
/// ([found]: `format_version`, or RELAY v1's `version`).
final class FormatUnsupported extends EnvelopeCheck {
  const FormatUnsupported(this.found);

  final String found;

  @override
  String toString() => 'FormatUnsupported($found)';
}

/// A document written by a newer schema ([found]) than this build's
/// ([supported]): update the app first.
final class SchemaTooNew extends EnvelopeCheck {
  const SchemaTooNew(this.found, {required this.supported});

  final int found;
  final int supported;

  @override
  String toString() => 'SchemaTooNew($found, reads $supported)';
}

/// The major version this package reads.
const int readableFormatMajor = 1;

final RegExp _version = RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$');

/// The major number of a `format_version` such as `1.0`, or null when
/// [version] is not `<major>.<minor>` in plain decimal digits.
int? formatMajor(String version) {
  final m = _version.firstMatch(version);
  return m == null ? null : int.parse(m.group(1)!);
}

/// Whether [version] is readable: any `1.x`.
bool isReadableFormatVersion(String version) =>
    formatMajor(version) == readableFormatMajor;

/// [checkEnvelope] over the document's bytes: a byte-order mark, bytes
/// that are not UTF-8 or text that is not JSON (a cut file) is
/// [NotABundle]. Never throws.
EnvelopeCheck checkEnvelopeUtf8(
  List<int> bytes, {
  required Set<String> formats,
  required int currentSchemaVersion,
  List<LegacyShape> legacy = const [],
}) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return const NotABundle('byteOrderMark');
  }
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return const NotABundle('notJson');
  }
  return checkEnvelope(
    json,
    formats: formats,
    currentSchemaVersion: currentSchemaVersion,
    legacy: legacy,
  );
}

/// Reads the envelope of a decoded document whose `format` is one of
/// [formats], for an app whose schema is [currentSchemaVersion]; see the
/// library comment. Keys a later `1.x` adds are ignored. `tables` may be
/// absent, for a reader that streams it; when present it must be an object
/// of arrays of objects.
EnvelopeCheck checkEnvelope(
  Object? json, {
  required Set<String> formats,
  required int currentSchemaVersion,
  List<LegacyShape> legacy = const [],
}) {
  if (json is! Map<String, Object?>) return const NotABundle('notAnObject');
  final format = json['format'];
  if (format is! String || !formats.contains(format)) {
    return const NotABundle('format');
  }
  if (!json.containsKey('format_version') &&
      legacy.contains(LegacyShape.relayExportV1) &&
      json.containsKey('version')) {
    return _relayV1(json, format, currentSchemaVersion);
  }
  final version = json['format_version'];
  if (version is! String) return const NotABundle('format_version');
  if (!isReadableFormatVersion(version)) return FormatUnsupported(version);
  if (!_isTables(json)) return const NotABundle('tables');
  final producedAt = _parseInstant(json['produced_at']);
  if (producedAt == null) return const NotABundle('produced_at');
  final producer = json['producer'];
  if (producer is! Map<String, Object?>) return const NotABundle('producer');
  final app = producer['app'];
  final appVersion = producer['app_version'];
  if (app is! String || app.isEmpty || appVersion is! String) {
    return const NotABundle('producer');
  }
  final extra = {
    for (final MapEntry(:key, :value) in json.entries)
      if (!envelopeKeys.contains(key)) key: value,
  };
  final schema = json['schema_version'];
  if (schema == null &&
      !json.containsKey('schema_version') &&
      legacy.contains(LegacyShape.viaticumExchangeV1)) {
    return EnvelopeOk(
      EnvelopeInfo(
        format: format,
        formatVersion: version,
        producedAt: producedAt,
        producer: Producer(app, appVersion),
        schemaVersion: null,
        extra: extra,
      ),
      readAs: LegacyShape.viaticumExchangeV1,
    );
  }
  if (schema is! int || schema < 1) return const NotABundle('schema_version');
  if (schema > currentSchemaVersion) {
    return SchemaTooNew(schema, supported: currentSchemaVersion);
  }
  return EnvelopeOk(
    EnvelopeInfo(
      format: format,
      formatVersion: version,
      producedAt: producedAt,
      producer: Producer(app, appVersion),
      schemaVersion: schema,
      extra: extra,
    ),
  );
}

/// RELAY v1.0.0…v2.0.x: `{appVersion, format, schemaVersion, tables,
/// version: 1}`.
EnvelopeCheck _relayV1(
  Map<String, Object?> json,
  String format,
  int currentSchemaVersion,
) {
  final version = json['version'];
  if (version is! int) return const NotABundle('version');
  if (version != 1) return FormatUnsupported('$version');
  if (!_isTables(json)) return const NotABundle('tables');
  final appVersion = json['appVersion'];
  if (appVersion is! String) return const NotABundle('appVersion');
  final schema = json['schemaVersion'];
  if (schema is! int || schema < 1) return const NotABundle('schemaVersion');
  if (schema > currentSchemaVersion) {
    return SchemaTooNew(schema, supported: currentSchemaVersion);
  }
  return EnvelopeOk(
    EnvelopeInfo(
      format: format,
      formatVersion: '$version',
      producedAt: null,
      producer: Producer('relay', appVersion),
      schemaVersion: schema,
    ),
    readAs: LegacyShape.relayExportV1,
  );
}

bool _isTables(Map<String, Object?> json) {
  final tables = json['tables'];
  return !json.containsKey('tables') ||
      tables is Map<String, Object?> &&
          tables.values.every(
            (rows) =>
                rows is List<Object?> &&
                rows.every((row) => row is Map<String, Object?>),
          );
}

final RegExp _instant = RegExp(
  r'^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})'
  r'(?:\.([0-9]{1,6}))?Z$',
);

DateTime? _parseInstant(Object? value) {
  if (value is! String) return null;
  final m = _instant.firstMatch(value);
  if (m == null) return null;
  final f = [for (var g = 1; g <= 6; g++) int.parse(m.group(g)!)];
  final t = _realUtc(f[0], f[1], f[2], f[3], f[4], f[5]);
  final fraction = m.group(7);
  if (t == null || fraction == null) return t;
  return t.add(Duration(microseconds: int.parse(fraction.padRight(6, '0'))));
}

// From lyceum lib/domain/export/bundle_name.dart @ 9f4ff27 (realUtc)
/// The UTC date-time with these fields, or null when they name no real one
/// (a 30 February, an hour 24): `DateTime.utc` rolls an impossible field
/// over, so a real one is the one that comes back unchanged.
DateTime? _realUtc(int year, int month, int day, int hour, int minute, int s) {
  final t = DateTime.utc(year, month, day, hour, minute, s);
  final real =
      t.year == year &&
      t.month == month &&
      t.day == day &&
      t.hour == hour &&
      t.minute == minute &&
      t.second == s;
  return real ? t : null;
}

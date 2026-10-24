// From lyceum lib/domain/export/canonical_json.dart @ 9f4ff27
/// The bundle's canonical JSON: object keys sorted by code unit at every
/// level, no whitespace between tokens, strings escaped as `dart:convert`
/// escapes them (non-ASCII text is written as is, for UTF-8 without a
/// BOM), BLOBs ([Uint8List]) as standard base64 text. The same value gives
/// the same text, so the same data and clock give the same bundle bytes.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Writes [value] to [out] as canonical JSON.
///
/// [value] is null, a bool, an int, a finite double, a String, a
/// [Uint8List] (written as base64 text), a List of these, or a Map with
/// String keys and these as values. Anything else — a NaN or infinite
/// double, a non-String key, another type — is a bug and throws an
/// [ArgumentError]; part of the value may already be written.
void writeSortedJson(Object? value, StringSink out) {
  switch (value) {
    case null || bool() || int() || String():
      out.write(jsonEncode(value));
    case double():
      if (!value.isFinite) {
        throw ArgumentError.value(value, 'value', 'not a finite number');
      }
      out.write(jsonEncode(value));
    case Uint8List():
      out.write(jsonEncode(base64.encode(value)));
    case List<Object?>():
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        writeSortedJson(value[i], out);
      }
      out.write(']');
    case Map<String, Object?>():
      out.write('{');
      final keys = value.keys.toList()..sort();
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out
          ..write(jsonEncode(keys[i]))
          ..write(':');
        writeSortedJson(value[keys[i]], out);
      }
      out.write('}');
    default:
      throw ArgumentError.value(value.runtimeType, 'value', 'not a JSON value');
  }
}

/// [value] as canonical JSON text (see [writeSortedJson]).
String encodeSortedJson(Object? value) {
  final out = StringBuffer();
  writeSortedJson(value, out);
  return out.toString();
}

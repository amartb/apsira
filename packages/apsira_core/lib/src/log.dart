// From relay lib/core/log.dart @ 5f606e9, with viaticum lib/core/log.dart @
// 78d38e0's stack hash and UUID-only IDs (D-APK-011).
/// Local, content-free logging (architecture §9.3, D-050).
///
/// A record is an event name plus typed fields: IDs, counts, durations,
/// stable codes, flags and error types. There is no free-text argument and an
/// error is recorded by its type (and a [Failure]'s code) and its stack by a
/// hash and its frame lines, never by its `toString()`, which can carry note
/// text. A value without the expected
/// shape is written as [redacted], so a mistake hides data instead of
/// leaking it. Logging never throws.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'result.dart';

/// Severity, most severe first. [debug] is written only in `.dev` builds.
enum LogLevel { error, warning, info, debug }

/// What a rejected name or value is written as.
const String redacted = '<redacted>';

/// Event names are dotted lowerCamel segments, such as `note.saved`.
final _eventShape = RegExp(r'^[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)*$');

/// Field keys and codes are lowerCamel identifiers.
final _codeShape = RegExp(r'^[a-z][a-zA-Z0-9]*$');

/// IDs are UUIDs (D-014). No shorter shape is accepted, since a short
/// lowercase word could be content.
final _idShape = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// RELAY's task-line block IDs: 6 × `a–z0–9` (data model §6.5).
final _blockIdShape = RegExp(r'^[a-z0-9]{6}$');

/// A stack frame line, as the VM and AOT runtimes print them (`#0 …`).
final _frameShape = RegExp(r'^#\d+\s');

/// The most stack frames a record keeps.
const int maxStackFrames = 30;

/// A typed field value. The constructors are the only way to make one, so
/// every value is an ID, a count, a duration, a code, a flag or a type.
sealed class LogValue {
  const LogValue();

  /// A UUID; anything else is [redacted].
  factory LogValue.id(String id) = _Text.id;

  /// A block ID (six characters of `a–z0–9`, RELAY's task lines); anything
  /// else is [redacted].
  factory LogValue.blockId(String id) = _Text.blockId;

  /// A stable lowerCamel code (a failure code, a source, a state); anything
  /// else is [redacted].
  factory LogValue.code(String code) = _Text.code;

  const factory LogValue.count(int count) = _Count;

  const factory LogValue.duration(Duration duration) = _Duration;

  const factory LogValue.flag(bool flag) = _Flag;

  /// The runtime type of [error], never its message.
  factory LogValue.errorType(Object error) =>
      _Text.raw(error.runtimeType.toString());

  /// The value as written in the log.
  String render();
}

final class _Text extends LogValue {
  _Text.id(String id) : text = _idShape.hasMatch(id) ? id : redacted;

  _Text.blockId(String id) : text = _blockIdShape.hasMatch(id) ? id : redacted;

  _Text.code(String code) : text = _codeShape.hasMatch(code) ? code : redacted;

  const _Text.raw(this.text);

  final String text;

  @override
  String render() => text;
}

final class _Count extends LogValue {
  const _Count(this.count);

  final int count;

  @override
  String render() => '$count';
}

final class _Duration extends LogValue {
  const _Duration(this.duration);

  final Duration duration;

  @override
  String render() => '${duration.inMilliseconds}ms';
}

final class _Flag extends LogValue {
  const _Flag(this.flag);

  final bool flag;

  @override
  String render() => '$flag';
}

/// One log entry. Sinks add the timestamp from the `Clock` port.
final class LogRecord {
  LogRecord(
    this.level,
    String event,
    Map<String, LogValue> fields, {
    StackTrace? stack,
  }) : event = _eventShape.hasMatch(event) ? event : redacted,
       fields = Map.unmodifiable(fields),
       stackFrames = List.unmodifiable(_frames(stack)) {
    stackHash = stackFrames.isEmpty ? null : _hash(stackFrames);
  }

  final LogLevel level;

  /// The event name, or [redacted] when it was not a dotted lowerCamel name.
  final String event;

  final Map<String, LogValue> fields;

  /// The stack's frame lines only, at most [maxStackFrames]; any other line
  /// (an exception message a runtime printed into the trace) is dropped.
  final List<String> stackFrames;

  /// The first 16 hex digits of the SHA-256 of [stackFrames], so the same
  /// failure groups under one value across records and files; `null` when
  /// there are no frames.
  late final String? stackHash;

  static Iterable<String> _frames(StackTrace? stack) => stack == null
      ? const []
      : stack
            .toString()
            .split('\n')
            .map((line) => line.trimRight())
            .where(_frameShape.hasMatch)
            .take(maxStackFrames);

  static String _hash(List<String> frames) => sha256
      .convert(utf8.encode(frames.join('\n')))
      .toString()
      .substring(0, 16);

  /// `key=value` pairs in insertion order, then `stackHash` when there is a
  /// stack; a key that is not lowerCamel is written as [redacted].
  List<String> renderFields() => [
    for (final MapEntry(:key, :value) in fields.entries)
      '${_codeShape.hasMatch(key) ? key : redacted}=${value.render()}',
    if (stackHash case final hash?) 'stackHash=$hash',
  ];
}

/// Where records go: the rotating file in the app, memory in tests.
abstract interface class LogSink {
  /// Writes [record]. It may throw; [Log] contains the failure.
  void write(LogRecord record);
}

/// The app's log. Levels error, warning and info always reach the sinks;
/// debug only when [debugEnabled], which is true in `.dev` builds.
final class Log {
  Log(List<LogSink> sinks, {required this.debugEnabled})
    : _sinks = List.unmodifiable(sinks);

  final List<LogSink> _sinks;

  final bool debugEnabled;

  /// Whether a build of [flavor] (Flutter's `appFlavor`) logs debug records.
  static bool debugEnabledFor(String? flavor) => flavor == 'dev';

  void error(
    String event, {
    Object? error,
    StackTrace? stack,
    Map<String, LogValue> fields = const {},
  }) => _emit(LogLevel.error, event, error, stack, fields);

  void warning(
    String event, {
    Object? error,
    StackTrace? stack,
    Map<String, LogValue> fields = const {},
  }) => _emit(LogLevel.warning, event, error, stack, fields);

  void info(String event, {Map<String, LogValue> fields = const {}}) =>
      _emit(LogLevel.info, event, null, null, fields);

  void debug(String event, {Map<String, LogValue> fields = const {}}) {
    if (debugEnabled) _emit(LogLevel.debug, event, null, null, fields);
  }

  void _emit(
    LogLevel level,
    String event,
    Object? error,
    StackTrace? stack,
    Map<String, LogValue> fields,
  ) {
    final record = LogRecord(level, event, {
      if (error != null) 'errorType': LogValue.errorType(error),
      if (error is Failure) 'code': LogValue.code(error.code),
      ...fields,
    }, stack: stack);
    for (final sink in _sinks) {
      try {
        sink.write(record);
      } catch (_) {
        // A full disk or a closed file must not turn logging into a crash;
        // the other sinks still get the record.
      }
    }
  }
}

// A log that keeps its records, as RELAY's tests' `_MemorySink` @ 09b28810.
import 'package:apsira_core/apsira_core.dart';

final class MemoryLog {
  final List<LogRecord> records = [];

  late final Log log = Log([_Sink(records)], debugEnabled: false);

  /// The events, in order.
  List<String> get events => [for (final r in records) r.event];

  /// [record]'s fields as the log writes them.
  static Map<String, String> fields(LogRecord record) => {
    for (final MapEntry(:key, :value) in record.fields.entries)
      key: value.render(),
  };
}

final class _Sink implements LogSink {
  _Sink(this.records);

  final List<LogRecord> records;

  @override
  void write(LogRecord record) => records.add(record);
}

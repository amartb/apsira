// From relay test/app/error_handlers_test.dart `_MemorySink` @ 09b28810
import 'package:apsira_core/apsira_core.dart';

/// A [LogSink] that keeps the records, in order, for a test to read.
final class MemoryLogSink implements LogSink {
  final records = <LogRecord>[];

  @override
  void write(LogRecord record) => records.add(record);
}

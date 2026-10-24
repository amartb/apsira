// From relay test/data/platform/file_log_sink_test.dart @ 09b28810, with
// viaticum's stack-hash line (test/data/platform/file_log_sink_test.dart @
// 78d38e0). The file name is the app's (`relay`, `viaticum`, `lyceum`).
import 'dart:io';

import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

// A rotating log of 5 × 1 MB in the directory the app passes (its private
// storage); lines are stamped from the Clock port, never the system clock.
void main() {
  late Directory root;
  late FakeClock clock;

  setUp(() {
    root = Directory.systemTemp.createTempSync('apsira_file_log_sink_');
    clock = FakeClock(DateTime.utc(2026, 10, 17, 9, 30, 5, 120));
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<FileLogSink> open({
    int maxBytes = FileLogSink.defaultMaxBytes,
    String name = 'relay',
  }) => FileLogSink.open(
    clock,
    directory: () async => root,
    name: name,
    maxBytes: maxBytes,
  );

  LogRecord record(String event, {LogLevel level = LogLevel.info}) =>
      LogRecord(level, event, const {});

  String current([String name = 'relay']) => '${root.path}/logs/$name.log';

  test('defaults to 5 files of 1 MB', () {
    expect(FileLogSink.defaultMaxFiles, 5);
    expect(FileLogSink.defaultMaxBytes, 1024 * 1024);
  });

  test('writes one line per record, stamped from the Clock', () async {
    final sink = await open();
    sink.write(
      LogRecord(LogLevel.error, 'save.failed', {
        'took': LogValue.duration(const Duration(milliseconds: 5)),
      }),
    );
    clock.advance(const Duration(seconds: 1));
    sink.write(record('app.started'));

    expect(File(current()).readAsLinesSync(), [
      '2026-10-17T09:30:05.120Z ERROR save.failed took=5ms',
      '2026-10-17T09:30:06.120Z INFO app.started',
    ]);
    expect(sink.files().map((f) => f.path), [current()]);
  });

  test('the file is named for the app', () async {
    final sink = await open(name: 'viaticum');
    sink.write(record('app.started'));
    expect(sink.files().map((f) => f.path), [current('viaticum')]);
  });

  test('writes the stack hash, then the frames indented', () async {
    final sink = await open();
    final entry = LogRecord(
      LogLevel.error,
      'save.failed',
      const {},
      stack: StackTrace.fromString('#0 f (a.dart:1:1)\n#1 g (b.dart:2:2)'),
    );
    sink.write(entry);
    expect(entry.stackHash, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(File(current()).readAsLinesSync(), [
      '2026-10-17T09:30:05.120Z ERROR save.failed '
          'stackHash=${entry.stackHash}',
      '  #0 f (a.dart:1:1)',
      '  #1 g (b.dart:2:2)',
    ]);
  });

  test('rotates when a file would pass the size cap', () async {
    // Each line is 39 bytes; three fit in 130, a fourth rotates.
    final sink = await open(maxBytes: 130);
    for (var i = 0; i < 4; i++) {
      sink.write(record('event.e$i'));
    }
    final logs = '${root.path}/logs';
    expect(File('$logs/relay.1.log').readAsLinesSync(), hasLength(3));
    expect(File('$logs/relay.log').readAsLinesSync(), [
      '2026-10-17T09:30:05.120Z INFO event.e3',
    ]);
    for (final file in sink.files()) {
      expect(file.lengthSync(), lessThanOrEqualTo(130));
    }
  });

  test('keeps at most 5 files, dropping the oldest', () async {
    final sink = await open(maxBytes: 50);
    for (var i = 0; i < 8; i++) {
      sink.write(record('event.e$i'));
    }
    final files = sink.files();
    expect(files.map((f) => f.uri.pathSegments.last), [
      'relay.4.log',
      'relay.3.log',
      'relay.2.log',
      'relay.1.log',
      'relay.log',
    ]);
    expect(files.first.readAsStringSync(), contains('event.e3'));
    expect(files.last.readAsStringSync(), contains('event.e7'));
    expect(
      Directory('${root.path}/logs').listSync(),
      hasLength(FileLogSink.defaultMaxFiles),
    );
  });

  test('a reopened sink continues the existing file and its size', () async {
    final first = await open(maxBytes: 130);
    first
      ..write(record('event.e0'))
      ..write(record('event.e1'));
    final second = await open(maxBytes: 130);
    second
      ..write(record('event.e2'))
      ..write(record('event.e3'));
    expect(
      File('${root.path}/logs/relay.1.log').readAsLinesSync(),
      hasLength(3),
    );
  });
}

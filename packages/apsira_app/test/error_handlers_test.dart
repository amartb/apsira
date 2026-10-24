// From relay test/app/error_handlers_test.dart @ 09b28810, with
// viaticum's stack hash (78d38e0) and lyceum's planted-message check
// (test/app/error_handlers_test.dart @ 9f4ff27).
import 'dart:ui';

import 'package:apsira_app/apsira_app.dart';
import 'package:apsira_app/testing.dart';
import 'package:apsira_core/apsira_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _planted = 'Chapter 3: the letter to Elena';

final class _Throws extends StatelessWidget {
  const _Throws();

  @override
  Widget build(BuildContext context) => throw StateError(_planted);
}

// FlutterError.onError and PlatformDispatcher.onError route uncaught errors
// to the log; release builds show no red error screen.
void main() {
  late MemoryLogSink sink;
  late Log log;

  setUp(() {
    sink = MemoryLogSink();
    log = Log([sink], debugEnabled: false);
  });

  test('FlutterError.onError routes to the log by error type', () {
    final handlers = ErrorHandlers.install(log, releaseMode: true);
    try {
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError(_planted),
          stack: StackTrace.current,
        ),
      );
    } finally {
      handlers.uninstall();
    }
    final record = sink.records.single;
    expect(record.level, LogLevel.error);
    expect(record.event, 'flutter.error');
    expect(record.renderFields(), [
      'errorType=StateError',
      'stackHash=${record.stackHash}',
    ]);
    expect(record.stackHash, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(record.stackFrames, isNotEmpty);
    expect(record.renderFields().join(' '), isNot(contains('Elena')));
  });

  test('PlatformDispatcher.onError routes to the log and handles it', () {
    final handlers = ErrorHandlers.install(log, releaseMode: true);
    bool? handled;
    try {
      handled = PlatformDispatcher.instance.onError!(
        ArgumentError(_planted),
        StackTrace.current,
      );
    } finally {
      handlers.uninstall();
    }
    expect(handled, isTrue);
    final record = sink.records.single;
    expect(record.event, 'platform.uncaughtError');
    expect(record.renderFields().first, 'errorType=ArgumentError');
  });

  test('uninstall restores the previous handlers', () {
    final flutterBefore = FlutterError.onError;
    final platformBefore = PlatformDispatcher.instance.onError;
    final builderBefore = ErrorWidget.builder;
    ErrorHandlers.install(log, releaseMode: true).uninstall();
    expect(FlutterError.onError, same(flutterBefore));
    expect(PlatformDispatcher.instance.onError, same(platformBefore));
    expect(ErrorWidget.builder, same(builderBefore));
  });

  testWidgets('a release build shows no red error screen', (tester) async {
    final handlers = ErrorHandlers.install(log, releaseMode: true);
    try {
      await tester.pumpWidget(const _Throws());
      expect(find.byType(ErrorWidget), findsNothing);
    } finally {
      handlers.uninstall();
    }
    expect(sink.records.single.event, 'flutter.error');
  });

  testWidgets('a debug build keeps the error screen', (tester) async {
    final handlers = ErrorHandlers.install(
      log,
      releaseMode: false,
      presentError: (_) {},
    );
    try {
      await tester.pumpWidget(const _Throws());
      expect(find.byType(ErrorWidget), findsOneWidget);
    } finally {
      handlers.uninstall();
    }
    expect(sink.records.single.event, 'flutter.error');
  });
}

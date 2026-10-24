// From relay test/core/log_test.dart @ 5f606e9; two bodies changed for
// D-APK-011 (block IDs through LogValue.blockId, VIATICUM's stackHash after
// the fields). VIATICUM's own cases are the last group.
import 'package:apsira_core/apsira_core.dart';
import 'package:test/test.dart';

/// Collects records in memory.
final class _MemorySink implements LogSink {
  final records = <LogRecord>[];

  @override
  void write(LogRecord record) => records.add(record);
}

final class _BrokenSink implements LogSink {
  @override
  void write(LogRecord record) => throw StateError('disk full');
}

final class _NoteError implements Exception {
  _NoteError(this.message);

  final String message;

  @override
  String toString() => 'NoteError: $message';
}

// Architecture §9.3 and D-050: levels error, warning, info and debug (dev
// builds only); records carry an event name and typed fields — IDs, counts,
// durations, error types — and never free text or an exception's toString().
void main() {
  const noteId = '01929a3e-7c1a-7b3e-9f00-1a2b3c4d5e6f';
  const secret = 'Buy flowers for Ana';

  late _MemorySink sink;
  Log logWith({bool debugEnabled = false}) =>
      Log([sink], debugEnabled: debugEnabled);

  setUp(() => sink = _MemorySink());

  group('levels', () {
    test('error, warning, info and debug reach the sink in a dev build', () {
      final log = logWith(debugEnabled: true)
        ..error('save.failed')
        ..warning('backup.stale')
        ..info('app.started')
        ..debug('editor.opened');
      expect(log.debugEnabled, isTrue);
      expect(sink.records.map((r) => r.level), [
        LogLevel.error,
        LogLevel.warning,
        LogLevel.info,
        LogLevel.debug,
      ]);
      expect(sink.records.map((r) => r.event), [
        'save.failed',
        'backup.stale',
        'app.started',
        'editor.opened',
      ]);
    });

    test('debug is dropped outside dev builds', () {
      logWith()
        ..debug('editor.opened')
        ..info('app.started');
      expect(sink.records.map((r) => r.event), ['app.started']);
    });

    test('debug is enabled only for the dev flavour', () {
      expect(Log.debugEnabledFor('dev'), isTrue);
      expect(Log.debugEnabledFor('prod'), isFalse);
      expect(Log.debugEnabledFor(null), isFalse);
    });
  });

  group('typed fields', () {
    test('IDs, counts, durations, codes and flags render as values', () {
      logWith().info(
        'note.saved',
        fields: {
          'noteId': LogValue.id(noteId),
          'blockId': LogValue.blockId('a1b2c3'),
          'lines': LogValue.count(42),
          'took': LogValue.duration(const Duration(milliseconds: 37)),
          'source': LogValue.code('autosave'),
          'cold': LogValue.flag(false),
        },
      );
      final record = sink.records.single;
      expect(record.renderFields(), [
        'noteId=$noteId',
        'blockId=a1b2c3',
        'lines=42',
        'took=37ms',
        'source=autosave',
        'cold=false',
      ]);
    });

    test('a value that is not an ID or a code is redacted, never written', () {
      logWith().info(
        'note.saved',
        fields: {
          'noteId': LogValue.id(secret),
          'source': LogValue.code(secret),
        },
      );
      final rendered = sink.records.single.renderFields().join(' ');
      expect(rendered, isNot(contains('flowers')));
      expect(rendered, 'noteId=<redacted> source=<redacted>');
    });

    test('an event name or field key with free text is redacted', () {
      logWith().info(secret, fields: {secret: LogValue.count(1)});
      final record = sink.records.single;
      expect(record.event, '<redacted>');
      expect(record.renderFields(), ['<redacted>=1']);
    });
  });

  group('errors', () {
    test('an error is logged by its type, never its toString()', () {
      final stack = StackTrace.current;
      logWith().error('save.failed', error: _NoteError(secret), stack: stack);
      final record = sink.records.single;
      final rendered = [
        record.event,
        ...record.renderFields(),
        ...record.stackFrames,
      ].join('\n');
      expect(record.renderFields(), [
        'errorType=_NoteError',
        'stackHash=${record.stackHash}',
      ]);
      expect(rendered, isNot(contains('flowers')));
      expect(record.stackFrames, isNotEmpty);
      expect(record.stackFrames.first, startsWith('#0'));
    });

    test('a Failure is logged by its stable code', () {
      logWith().warning(
        'backup.skipped',
        error: const Failure('backupFolderUnavailable'),
      );
      expect(sink.records.single.renderFields(), [
        'errorType=Failure',
        'code=backupFolderUnavailable',
      ]);
    });

    test('stack frames keep only frame lines, at most 30', () {
      final text = [
        'Error: $secret',
        for (var i = 0; i < 40; i++) '#$i      f (package:relay/x.dart:1:1)',
      ].join('\n');
      logWith().error(
        'save.failed',
        error: StateError('x'),
        stack: StackTrace.fromString(text),
      );
      final frames = sink.records.single.stackFrames;
      expect(frames, hasLength(30));
      expect(frames.join('\n'), isNot(contains('flowers')));
    });

    test('a failing sink never makes logging throw', () {
      final log = Log([_BrokenSink(), sink], debugEnabled: false);
      expect(() => log.error('save.failed'), returnsNormally);
      expect(sink.records, hasLength(1));
    });
  });

  // From viaticum test/core/log_test.dart @ 78d38e0: the UUID-only ID rule,
  // typed fields and the stack hash.
  group('VIATICUM: IDs and the stack hash', () {
    test('a short lowercase word is not an ID: it could be content', () {
      logWith().info(
        'item.saved',
        fields: {
          'itemId': LogValue.id(noteId),
          'shortWord': LogValue.id('legajo'),
          'blockAsId': LogValue.id('a1b2c3'),
        },
      );
      final rendered = sink.records.single.renderFields().join(' ');
      expect(rendered, isNot(contains('legajo')));
      expect(
        rendered,
        'itemId=$noteId shortWord=<redacted> blockAsId=<redacted>',
      );
    });

    test('a block ID is six characters of a–z0–9, anything else redacted', () {
      String render(String id) => LogValue.blockId(id).render();
      expect(render('a1b2c3'), 'a1b2c3');
      expect(render('zz9900'), 'zz9900');
      for (final bad in ['A1b2c3', 'a1b2c', 'a1b2c3d', 'a-b2c3', noteId, '']) {
        expect(render(bad), redacted, reason: bad);
      }
    });

    test('a String value is rejected: fields take only LogValues', () {
      final Object untyped = <String, Object>{'title': secret};
      expect(
        () => logWith().info(
          'item.saved',
          fields: untyped as Map<String, LogValue>,
        ),
        throwsA(isA<TypeError>()),
      );
      expect(sink.records, isEmpty);
    });

    test('an error with a stack carries a 16-hex stack hash', () {
      logWith().error(
        'item.saveFailed',
        error: _NoteError(secret),
        stack: StackTrace.current,
      );
      final record = sink.records.single;
      expect(record.stackHash, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(record.renderFields().last, 'stackHash=${record.stackHash}');
    });

    test('the stack hash is the same for the same frames only', () {
      String? hashOf(String trace) => LogRecord(
        LogLevel.error,
        'item.saveFailed',
        const {},
        stack: StackTrace.fromString(trace),
      ).stackHash;
      const frames = '#0 f (package:viaticum/a.dart:1:1)\n#1 g (b.dart:2:2)';
      expect(hashOf(frames), hashOf('Error: $secret\n$frames'));
      expect(
        hashOf(frames),
        isNot(hashOf('#0 f (package:viaticum/a.dart:9:1)')),
      );
      expect(hashOf('no frames here'), isNull);
      expect(
        LogRecord(LogLevel.error, 'item.saveFailed', const {}).stackHash,
        isNull,
      );
    });

    test('the stack hash is the first 16 hex of sha256 of the frames', () {
      final record = LogRecord(
        LogLevel.error,
        'item.saveFailed',
        const {},
        stack: StackTrace.fromString('#0 f (a.dart:1:1)\n#1 g (b.dart:2:2)'),
      );
      // The first 16 of sha256sum's ad4cda2d9d52ea91286e…422f for these frames.
      expect(record.stackHash, 'ad4cda2d9d52ea91');
    });
  });
}

// The crash matrix KP-E1…E6 (D-APK-019; ledger packages-v0-4,
// evidence/task-specs.md § T14): every kill point of the export writer, the
// loader and the reader ends in a state the app can recover from, and every
// shape a released app wrote still reads. Written before the code.
import 'dart:convert';
import 'dart:io';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_exchange/apsira_exchange.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'support/db.dart';

/// A simulated process kill: thrown by a hook, never caught by the code.
final class _Kill implements Exception {}

/// A sink that fails once [limit] characters have gone through, as a
/// writer whose file or stream went away mid-export.
final class _CutSink implements StringSink {
  _CutSink(this._inner, this.limit);

  final IOSink _inner;
  final int limit;
  int written = 0;

  void _take(String s) {
    if (written + s.length > limit) {
      throw const FileSystemException('sink closed', 'export.json.part');
    }
    written += s.length;
    _inner.write(s);
  }

  @override
  void write(Object? object) => _take('$object');

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _take(objects.join(separator));

  @override
  void writeCharCode(int charCode) => _take(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) => _take('$object\n');
}

ExportEnvelope _envelope({int schema = 1}) => ExportEnvelope(
  format: 'test-export',
  producedAt: DateTime.utc(2026, 10, 24, 12),
  producer: const Producer('test', '0.4.0'),
  schemaVersion: schema,
);

Future<SqlDatabase> _filled({int works = 3}) async {
  final db = SqlDatabase.memory(smallSchema);
  for (final MapEntry(key: table, value: rows) in smallTables(
    works: works,
  ).entries) {
    for (final row in rows! as List<Object?>) {
      final r = row! as Map<String, Object?>;
      await db.customStatement(
        'INSERT INTO $table (${r.keys.join(', ')}) '
        'VALUES (${List.filled(r.length, '?').join(', ')})',
        [
          for (final MapEntry(:key, :value) in r.entries)
            key == 'cover' && value is String ? base64.decode(value) : value,
        ],
      );
    }
  }
  return db;
}

Future<String> _export(SqlDatabase db) async {
  final out = StringBuffer();
  await writeExport(
    out,
    envelope: _envelope(),
    dump: JsonDump(db),
    tables: await exportedTables(db),
  );
  return out.toString();
}

Future<Result<LoadSummary, LoadRefused>> _build(
  File target,
  Map<String, Object?> tables, {
  int bundleSchema = 1,
  int currentSchema = 1,
  LoadStepHook? onStep,
}) => buildDatabaseFrom(
  target,
  tables,
  bundleSchema: bundleSchema,
  currentSchema: currentSchema,
  open: (e) => SqlDatabase(e, ddl: smallSchema, version: currentSchema),
  onStep: onStep,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('KP-E1 the export writer killed mid-tables', () {
    test(
      'the sink closes early: the error reaches the caller, no file has '
      'the final name and the caller\'s .part is the only leftover',
      () async {
        final db = await _filled();
        addTearDown(db.close);
        final whole = await _export(db);
        final dir = scratch('kp_e1');
        for (final limit in [
          0,
          10,
          whole.indexOf('"tables":') + 12,
          whole.length - 3,
        ]) {
          final part = File('${dir.path}/export.json.part');
          final done = File('${dir.path}/export.json');
          final io = part.openWrite();
          Object? caught;
          try {
            await writeExport(
              _CutSink(io, limit),
              envelope: _envelope(),
              dump: JsonDump(db),
              tables: await exportedTables(db),
            );
            await io.close();
            part.renameSync(done.path);
          } on FileSystemException catch (e) {
            caught = e;
            await io.close();
          }
          expect(caught, isA<FileSystemException>(), reason: 'limit $limit');
          expect(done.existsSync(), isFalse, reason: 'limit $limit');
          expect(dir.listSync().map((e) => e.uri.pathSegments.last), [
            'export.json.part',
          ]);
          part.deleteSync();
        }
      },
    );
  });

  group('KP-E2 the load killed after N of M tables', () {
    test('at every table: the target is removed and the live database is '
        'untouched', () async {
      final dir = scratch('kp_e2');
      final live = File('${dir.path}/live.db');
      final liveDb = SqlDatabase(NativeDatabase(live), ddl: smallSchema);
      await liveDb.customStatement(
        "INSERT INTO works (id, title) VALUES ('x', 'live')",
      );
      await liveDb.close();
      final before = live.readAsBytesSync();
      final target = File('${dir.path}/restore/built.db');
      final tables = smallTables();
      for (var n = 1; n <= tables.length; n++) {
        await expectLater(
          _build(
            target,
            tables,
            onStep: (table, loaded, total) {
              expect(total, tables.length);
              if (loaded == n) throw _Kill();
            },
          ),
          throwsA(isA<_Kill>()),
          reason: 'killed after $n',
        );
        for (final suffix in ['', '-journal', '-wal', '-shm']) {
          expect(File('${target.path}$suffix').existsSync(), isFalse);
        }
        expect(live.readAsBytesSync(), before);
      }
    });

    test('a file a killed run left at the target never stays: the next '
        'build removes it first, even when it refuses', () async {
      final dir = scratch('kp_e2b');
      final target = File('${dir.path}/built.db')..writeAsStringSync('half');
      File('${target.path}-wal').writeAsStringSync('half');
      final refused = await _build(target, smallTables(), bundleSchema: 9);
      expect(refused.failureOrNull?.refusal, LoadRefusal.schemaTooNew);
      expect(target.existsSync(), isFalse);
      expect(File('${target.path}-wal').existsSync(), isFalse);
    });
  });

  group('KP-E3 a cut export', () {
    test('cut at every 1 KiB of a 20 KiB export: NotABundle, never an '
        'exception, never EnvelopeOk', () async {
      final db = await _filled(works: 360);
      addTearDown(db.close);
      final bytes = utf8.encode(await _export(db));
      expect(bytes.length, greaterThan(20 * 1024));
      bool check(List<int> b) => switch (checkEnvelopeUtf8(
        b,
        formats: {'test-export'},
        currentSchemaVersion: 1,
      )) {
        EnvelopeOk() => true,
        NotABundle() => false,
        final other => fail('$other'),
      };
      expect(check(bytes), isTrue);
      for (var cut = 0; cut < bytes.length; cut += 1024) {
        expect(check(bytes.sublist(0, cut)), isFalse, reason: 'cut at $cut');
      }
      expect(check(bytes.sublist(0, bytes.length - 2)), isFalse);
    });
  });

  group('KP-E4 ENOSPC during the load', () {
    for (final (name, error) in [
      (
        'ENOSPC',
        const FileSystemException(
          'write',
          'built.db',
          OSError('No space left on device', 28),
        ),
      ),
      (
        'SQLITE_FULL',
        SqliteException(
          extendedResultCode: 13,
          message: 'database or disk is full',
        ),
      ),
    ]) {
      test('$name: storageFull, the partial removed', () async {
        final dir = scratch('kp_e4');
        final target = File('${dir.path}/built.db');
        final result = await _build(
          target,
          smallTables(),
          onStep: (table, loaded, total) {
            if (loaded == 2) throw error;
          },
        );
        expect(result.failureOrNull?.refusal, LoadRefusal.storageFull);
        expect(result.failureOrNull?.code, 'loadStorageFull');
        expect(dir.listSync(), isEmpty);
      });
    }
  });

  group('KP-E5 every released shape reads', () {
    EnvelopeCheck check(
      String path, {
      required Set<String> formats,
      required int current,
      List<LegacyShape> legacy = LegacyShape.values,
    }) => checkEnvelopeUtf8(
      fixtureBytes(path),
      formats: formats,
      currentSchemaVersion: current,
      legacy: legacy,
    );

    test('RELAY v1.0.0…v2.0.1 relay.json (one shape; v2.0.1\'s own export): '
        'read as relayExportV1, and refused without the legacy shape', () {
      final read = check(
        'relay/relay-v2.0.1.json.gz',
        formats: {'relay-export'},
        current: 12,
      );
      expect(read, isA<EnvelopeOk>());
      final ok = read as EnvelopeOk;
      expect(ok.readAs, LegacyShape.relayExportV1);
      expect(ok.envelope.schemaVersion, 11);
      expect(ok.envelope.producer?.app, 'relay');
      expect(ok.envelope.producer?.appVersion, '2.0.1');
      expect(
        check(
          'relay/relay-v2.0.1.json.gz',
          formats: {'relay-export'},
          current: 12,
          legacy: const [],
        ),
        isA<NotABundle>(),
      );
    });

    for (final tag in ['v0.2.0', 'v1.0.0']) {
      for (final (kind, file) in [
        ('seed', 'seed-valid'),
        ('package', 'package-small'),
        ('results', 'results-small'),
      ]) {
        test('VIATICUM $tag $kind: read as viaticumExchangeV1', () {
          final path = tag == 'v0.2.0'
              ? 'viaticum-v0.2.0-$file.json'
              : 'exchange/viaticum-v1.0.0/examples/$file.json';
          final read = check(
            path,
            formats: {'viaticum.seed', 'viaticum.package', 'viaticum.results'},
            current: 1,
          );
          expect(read, isA<EnvelopeOk>());
          final ok = read as EnvelopeOk;
          expect(ok.readAs, LegacyShape.viaticumExchangeV1);
          expect(ok.envelope.format, 'viaticum.$kind');
          expect(ok.envelope.schemaVersion, isNull);
          expect(ok.envelope.extra['artifact_id'], isA<String>());
        });
      }
    }

    for (final (name, schema) in [('synthetic', 2), ('minimal', 1)]) {
      test('LYCEUM v1.0.0 lyceum.json ($name): the envelope itself', () {
        final read = check(
          'exchange/lyceum-v1.0.0/examples/valid/lyceum-export-$name.json',
          formats: {'lyceum-export'},
          current: 2,
        );
        expect(read, isA<EnvelopeOk>());
        final ok = read as EnvelopeOk;
        expect(ok.readAs, isNull);
        expect(ok.envelope.schemaVersion, schema);
        expect(ok.envelope.producer?.app, 'lyceum');
        expect(
          ok.envelope.extra['app_version'],
          ok.envelope.producer?.appVersion,
        );
      });
    }
  });

  group('KP-E6 a format or a schema this build does not read', () {
    Map<String, Object?> doc() =>
        jsonDecode(_envelope(schema: 3).encode()) as Map<String, Object?>;

    test('format_version 2.0: FormatUnsupported', () {
      final d = doc()..['format_version'] = '2.0';
      final read = checkEnvelope(
        d,
        formats: {'test-export'},
        currentSchemaVersion: 3,
      );
      expect(read, isA<FormatUnsupported>());
      expect((read as FormatUnsupported).found, '2.0');
    });

    test('a schema newer than the current: SchemaTooNew', () {
      final read = checkEnvelope(
        doc(),
        formats: {'test-export'},
        currentSchemaVersion: 2,
      );
      expect(read, isA<SchemaTooNew>());
      expect((read as SchemaTooNew).found, 3);
      expect(read.supported, 2);
    });

    test('RELAY\'s version 2 is FormatUnsupported, its newer schema '
        'SchemaTooNew', () {
      final relay =
          fixtureJson('relay/relay-v2.0.1.json.gz')! as Map<String, Object?>;
      final v2 = {...relay, 'version': 2};
      expect(
        checkEnvelope(
          v2,
          formats: {'relay-export'},
          currentSchemaVersion: 12,
          legacy: LegacyShape.values,
        ),
        isA<FormatUnsupported>(),
      );
      expect(
        checkEnvelope(
          relay,
          formats: {'relay-export'},
          currentSchemaVersion: 10,
          legacy: LegacyShape.values,
        ),
        isA<SchemaTooNew>(),
      );
    });
  });
}

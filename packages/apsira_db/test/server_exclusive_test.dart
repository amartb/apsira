// From relay test/data/db/server_exclusive_test.dart @ 09b28810, 2520b90b's
// test (D-APK-018, AC-13.3, AC-13.4): drift closes the executor of every
// `exclusively` block when the block ends. On the UI's server connection
// that close ends the block, not the connection: an integrity check and a
// restore swap both run inside `exclusively` on the UI's connection, and
// every statement after them must still run. Only the owner's real close
// stops the server. A client's exclusive block likewise leaves its watch on
// the server's exit in place, so a statement after it still fails fast with
// `DatabaseServerGone` when the server dies. RELAY's `IntegrityDao.check`
// is its read-only `exclusively` block, written out here.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:apsira_db/apsira_db.dart';
import 'package:apsira_db/testing.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixture_database.dart';
import 'support/memory_log.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late FakePortRegistry registry;
  late DatabaseServer server;
  final portName = databasePortName('fixture');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('apsira_db_server_exclusive_');
    registry = FakePortRegistry();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// The UI's open as an app does it, keeping the server.
  Future<FixtureDatabase> openUi() async {
    server = DatabaseServer(registry: registry, portName: portName);
    final opening = await openWithSnapshot(
      directory: dir,
      name: 'fixture',
      targetVersion: fixtureVersion,
      open: FixtureDatabase.new,
      log: MemoryLog().log,
      connect: server.connect,
    );
    await server.publish();
    return (opening as Opened<FixtureDatabase>).database;
  }

  /// RELAY's `IntegrityDao.check`: `PRAGMA integrity_check` read-only,
  /// inside `exclusively`, inside a savepoint. The problems it finds.
  Future<List<String>> check(GeneratedDatabase db) => db.exclusively(() async {
    await db.customStatement('PRAGMA query_only = ON');
    try {
      await db.customStatement('SAVEPOINT integrity_check');
      try {
        final rows = await db.customSelect('PRAGMA integrity_check').get();
        return [
          for (final r in rows)
            if (r.data.values.single != 'ok') '${r.data.values.single}',
        ];
      } finally {
        await db.customStatement('RELEASE integrity_check');
      }
    } finally {
      await db.customStatement('PRAGMA query_only = OFF');
    }
  });

  Future<int> noteCount(GeneratedDatabase db) async =>
      (await db.customSelect('SELECT count(*) AS n FROM notes').getSingle())
          .read<int>('n');

  test('the integrity check runs twice on the UI connection, and a normal '
      'query runs after it', () async {
    final db = await openUi();
    addTearDown(db.close);

    expect(await check(db), isEmpty);
    expect(await check(db), isEmpty);
    expect(await noteCount(db), 0);
    expect(registry.mappings.keys, [portName]);
  });

  test('an exclusive block still holds the connection: a statement from '
      'outside it waits for the block to end', () async {
    final db = await openUi();
    addTearDown(db.close);
    final events = <String>[];
    Future<void>? outside;

    await db.exclusively(() async {
      await db.customStatement('CREATE TABLE t (x)');
      outside = Zone.root.run(
        () => db
            .customStatement('INSERT INTO t VALUES (2)')
            .then((_) => events.add('outside')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await db.customStatement('INSERT INTO t VALUES (1)');
      events.add('block');
    });
    await outside;

    expect(events, ['block', 'outside']);
    final rows = await db.customSelect('SELECT x FROM t ORDER BY rowid').get();
    expect(rows.map((r) => r.read<int>('x')), [1, 2]);
  });

  test('the real close still stops the server and unpublishes the name, '
      'after an exclusive block', () async {
    final db = await openUi();
    // The server's isolate, as a client's handshake hears it.
    final answer = ReceivePort();
    registry.lookup(portName)!.send(answer.sendPort);
    final control = (await answer.first as List<Object?>)[1]! as SendPort;
    final exited = ReceivePort();
    Isolate(control).addOnExitListener(exited.sendPort);
    await check(db);
    await noteCount(db);

    await db.close();

    expect(registry.mappings, isEmpty);
    await exited.first.timeout(const Duration(seconds: 2));
  });

  test(
    "a client's exclusive block keeps its watch on the server's exit",
    () async {
      // No close of the UI's database here: a killed server answers no
      // shutdown.
      await openUi();
      final client = FixtureDatabase(
        (await connectByName(registry, portName))!,
      );
      await client.exclusively(() => client.customSelect('SELECT 1').get());
      expect(await noteCount(client), 0);

      await server.kill();
      final timer = Stopwatch()..start();

      await expectLater(
        client.customSelect('SELECT 1').get(),
        throwsA(isA<DatabaseServerGone>()),
      );
      expect(timer.elapsed, lessThan(const Duration(seconds: 1)));
      await client.close().timeout(const Duration(seconds: 1));
    },
  );
}

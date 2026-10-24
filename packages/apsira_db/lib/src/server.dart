// From relay lib/data/db/server.dart @ 09b28810, which carries 2520b90b
// ("an exclusively() block no longer stops the database server":
// `_ExclusiveBlocks` on both interceptors). VIATICUM's copy @ 78d38e0 lacks
// it (latent there: it calls no `exclusively(`) and gains it here
// (D-APK-018). The port name is the app's: `databasePortName(name)`.
/// The UI's database runs on a drift server isolate, published under one
/// name ([databasePortName]), so code in another isolate or Flutter engine
/// (a WorkManager job, a notification action) connects to the UI's own
/// connection, and its writes update the UI's watch streams.
///
/// What the name holds is a small port in the UI's isolate that answers
/// with two ports: the server's drift connect port, and its isolate's
/// control port, so a client hears when the server exits and fails its
/// statements at once ([DatabaseServerGone]) instead of hanging.
///
/// The port is published only once the opener has the database at the
/// build's version, and unpublished when the UI's database closes; a client
/// of the server never creates or migrates, because the server's connection
/// is already open. The only library of the package that needs Flutter
/// (`dart:ui`'s `IsolateNameServer`).
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftIsolate;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'connection.dart';

/// The one name the UI's database server of the database [name] is
/// published under: RELAY's `relay.database`, VIATICUM's
/// `viaticum.database`.
String databasePortName(String name) => '$name.database';

/// Where a connect port is published by name: the process-wide
/// `IsolateNameServer` in the app ([IsolatePortRegistry]), a fake on the
/// host. A name holds one port; registering a taken name fails.
abstract interface class PortRegistry {
  SendPort? lookup(String name);

  /// Whether [port] now holds [name]; false when the name is taken.
  bool register(SendPort port, String name);

  /// Whether a mapping was removed.
  bool remove(String name);
}

/// [PortRegistry] on `IsolateNameServer`, shared by every isolate and
/// engine of the process.
final class IsolatePortRegistry implements PortRegistry {
  const IsolatePortRegistry();

  @override
  SendPort? lookup(String name) => IsolateNameServer.lookupPortByName(name);

  @override
  bool register(SendPort port, String name) =>
      IsolateNameServer.registerPortWithName(port, name);

  @override
  bool remove(String name) => IsolateNameServer.removePortNameMapping(name);
}

/// The UI's database server. [connect] is the opener's connection
/// (`openWithSnapshot`'s `connect`): it spawns the server and returns its
/// owner's connection, which runs the migration like any other. [publish]
/// puts the server's handshake port under [portName] once the database is
/// open. Closing the owner's connection unpublishes the name, closes every
/// client and the server's SQLite connection, and returns only once the
/// server isolate has exited, so a restore that follows never races it.
final class DatabaseServer {
  DatabaseServer({required this.registry, required this.portName});

  /// Where [publish] puts the handshake port.
  final PortRegistry registry;

  /// The name it is published under ([databasePortName]).
  final String portName;
  final _spawned = Completer<(DriftIsolate, Isolate, Future<void>)>();
  var _connected = false;
  Future<void>? _stopped;
  RawReceivePort? _handshake;

  /// The owner's connection to a server spawned for [file]. Nothing opens
  /// the file until the first statement. A server has one owner.
  QueryExecutor connect(File file) {
    if (_connected) throw StateError('A database server has one owner');
    _connected = true;
    return DatabaseConnection.delayed(_start(file.absolute.path));
  }

  Future<DatabaseConnection> _start(String path) async {
    final exited = ReceivePort('$portName server exit');
    Isolate? server;
    Future<Isolate> spawn<T>(void Function(T) entry, T message) async =>
        server = await Isolate.spawn(
          entry,
          message,
          onExit: exited.sendPort,
          debugName: '$portName server',
        );
    final DriftIsolate isolate;
    try {
      isolate = await DriftIsolate.spawn(
        _serverOpener(path),
        isolateSpawn: spawn,
      );
    } catch (_) {
      exited.close();
      rethrow;
    }
    _spawned.complete((isolate, server!, exited.first));
    try {
      final connection = await isolate.connect();
      return connection.interceptWith(_StopOnClose(this));
    } catch (_) {
      await _stop();
      rethrow;
    }
  }

  /// Publishes the handshake port under the name, replacing a mapping that
  /// an engine which died without closing left behind. A client sends it a
  /// `SendPort`; it answers `[connectPort, controlPort]` (see
  /// [connectByName]).
  Future<void> publish() async {
    final (isolate, server, _) = await _spawned.future;
    final handshake = _handshake ??= RawReceivePort((Object? message) {
      if (message is SendPort) {
        message.send([isolate.connectPort, server.controlPort]);
      }
    }, '$portName handshake');
    registry.remove(portName);
    if (!registry.register(handshake.sendPort, portName)) {
      throw StateError('The database port name could not be registered');
    }
  }

  void _unpublish() {
    final handshake = _handshake;
    if (handshake == null) return;
    _handshake = null;
    // A mapping that is not this server's belongs to whoever replaced it.
    if (registry.lookup(portName) == handshake.sendPort) {
      registry.remove(portName);
    }
    handshake.close();
  }

  Future<void> _stop() => _stopped ??= () async {
    if (!_spawned.isCompleted) return;
    final (isolate, _, exited) = await _spawned.future;
    await isolate.shutdownAll();
    // The server closes its SQLite connection before its isolate exits.
    await exited;
  }();

  /// Ends the server isolate at once, as the death of the UI's engine
  /// does: no statement finishes and nothing is unpublished. For tests.
  @visibleForTesting
  Future<void> kill() async {
    final (_, server, exited) = await _spawned.future;
    server.kill(priority: Isolate.immediate);
    await exited;
  }
}

/// Opens the file on the server isolate with the four pragmas. Top level,
/// so the closure sent to the isolate holds only the path.
QueryExecutor Function() _serverOpener(String path) =>
    () => NativeDatabase(File(path), setup: applyPragmas);

/// Marks the executors of `exclusively` blocks. drift closes such an
/// executor when its block ends, and an interceptor sees that close like
/// the connection's own: [isExclusive] tells the two apart, so ending an
/// integrity check or a restore swap closes only its block (2520b90b).
mixin _ExclusiveBlocks on QueryInterceptor {
  final _exclusive = Expando<bool>('exclusive block');

  @override
  QueryExecutor beginExclusive(QueryExecutor parent) {
    final block = parent.beginExclusive();
    _exclusive[block] = true;
    return block;
  }

  bool isExclusive(QueryExecutor executor) => _exclusive[executor] ?? false;
}

/// Stops the server when the owner's connection closes; the end of an
/// exclusive block releases the connection and nothing more.
final class _StopOnClose extends QueryInterceptor with _ExclusiveBlocks {
  _StopOnClose(this._server);

  final DatabaseServer _server;

  @override
  Future<void> close(QueryExecutor inner) async {
    if (isExclusive(inner)) return inner.close();
    _server._unpublish();
    try {
      await inner.close();
    } finally {
      await _server._stop();
    }
  }
}

/// A client's statement could not finish: the UI's database server exited
/// (its engine died). The statement's transaction did not commit unless
/// the server committed it before exiting. The message holds no SQL and
/// no values.
final class DatabaseServerGone implements Exception {
  const DatabaseServerGone();

  @override
  String toString() => 'DatabaseServerGone: the database server exited';
}

/// The connection to the server published under [portName], for another
/// isolate or engine; null when nothing is published. Throws when the
/// handshake port or the server does not answer within [timeout] each (its
/// engine died and left the name behind).
///
/// The client listens for the server isolate's exit: from then on every
/// statement, commit and close of the connection completes at once, a
/// statement with [DatabaseServerGone] (a rollback succeeds, because the
/// server's SQLite connection is gone with its transaction).
Future<DatabaseConnection?> connectByName(
  PortRegistry registry,
  String portName, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final port = registry.lookup(portName);
  if (port == null) return null;
  final answer = Completer<Object?>();
  final reply = RawReceivePort((Object? message) {
    if (!answer.isCompleted) answer.complete(message);
  }, '$portName handshake reply');
  final Object? ports;
  try {
    port.send(reply.sendPort);
    ports = await answer.future.timeout(timeout);
  } finally {
    reply.close();
  }
  if (ports case [final SendPort connectPort, final SendPort controlPort]) {
    final gone = _ServerExit(controlPort);
    try {
      final connection = await DriftIsolate.fromConnectPort(connectPort)
          .connect(connectTimeout: timeout);
      return connection.interceptWith(_FailWhenGone(gone));
    } catch (_) {
      gone.close();
      rethrow;
    }
  }
  throw StateError('The database port name does not answer as a server');
}

/// The server isolate's exit, heard through its control port. Listening
/// starts before the drift handshake, so an exit after it is always heard;
/// an exit before it fails the handshake.
final class _ServerExit {
  _ServerExit(SendPort controlPort) {
    _port = RawReceivePort((Object? _) {
      if (!_exited.isCompleted) _exited.complete();
      close();
    }, 'database server exit');
    Isolate(controlPort).addOnExitListener(_port.sendPort);
  }

  late final RawReceivePort _port;
  final _exited = Completer<void>();

  bool get exited => _exited.isCompleted;

  Future<void> get future => _exited.future;

  void close() => _port.close();
}

/// Completes every call at once when the server has exited. The end of
/// an exclusive block keeps the watch on the server's exit.
final class _FailWhenGone extends QueryInterceptor with _ExclusiveBlocks {
  _FailWhenGone(this._gone);

  final _ServerExit _gone;

  Future<T> _guard<T>(Future<T> Function() call) {
    if (_gone.exited) return Future.error(const DatabaseServerGone());
    return Future.any([
      call(),
      _gone.future.then<T>((_) => throw const DatabaseServerGone()),
    ]);
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      _guard(() => executor.ensureOpen(user));

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _guard(() => executor.runBatched(statements));

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runCustom(statement, args));

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runInsert(statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runUpdate(statement, args));

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runDelete(statement, args));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runSelect(statement, args));

  @override
  Future<void> commitTransaction(TransactionExecutor inner) =>
      _guard(inner.send);

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    // The server's connection, and its open transaction, died with it.
    if (_gone.exited) return;
    await Future.any([inner.rollback(), _gone.future]);
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    if (isExclusive(inner)) return _guard(inner.close);
    try {
      if (!_gone.exited) await Future.any([inner.close(), _gone.future]);
    } finally {
      _gone.close();
    }
  }
}

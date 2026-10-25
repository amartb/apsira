// From relay test/data/files/backup_zip_reader_test.dart @ 09b28810 (the
// helpers both of RELAY's zip tests repeat, and LYCEUM's copies of them in
// test/data/files/bundle_zip_reader_test.dart @ 9f4ff27), gathered so the
// writer, reader and crash-matrix tests share one set.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_zip/apsira_zip.dart';
import 'package:crypto/crypto.dart' as crypto;

const kib = 1024;
const mib = 1024 * 1024;

/// Local wall time; DOS time keeps even seconds.
final modified = DateTime(2026, 10, 18, 12, 30, 44);

Uint8List randomBytes(int length, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

/// Compressible bytes with some noise, like a database page file.
Uint8List pages(int length, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(
    List.generate(length, (i) => i % 11 == 0 ? r.nextInt(256) : i ~/ 512),
  );
}

String sha(List<int> bytes) => crypto.sha256.convert(bytes).toString();

Stream<List<int>> chunks(List<int> data, [int size = 4 * kib]) async* {
  for (var i = 0; i < data.length; i += size) {
    yield data.sublist(i, min(i + size, data.length));
  }
}

Future<Uint8List> collect(Stream<List<int>> s) async {
  final b = BytesBuilder(copy: false);
  await for (final c in s) {
    b.add(c);
  }
  return b.takeBytes();
}

/// Writes [entries] as one zip: its bytes and its summary.
Future<(Uint8List, ZipSummary)> zipOf(
  List<ZipEntry> entries, {
  bool forceZip64 = false,
  int zip32Max = zip32Limit,
  DateTime? at,
}) async {
  final writer = ZipWriter(
    modified: at ?? modified,
    forceZip64: forceZip64,
    zip32Max: zip32Max,
  );
  final bytes = await collect(writer.write(entries));
  return (bytes, await writer.done);
}

/// [bytes] as a single-subscription stream cut into [cuts]-sized chunks
/// (cycled), counting its listeners in [listens].
Stream<List<int>> streamOf(
  Uint8List bytes, {
  List<int> cuts = const [64 * kib],
  List<int>? listens,
}) {
  late StreamController<List<int>> c;
  c = StreamController<List<int>>(
    onListen: () async {
      listens?.add(1);
      var i = 0;
      for (var at = 0; at < bytes.length; i++) {
        final end = min(at + cuts[i % cuts.length], bytes.length);
        c.add(Uint8List.sublistView(bytes, at, end));
        at = end;
        if (i % 64 == 0) await Future<void>.delayed(Duration.zero);
      }
      await c.close();
    },
  );
  return c.stream;
}

/// The refusal of a failed read, or null when it verified.
ZipRefusal? refusalOf(Result<ZipContents, ZipRefused> r) =>
    r.failureOrNull?.refusal;

int u16(Uint8List b, int at) =>
    ByteData.sublistView(b).getUint16(at, Endian.little);

int u32(Uint8List b, int at) =>
    ByteData.sublistView(b).getUint32(at, Endian.little);

void put32(Uint8List b, int at, int v) =>
    ByteData.sublistView(b).setUint32(at, v, Endian.little);

void put16(Uint8List b, int at, int v) =>
    ByteData.sublistView(b).setUint16(at, v, Endian.little);

/// Where things are in a zip without ZIP64: each central header's offset,
/// with its entry's local header, data and descriptor offsets.
final class Layout {
  Layout(this.zip) {
    final eocd = zip.length - 22;
    cdOffset = u32(zip, eocd + 16);
    var at = cdOffset;
    for (var i = 0; i < u16(zip, eocd + 10); i++) {
      central.add(at);
      final local = u32(zip, at + 42);
      locals.add(local);
      final data = local + 30 + u16(zip, local + 26) + u16(zip, local + 28);
      descriptors.add(data + u32(zip, at + 20));
      at += 46 + u16(zip, at + 28) + u16(zip, at + 30) + u16(zip, at + 32);
    }
  }

  final Uint8List zip;
  late final int cdOffset;
  final central = <int>[];
  final locals = <int>[];
  final descriptors = <int>[];

  int get eocd => zip.length - 22;

  /// A copy of [zip] with entry [entry]'s name, in its local header and its
  /// central header alike, replaced by [name] of the same length.
  Uint8List rename(int entry, List<int> name) {
    final length = u16(zip, locals[entry] + 26);
    if (name.length != length) {
      throw ArgumentError.value(name.length, 'name', 'not $length bytes');
    }
    final b = Uint8List.fromList(zip);
    b.setRange(locals[entry] + 30, locals[entry] + 30 + length, name);
    b.setRange(central[entry] + 46, central[entry] + 46 + length, name);
    return b;
  }
}

/// `ENOSPC`, as `dart:io` reports a write to a full disk.
FileSystemException noSpace(String path) => FileSystemException(
  'writeFrom failed',
  path,
  const OSError('No space left on device', 28),
);

/// An [ExtractSink] in memory that records what it was asked for; [fail]
/// makes a step of a target throw.
final class RecordingSink implements ExtractSink {
  RecordingSink({this.fail});

  /// Called with (name, step) for 'open', 'add', 'flush' and 'close'; it may
  /// throw.
  final void Function(String name, String step)? fail;

  /// The names opened, in order.
  final opened = <String>[];

  /// The names whose targets were closed.
  final closed = <String>[];

  /// The names flushed (each entry once it checked out).
  final flushed = <String>[];

  final bytes = <String, BytesBuilder>{};

  @override
  ExtractTarget open(String name) {
    fail?.call(name, 'open');
    opened.add(name);
    return _RecordingTarget(this, name);
  }
}

final class _RecordingTarget implements ExtractTarget {
  _RecordingTarget(this._sink, this._name) {
    _sink.bytes[_name] = BytesBuilder();
  }

  final RecordingSink _sink;
  final String _name;

  @override
  void add(List<int> chunk) {
    _sink.fail?.call(_name, 'add');
    _sink.bytes[_name]!.add(chunk);
  }

  @override
  void flush() {
    _sink.fail?.call(_name, 'flush');
    _sink.flushed.add(_name);
  }

  @override
  void close() {
    _sink.closed.add(_name);
    _sink.fail?.call(_name, 'close');
  }
}

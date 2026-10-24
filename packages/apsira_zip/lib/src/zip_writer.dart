// From relay lib/data/files/backup_zip_writer.dart @ 09b28810
/// The zip writer (D-APK-020; RELAY ruling R-15: `archive` deflates each
/// entry in memory and gives no back-pressure): the entries are read from
/// their streams one after another and written as one zip into a stream,
/// so an archive of any size (RELAY's backup, LYCEUM's export bundle)
/// passes through a few chunks of memory and goes straight to the target.
///
/// The zip it writes, "the profile" (RELAY's), is what `zip_reader.dart`
/// verifies field by field:
///
/// - every entry is raw deflate (method 8, dart:io's zlib), with general
///   purpose flags `0x0808`: bit 3, the CRC-32 and sizes follow the data
///   in a data descriptor (with its signature), and bit 11, the name is
///   UTF-8; the local header's CRC and sizes are zero;
/// - names are plain relative paths ([zipNameProblem]); there are no
///   directory entries, comments, attributes or other extra fields;
/// - one modification time for every entry, the wall time the writer is
///   given, in DOS form (even seconds, 1980 to 2107);
/// - "version needed" and "version made by" (host 0, MS-DOS) are 2.0, or
///   4.5 where a header carries a ZIP64 field.
///
/// ZIP64 (APPNOTE 4.5.3): a local header can only announce 8-byte sizes
/// before its data is written, so an entry gets the ZIP64 local extra
/// field and an 8-byte data descriptor when its declared [ZipEntry.size]
/// could pass [zip32Limit] once deflated. An entry without a declared size
/// that passes it fails the zip ([StateError]) rather than writing sizes
/// it cannot hold. The central directory gives an offset past the limit
/// in its ZIP64 field, and the ZIP64 end records follow it when the entry
/// count, the directory's size or its offset need them. `forceZip64`
/// writes every ZIP64 field and record, for tests and decoders.
///
/// Back-pressure: the stream comes from an `async*` generator, which
/// stops at each `yield` while its listener is paused and reads the next
/// chunk of the current entry only when the last one has been handed on.
/// A cancel takes effect when the source delivers its next chunk.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'crc32.dart';

/// The largest size or offset a 32-bit zip field holds; 0xFFFFFFFF means
/// "in the ZIP64 field".
const zip32Limit = 0xFFFFFFFE;

/// The constants of the zip profile, shared by the writer and the
/// reader.
abstract final class ZipProfile {
  static const localHeader = 0x04034b50;
  static const descriptor = 0x08074b50;
  static const centralHeader = 0x02014b50;
  static const zip64EndRecord = 0x06064b50;
  static const zip64Locator = 0x07064b50;
  static const endRecord = 0x06054b50;

  /// Data descriptor and UTF-8 names.
  static const flags = 0x0808;
  static const deflate = 8;
  static const version20 = 20;
  static const version45 = 45;
  static const zip64ExtraId = 0x0001;

  /// The 32-bit and 16-bit "see the ZIP64 field" markers.
  static const marker32 = 0xFFFFFFFF;
  static const marker16 = 0xFFFF;

  /// The ZIP64 end record's "size of the record" field: its fixed part
  /// after the first 12 bytes, without extensible data.
  static const zip64EndRecordRest = 44;
}

/// Why [name] cannot be an entry name, or null when it can.
///
/// A name is a relative path of one or more `/`-separated segments, none
/// empty, `.` or `..`, with no backslash or control character, that
/// survives UTF-8 encoding unchanged (no lone surrogate) in at most
/// 65,535 bytes: a name that extracts inside the folder it is extracted
/// to, on any system.
String? zipNameProblem(String name) {
  if (name.isEmpty) return 'empty';
  final bytes = utf8.encode(name);
  if (bytes.length > 0xFFFF) return 'longer than 65,535 bytes';
  if (utf8.decode(bytes, allowMalformed: true) != name) return 'not UTF-8';
  for (final unit in name.codeUnits) {
    if (unit < 0x20 || unit == 0x7F) return 'a control character';
    if (unit == 0x5C) return 'a backslash';
  }
  for (final segment in name.split('/')) {
    if (segment.isEmpty) return 'an empty segment, or a leading or trailing /';
    if (segment == '.' || segment == '..') return 'a . or .. segment';
  }
  return null;
}

/// One entry of a zip being written: [bytes] is listened to when the
/// entry's turn comes, so a later entry's source can wait for an earlier
/// one's [written] (a manifest names an earlier entry's checksum).
final class ZipEntry {
  ZipEntry(this.name, this.bytes, {this.size, this.sha256 = false}) {
    // A zip that fails before this entry completes [written] with the
    // error; nobody need listen for it.
    _written.future.ignore();
  }

  /// The entry's path inside the zip ([zipNameProblem]).
  final String name;

  /// The entry's content, read once.
  final Stream<List<int>> bytes;

  /// The number of bytes [bytes] delivers, when known: a different count
  /// fails the zip, and a size that could pass [zip32Limit] gets ZIP64.
  final int? size;

  /// Whether [written] carries the content's sha256.
  final bool sha256;

  final _written = Completer<ZipEntryInfo>();

  /// The entry as written, once its data descriptor is; the zip's error
  /// when it fails first.
  Future<ZipEntryInfo> get written => _written.future;
}

/// An entry as written or as read back.
final class ZipEntryInfo {
  const ZipEntryInfo({
    required this.name,
    required this.size,
    required this.compressedSize,
    required this.crc32,
    required this.offset,
    required this.zip64,
    this.sha256,
  });

  final String name;

  /// Bytes before and after deflate.
  final int size;
  final int compressedSize;
  final int crc32;

  /// Where the entry's local header starts.
  final int offset;

  /// Whether the local header has the ZIP64 field (8-byte descriptor).
  final bool zip64;

  /// Lower-case hex, when asked for.
  final String? sha256;

  @override
  String toString() => 'ZipEntryInfo($name, $size B)';
}

/// A written zip: its length, the sha256 of every byte of it, and its
/// entries in order.
final class ZipSummary {
  const ZipSummary({
    required this.length,
    required this.sha256,
    required this.entries,
  });

  final int length;
  final String sha256;
  final List<ZipEntryInfo> entries;
}

/// Writes one zip ([write]); [done] reports it.
final class ZipWriter {
  /// [modified] is the entries' modification time, as wall time (the
  /// archive's local time). Output chunks hold at least [chunkSize]
  /// bytes, the last one excepted. [level] is zlib's (0–9). [zip32Max]
  /// lowers the 32-bit limit, so tests reach the ZIP64 paths without
  /// 4 GiB of data; the format is otherwise the same.
  ZipWriter({
    required DateTime modified,
    this.forceZip64 = false,
    this.chunkSize = 64 * 1024,
    this.level = 6,
    this.zip32Max = zip32Limit,
  }) : _dos = _dosDateTime(modified) {
    _done.future.ignore();
  }

  final bool forceZip64;
  final int chunkSize;
  final int level;
  final int zip32Max;

  /// (time, date).
  final (int, int) _dos;
  final _done = Completer<ZipSummary>();
  var _used = false;

  /// The zip, once [write] has finished; its error when it fails.
  Future<ZipSummary> get done => _done.future;

  /// The zip of [entries], in order. Names are checked before anything is
  /// read: an invalid or repeated name throws [ArgumentError]. An error
  /// of a source, or a [StateError] for a size that is not what was
  /// declared, ends the stream with that error.
  Stream<List<int>> write(Iterable<ZipEntry> entries) {
    if (_used) throw StateError('a ZipWriter writes one zip');
    final list = List.of(entries);
    final names = <String>{};
    for (final e in list) {
      final problem = zipNameProblem(e.name);
      if (problem != null) {
        throw ArgumentError.value(e.name, 'name', problem);
      }
      if (!names.add(e.name)) {
        throw ArgumentError.value(e.name, 'name', 'repeated');
      }
    }
    _used = true;
    return _write(list);
  }

  Stream<List<int>> _write(List<ZipEntry> entries) async* {
    final out = _Output();
    final infos = <ZipEntryInfo>[];
    final directory = BytesBuilder(copy: false);
    Object error = StateError('the zip was cancelled');
    StackTrace? trace;
    try {
      for (final entry in entries) {
        final offset = out.length;
        final name = utf8.encode(entry.name);
        final declared = entry.size;
        final zip64 =
            forceZip64 ||
            (declared != null && _deflateBound(declared) > zip32Max);
        out.add(_localHeader(name, zip64));

        final crc = Crc32();
        final hash = entry.sha256 ? RunningSha256() : null;
        final deflated = _Collect();
        final deflater = ZLibEncoder(
          raw: true,
          level: level,
        ).startChunkedConversion(deflated);
        var size = 0;
        var compressed = 0;
        await for (final chunk in entry.bytes) {
          final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
          crc.add(bytes);
          hash?.add(bytes);
          size += bytes.length;
          deflater.add(bytes);
          compressed += out.addAll(deflated.take());
          while (out.length - out.yielded >= chunkSize) {
            yield out.take();
          }
        }
        deflater.close();
        compressed += out.addAll(deflated.take());

        if (declared != null && declared != size) {
          throw StateError(
            '${entry.name}: $size bytes where $declared were declared',
          );
        }
        if (!zip64 && (size > zip32Max || compressed > zip32Max)) {
          throw StateError(
            '${entry.name}: $size bytes need ZIP64; declare its size',
          );
        }
        out.add(_descriptor(crc.value, compressed, size, zip64));
        final info = ZipEntryInfo(
          name: entry.name,
          size: size,
          compressedSize: compressed,
          crc32: crc.value,
          offset: offset,
          zip64: zip64,
          sha256: hash?.close(),
        );
        infos.add(info);
        directory.add(_centralHeader(info, name));
        entry._written.complete(info);
        while (out.length - out.yielded >= chunkSize) {
          yield out.take();
        }
      }

      final cdOffset = out.length;
      final cd = directory.takeBytes();
      out.add(cd);
      final zip64End =
          forceZip64 ||
          entries.length >= ZipProfile.marker16 ||
          cd.length > zip32Max ||
          cdOffset > zip32Max;
      if (zip64End) {
        final recordOffset = out.length;
        out.add(_zip64EndRecord(entries.length, cd.length, cdOffset));
        out.add(_zip64Locator(recordOffset));
      }
      out.add(_endRecord(entries.length, cd.length, cdOffset, zip64End));
      final rest = out.take();
      for (var i = 0; i < rest.length; i += chunkSize) {
        yield Uint8List.sublistView(rest, i, min(i + chunkSize, rest.length));
      }
      _done.complete(
        ZipSummary(
          length: out.length,
          sha256: out.close(),
          entries: List.unmodifiable(infos),
        ),
      );
    } catch (e, s) {
      error = e;
      trace = s;
      rethrow;
    } finally {
      // Reached on an error and on a cancel alike.
      for (final entry in entries) {
        if (!entry._written.isCompleted) {
          entry._written.completeError(error, trace);
        }
      }
      if (!_done.isCompleted) _done.completeError(error, trace);
    }
  }

  /// zlib's `deflateBound` for raw deflate, with room to spare.
  static int _deflateBound(int n) => n + (n >> 12) + (n >> 14) + (n >> 25) + 64;

  static (int, int) _dosDateTime(DateTime t) {
    if (t.year < 1980) return (0, 1 << 5 | 1);
    if (t.year > 2107) {
      return (23 << 11 | 59 << 5 | 29, 127 << 9 | 12 << 5 | 31);
    }
    return (
      t.hour << 11 | t.minute << 5 | t.second ~/ 2,
      (t.year - 1980) << 9 | t.month << 5 | t.day,
    );
  }

  Uint8List _localHeader(Uint8List name, bool zip64) {
    final h = _Le(30 + name.length + (zip64 ? 20 : 0))
      ..u32(ZipProfile.localHeader)
      ..u16(zip64 ? ZipProfile.version45 : ZipProfile.version20)
      ..u16(ZipProfile.flags)
      ..u16(ZipProfile.deflate)
      ..u16(_dos.$1)
      ..u16(_dos.$2)
      ..u32(0)
      ..u32(zip64 ? ZipProfile.marker32 : 0)
      ..u32(zip64 ? ZipProfile.marker32 : 0)
      ..u16(name.length)
      ..u16(zip64 ? 20 : 0)
      ..bytes(name);
    if (zip64) {
      h
        ..u16(ZipProfile.zip64ExtraId)
        ..u16(16)
        ..u64(0)
        ..u64(0);
    }
    return h.done();
  }

  static Uint8List _descriptor(int crc, int compressed, int size, bool zip64) {
    final d = _Le(zip64 ? 24 : 16)
      ..u32(ZipProfile.descriptor)
      ..u32(crc);
    if (zip64) {
      d
        ..u64(compressed)
        ..u64(size);
    } else {
      d
        ..u32(compressed)
        ..u32(size);
    }
    return d.done();
  }

  Uint8List _centralHeader(ZipEntryInfo e, Uint8List name) {
    final offset64 = forceZip64 || e.offset > zip32Max;
    final extra = (e.zip64 ? 16 : 0) + (offset64 ? 8 : 0);
    final version = extra > 0 ? ZipProfile.version45 : ZipProfile.version20;
    final h = _Le(46 + name.length + (extra > 0 ? 4 + extra : 0))
      ..u32(ZipProfile.centralHeader)
      ..u16(version)
      ..u16(version)
      ..u16(ZipProfile.flags)
      ..u16(ZipProfile.deflate)
      ..u16(_dos.$1)
      ..u16(_dos.$2)
      ..u32(e.crc32)
      ..u32(e.zip64 ? ZipProfile.marker32 : e.compressedSize)
      ..u32(e.zip64 ? ZipProfile.marker32 : e.size)
      ..u16(name.length)
      ..u16(extra > 0 ? 4 + extra : 0)
      ..u16(0) // comment
      ..u16(0) // disk
      ..u16(0) // internal attributes
      ..u32(0) // external attributes
      ..u32(offset64 ? ZipProfile.marker32 : e.offset)
      ..bytes(name);
    if (extra > 0) {
      h
        ..u16(ZipProfile.zip64ExtraId)
        ..u16(extra);
      if (e.zip64) {
        h
          ..u64(e.size)
          ..u64(e.compressedSize);
      }
      if (offset64) h.u64(e.offset);
    }
    return h.done();
  }

  static Uint8List _zip64EndRecord(int count, int cdSize, int cdOffset) =>
      (_Le(56)
            ..u32(ZipProfile.zip64EndRecord)
            ..u64(ZipProfile.zip64EndRecordRest)
            ..u16(ZipProfile.version45)
            ..u16(ZipProfile.version45)
            ..u32(0)
            ..u32(0)
            ..u64(count)
            ..u64(count)
            ..u64(cdSize)
            ..u64(cdOffset))
          .done();

  static Uint8List _zip64Locator(int recordOffset) =>
      (_Le(20)
            ..u32(ZipProfile.zip64Locator)
            ..u32(0)
            ..u64(recordOffset)
            ..u32(1))
          .done();

  static Uint8List _endRecord(
    int count,
    int cdSize,
    int cdOffset,
    bool zip64,
  ) =>
      (_Le(22)
            ..u32(ZipProfile.endRecord)
            ..u16(0)
            ..u16(0)
            ..u16(zip64 ? ZipProfile.marker16 : count)
            ..u16(zip64 ? ZipProfile.marker16 : count)
            ..u32(zip64 ? ZipProfile.marker32 : cdSize)
            ..u32(zip64 ? ZipProfile.marker32 : cdOffset)
            ..u16(0))
          .done();
}

/// The bytes written so far: buffered until [take], counted and hashed in
/// order.
final class _Output {
  final _buffer = BytesBuilder(copy: false);
  final _hash = RunningSha256();

  /// Bytes added, and bytes handed out by [take].
  int length = 0;
  int yielded = 0;

  void add(Uint8List bytes) {
    _buffer.add(bytes);
    _hash.add(bytes);
    length += bytes.length;
  }

  /// Adds each of [chunks]; returns their total length.
  int addAll(List<Uint8List> chunks) {
    var n = 0;
    for (final c in chunks) {
      add(c);
      n += c.length;
    }
    return n;
  }

  Uint8List take() {
    final bytes = _buffer.takeBytes();
    yielded += bytes.length;
    return bytes;
  }

  String close() => _hash.close();
}

/// Collects a converter's output until [take].
final class _Collect implements Sink<List<int>> {
  var _chunks = <Uint8List>[];

  @override
  void add(List<int> data) =>
      _chunks.add(data is Uint8List ? data : Uint8List.fromList(data));

  @override
  void close() {}

  List<Uint8List> take() {
    final out = _chunks;
    _chunks = [];
    return out;
  }
}

/// A running sha256, fed chunk by chunk; [close] gives it in lower-case
/// hex. The reader uses it too.
final class RunningSha256 {
  factory RunningSha256() {
    final digest = _DigestSink();
    return RunningSha256._(
      digest,
      crypto.sha256.startChunkedConversion(digest),
    );
  }

  RunningSha256._(this._digest, this._input);

  final _DigestSink _digest;
  final ByteConversionSink _input;

  void add(List<int> bytes) => _input.add(bytes);

  String close() {
    _input.close();
    return _digest.value.toString();
  }
}

final class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}

/// A little-endian record of a fixed [length].
final class _Le {
  _Le(int length) : _b = Uint8List(length);

  final Uint8List _b;
  late final _d = ByteData.sublistView(_b);
  var _i = 0;

  void u16(int v) {
    _d.setUint16(_i, v, Endian.little);
    _i += 2;
  }

  void u32(int v) {
    _d.setUint32(_i, v, Endian.little);
    _i += 4;
  }

  void u64(int v) {
    _d.setUint64(_i, v, Endian.little);
    _i += 8;
  }

  void bytes(List<int> v) {
    _b.setRange(_i, _i + v.length, v);
    _i += v.length;
  }

  Uint8List done() {
    assert(_i == _b.length, 'record length');
    return _b;
  }
}

// From relay lib/data/files/backup_zip_reader.dart @ 09b28810, with
// LYCEUM's ENOSPC refusal from lyceum lib/data/files/bundle_zip_reader.dart @
// 9f4ff27; the apps' entry names and media-hash rule are hooks (D-APK-020).
/// The zip verifier (RELAY ruling R-15, D-APK-020): one pass over a zip as
/// a stream, as the backup target hands it back, holding a few chunks of it
/// at a time. RELAY verifies and restores its backups through it; LYCEUM
/// reads its export bundles back and stages an import through it.
///
/// It accepts exactly the zips `zip_writer.dart` writes (the profile,
/// described there) and checks, in order:
///
/// 1. each local header: its signature, the profile's fields (flags,
///    method, versions, the zero CRC and sizes, the ZIP64 field or none),
///    and a name that is UTF-8, safe to extract ([zipNameProblem]), allowed
///    by the caller (`nameAllowed`) and not repeated, before any of its data
///    is read or extracted;
/// 2. each entry's data: it is inflated as it arrives, and its CRC-32 and
///    its compressed and inflated sizes must be those of its data
///    descriptor. A descriptor is the first `PK\x07\x08` whose compressed
///    size is the number of bytes since the header, so a signature inside
///    the data is passed over. The caller's `onEntry` then sees the entry
///    (with its sha256 when asked for) and may reject it;
/// 3. the central directory, header by header against the entries read
///    (every field: versions, flags, time, CRC, sizes, name, offset, the
///    ZIP64 field), and the ZIP64 end records and the end record against
///    the directory's count, size and offset;
/// 4. that nothing follows the end record, and, when it is given, that
///    the sha256 of every byte read is the one expected.
///
/// The first check that fails ends the read with a [ZipRefused] failure; a
/// refusal is never thrown. Running out of space while extracting
/// (`ENOSPC`, errno 28) is [ZipRefusal.storageFull]. An error of the stream
/// itself (the target's own failure), or any other failure to write an
/// extracted entry, is rethrown.
///
/// A changed byte in a header, a descriptor, the directory or an end
/// record fails a check, and so does a change to an entry's data that
/// changes what it inflates to. A change that inflates to the same bytes
/// can pass: deflate has bits the output does not depend on (padding, a
/// final-block flag, some table bits), and dart:io's inflater does not
/// report where its stream ends. Such a zip still holds exactly the
/// content it was written with; to prove that every byte read is a byte
/// written, the caller passes the writer's sha256 as `expectedSha256`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';

import 'crc32.dart';
import 'zip_writer.dart';

/// `ENOSPC`, "no space left on device", on Linux and Android.
const int _noSpace = 28;

/// Why a zip was refused. Each app maps a refusal to its own message key
/// (D-APK-020): RELAY keeps [code], LYCEUM maps it to an import code.
enum ZipRefusal {
  /// The stream ended before the zip did.
  truncated,

  /// A signature, a header field outside the profile, a deflate stream
  /// that does not inflate, or bytes after the end record.
  corrupt,

  /// An entry's inflated data does not have its descriptor's CRC-32.
  crcMismatch,

  /// An entry's inflated data is not its descriptor's size.
  sizeMismatch,

  /// The central directory or an end record disagrees with the entries
  /// read, or with itself.
  directoryMismatch,

  /// A name that is not UTF-8, not safe to extract, not allowed by the
  /// caller, or repeated.
  unsafeName,

  /// An entry to keep in memory is larger than the limit.
  entryTooLarge,

  /// The zip is well formed, but its sha256 is not the expected one.
  digestMismatch,

  /// Writing an extracted entry ran out of space (`ENOSPC`).
  storageFull,

  /// The caller's `onEntry` check refused an entry that is otherwise well
  /// formed (LYCEUM: a media entry that is not its name's sha256).
  rejected;

  /// The message key: `zip` and the refusal (`zipTruncated`), so RELAY's
  /// codes keep their names.
  String get code => 'zip${name[0].toUpperCase()}${name.substring(1)}';
}

/// A refused zip: its code is [refusal]'s ([ZipRefusal.code]); [entry]
/// names the entry the refusal concerns, when its name was read and
/// allowed. Like every [Failure], it prints its code only, never the name.
final class ZipRefused extends Failure {
  ZipRefused(this.refusal, {this.entry}) : super(refusal.code);

  final ZipRefusal refusal;

  /// The entry's name, when the refusal concerns one.
  final String? entry;

  @override
  bool operator ==(Object other) =>
      other is ZipRefused && other.refusal == refusal && other.entry == entry;

  @override
  int get hashCode => Object.hash(ZipRefused, refusal, entry);

  @override
  String toString() => 'Failure($code)';
}

/// A zip that verified.
final class ZipContents {
  const ZipContents({
    required this.entries,
    required this.kept,
    required this.length,
    required this.sha256,
  });

  /// In the zip's order, with the sha256 of the entries asked for.
  final List<ZipEntryInfo> entries;

  /// The inflated bytes of the entries asked to be kept.
  final Map<String, Uint8List> kept;

  /// The zip's length and the sha256 of all of it, lower-case hex.
  final int length;
  final String sha256;

  /// The entry called [name], or null.
  ZipEntryInfo? entry(String name) {
    for (final e in entries) {
      if (e.name == name) return e;
    }
    return null;
  }
}

/// The caller's check of an entry that has checked out, its sha256 there
/// when `sha256Where` asked for it: false refuses the zip with
/// [ZipRefusal.rejected].
typedef ZipEntryCheck = bool Function(ZipEntryInfo entry);

/// Where extracted entries are written.
abstract interface class ExtractSink {
  /// The target of the entry [name], created or truncated. The name has
  /// passed [zipNameProblem] and `nameAllowed` first.
  ExtractTarget open(String name);
}

/// One extracted entry being written: [add] in order, [flush] once the
/// entry checks out, [close] always.
abstract interface class ExtractTarget {
  void add(List<int> bytes);

  void flush();

  void close();
}

/// Extracts into the file [fileFor] gives for each name (its directory
/// already made), flushed (an fsync) once the entry checks out.
final class FileExtractSink implements ExtractSink {
  FileExtractSink(this.fileFor);

  final File Function(String name) fileFor;

  @override
  ExtractTarget open(String name) =>
      _FileTarget(fileFor(name).openSync(mode: FileMode.write));
}

final class _FileTarget implements ExtractTarget {
  _FileTarget(this._file);

  final RandomAccessFile _file;

  @override
  void add(List<int> bytes) => _file.writeFromSync(bytes);

  @override
  void flush() => _file.flushSync();

  @override
  void close() => _file.closeSync();
}

/// Verifies the zip in [bytes] in one pass (see the library comment).
///
/// The entries [sha256Where] names get their sha256; those in [keep] are
/// returned inflated, each at most [keepLimit] bytes
/// ([ZipRefusal.entryTooLarge] beyond; each app passes its own: RELAY
/// 1 MiB, LYCEUM 16 MiB). With [expectedSha256], a zip whose bytes hash
/// otherwise is refused ([ZipRefusal.digestMismatch]).
///
/// [nameAllowed] narrows the names [zipNameProblem] lets through (LYCEUM's
/// entry shapes); [onEntry] sees each entry once it checks out.
///
/// The entries [extractWhere] names are inflated into [extract]'s target
/// as they are read, any size, and flushed once the entry checks out; a
/// restore stages its database this way. The targets are written even when
/// a later check fails: the caller deletes them unless the result is [Ok].
/// [extractWhere] and [extract] come together, or neither.
Future<Result<ZipContents, ZipRefused>> verifyZip(
  Stream<List<int>> bytes, {
  required int keepLimit,
  Set<String> keep = const {},
  String? expectedSha256,
  bool Function(String name)? sha256Where,
  bool Function(String name)? nameAllowed,
  ZipEntryCheck? onEntry,
  bool Function(String name)? extractWhere,
  ExtractSink? extract,
}) async {
  if ((extractWhere == null) != (extract == null)) {
    throw ArgumentError('extractWhere and extract come together');
  }
  final input = _Input(bytes);
  try {
    final contents = await _Verifier(
      input,
      keep: keep,
      keepLimit: keepLimit,
      sha256Where: sha256Where,
      nameAllowed: nameAllowed,
      onEntry: onEntry,
      extractWhere: extractWhere,
      extract: extract,
    ).run();
    if (expectedSha256 != null && contents.sha256 != expectedSha256) {
      return Err(ZipRefused(ZipRefusal.digestMismatch));
    }
    return Ok(contents);
  } on _Fail catch (f) {
    return Err(ZipRefused(f.refusal, entry: f.entry));
  } finally {
    await input.cancel();
  }
}

/// A failed check, caught by [verifyZip].
final class _Fail implements Exception {
  const _Fail(this.refusal, [this.entry]);

  final ZipRefusal refusal;
  final String? entry;
}

const _truncated = _Fail(ZipRefusal.truncated);
const _corrupt = _Fail(ZipRefusal.corrupt);
const _mismatch = _Fail(ZipRefusal.directoryMismatch);
const _unsafe = _Fail(ZipRefusal.unsafeName);

/// Runs a write to an extracted entry: `ENOSPC` becomes
/// [ZipRefusal.storageFull]; any other failure is rethrown as it is.
T _writing<T>(T Function() write) {
  try {
    return write();
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode == _noSpace) {
      throw const _Fail(ZipRefusal.storageFull);
    }
    rethrow;
  }
}

/// An entry as its local header and data were read.
final class _Read {
  _Read(this.info, this.name, this.time, this.date);

  final ZipEntryInfo info;
  final Uint8List name;
  final int time;
  final int date;
}

final class _Verifier {
  _Verifier(
    this.input, {
    required this.keep,
    required this.keepLimit,
    required this.sha256Where,
    required this.nameAllowed,
    required this.onEntry,
    required this.extractWhere,
    required this.extract,
  });

  final _Input input;
  final Set<String> keep;
  final int keepLimit;
  final bool Function(String name)? sha256Where;
  final bool Function(String name)? nameAllowed;
  final ZipEntryCheck? onEntry;
  final bool Function(String name)? extractWhere;
  final ExtractSink? extract;

  final _entries = <_Read>[];
  final _names = <String>{};
  final _kept = <String, Uint8List>{};

  Future<ZipContents> run() async {
    var at = input.offset;
    var sig = await input.u32();
    while (sig == ZipProfile.localHeader) {
      _entries.add(await _entry(at));
      at = input.offset;
      sig = await input.u32();
    }

    final cdOffset = at;
    var i = 0;
    while (sig == ZipProfile.centralHeader) {
      if (i == _entries.length) throw _mismatch;
      await _central(_entries[i++]);
      at = input.offset;
      sig = await input.u32();
    }
    if (i != _entries.length) throw _mismatch;
    final cdSize = at - cdOffset;
    final count = _entries.length;

    var zip64 = false;
    if (sig == ZipProfile.zip64EndRecord) {
      zip64 = true;
      final recordOffset = at;
      final r = await input.take(52);
      if (r.u64(0) != ZipProfile.zip64EndRecordRest ||
          r.u16(8) != ZipProfile.version45 ||
          r.u16(10) != ZipProfile.version45 ||
          r.u32(12) != 0 ||
          r.u32(16) != 0 ||
          r.u64(20) != count ||
          r.u64(28) != count ||
          r.u64(36) != cdSize ||
          r.u64(44) != cdOffset) {
        throw _mismatch;
      }
      if (await input.u32() != ZipProfile.zip64Locator) throw _corrupt;
      final l = await input.take(16);
      if (l.u32(0) != 0 || l.u64(4) != recordOffset || l.u32(12) != 1) {
        throw _mismatch;
      }
      sig = await input.u32();
    }
    if (sig != ZipProfile.endRecord) throw _corrupt;
    final e = await input.take(18);
    bool fits(int field, int marker, int actual) =>
        field == actual || (zip64 && field == marker);
    if (e.u16(0) != 0 ||
        e.u16(2) != 0 ||
        !fits(e.u16(4), ZipProfile.marker16, count) ||
        !fits(e.u16(6), ZipProfile.marker16, count) ||
        !fits(e.u32(8), ZipProfile.marker32, cdSize) ||
        !fits(e.u32(12), ZipProfile.marker32, cdOffset) ||
        e.u16(16) != 0) {
      throw _mismatch;
    }
    if (!await input.atEnd()) throw _corrupt;

    return ZipContents(
      entries: List.unmodifiable([for (final r in _entries) r.info]),
      kept: Map.unmodifiable(_kept),
      length: input.offset,
      sha256: input.digest(),
    );
  }

  /// The entry whose local header starts at [offset], its signature read.
  Future<_Read> _entry(int offset) async {
    final h = await input.take(26);
    final nameBytes = Uint8List.fromList(await input.bytes(h.u16(22)));
    final extra = await input.bytes(h.u16(24));
    final zip64 = extra.length == 20;
    if (zip64) {
      final x = _View(extra);
      if (x.u16(0) != ZipProfile.zip64ExtraId ||
          x.u16(2) != 16 ||
          x.u64(4) != 0 ||
          x.u64(12) != 0) {
        throw _corrupt;
      }
    } else if (extra.isNotEmpty) {
      throw _corrupt;
    }
    final placeholder = zip64 ? ZipProfile.marker32 : 0;
    if (h.u16(0) != (zip64 ? ZipProfile.version45 : ZipProfile.version20) ||
        h.u16(2) != ZipProfile.flags ||
        h.u16(4) != ZipProfile.deflate ||
        h.u32(10) != 0 ||
        h.u32(14) != placeholder ||
        h.u32(18) != placeholder) {
      throw _corrupt;
    }
    final String name;
    try {
      name = utf8.decode(nameBytes);
    } on FormatException {
      throw _unsafe;
    }
    if (zipNameProblem(name) != null ||
        !(nameAllowed?.call(name) ?? true) ||
        !_names.add(name)) {
      throw _unsafe;
    }

    try {
      final (crc, size, compressed, sha256) = await _data(name, zip64);
      final info = ZipEntryInfo(
        name: name,
        size: size,
        compressedSize: compressed,
        crc32: crc,
        offset: offset,
        zip64: zip64,
        sha256: sha256,
      );
      if (!(onEntry?.call(info) ?? true)) {
        throw const _Fail(ZipRefusal.rejected);
      }
      return _Read(info, nameBytes, h.u16(6), h.u16(8));
    } on _Fail catch (f) {
      throw f.entry == null ? _Fail(f.refusal, name) : f;
    }
  }

  /// Inflates an entry's data up to its descriptor and checks it: (CRC-32,
  /// size, compressed size, sha256 or null).
  Future<(int, int, int, String?)> _data(String name, bool zip64) async {
    final hash = (sha256Where?.call(name) ?? false) ? RunningSha256() : null;
    final kept = keep.contains(name) ? BytesBuilder(copy: false) : null;
    final sink = extract;
    final out = sink != null && extractWhere!(name)
        ? _writing(() => sink.open(name))
        : null;
    try {
      return await _inflate(name, zip64, hash, kept, out);
    } finally {
      if (out != null) _writing(out.close);
    }
  }

  /// [_data]'s inflation into [hash], [kept] and [out], when given.
  Future<(int, int, int, String?)> _inflate(
    String name,
    bool zip64,
    RunningSha256? hash,
    BytesBuilder? kept,
    ExtractTarget? out,
  ) async {
    final crc = Crc32();
    var size = 0;
    final inflater = ZLibDecoder(raw: true).startChunkedConversion(
      _Each((chunk) {
        crc.add(chunk);
        size += chunk.length;
        hash?.add(chunk);
        if (out != null) _writing(() => out.add(chunk));
        if (kept != null) {
          if (kept.length + chunk.length > keepLimit) {
            throw const _Fail(ZipRefusal.entryTooLarge);
          }
          kept.add(Uint8List.fromList(chunk));
        }
      }),
    );
    void inflate(Uint8List bytes, int from, int to) {
      try {
        inflater.add(Uint8List.sublistView(bytes, from, to));
      } on _Fail {
        rethrow;
      } on FileSystemException {
        // Writing an extracted entry failed: the caller's, not the zip's.
        rethrow;
      } on Object {
        throw _corrupt;
      }
    }

    final start = input.offset;
    final descriptorLength = zip64 ? 24 : 16;
    for (;;) {
      await input.need(1);
      final buf = input.buffer;
      final from = input.position;
      final end = buf.length;
      var candidate = from;
      for (; candidate < end; candidate++) {
        // `PK\x07\x08`, or as much of it as the buffer holds.
        if (buf[candidate] == 0x50 &&
            (candidate + 1 >= end || buf[candidate + 1] == 0x4b) &&
            (candidate + 2 >= end || buf[candidate + 2] == 0x07) &&
            (candidate + 3 >= end || buf[candidate + 3] == 0x08)) {
          break;
        }
      }
      if (candidate > from) {
        inflate(buf, from, candidate);
        input.skip(candidate - from);
      }
      if (candidate == end) continue;

      await input.need(descriptorLength);
      final d = _View(input.peek(descriptorLength));
      final compressed = zip64 ? d.u64(8) : d.u32(8);
      if (d.u32(0) == ZipProfile.descriptor &&
          compressed == input.offset - start) {
        input.skip(descriptorLength);
        try {
          inflater.close();
        } on _Fail {
          rethrow;
        } on FileSystemException {
          rethrow;
        } on Object {
          throw _corrupt;
        }
        if (d.u32(4) != crc.value) {
          throw const _Fail(ZipRefusal.crcMismatch);
        }
        if ((zip64 ? d.u64(16) : d.u32(12)) != size) {
          throw const _Fail(ZipRefusal.sizeMismatch);
        }
        if (kept != null) _kept[name] = kept.takeBytes();
        if (out != null) _writing(out.flush);
        return (crc.value, size, compressed, hash?.close());
      }
      // A signature inside the data: it is data.
      inflate(input.buffer, input.position, input.position + 1);
      input.skip(1);
    }
  }

  /// The central header of [r], its signature read.
  Future<void> _central(_Read r) async {
    final e = r.info;
    final h = await input.take(42);
    final name = await input.bytes(h.u16(24));
    final extra = await input.bytes(h.u16(26));
    await input.bytes(h.u16(28)); // a comment fails below
    final offsetField = h.u32(38);
    final want = [
      if (e.zip64) ...[e.size, e.compressedSize],
      if (offsetField == ZipProfile.marker32) e.offset,
    ];
    final version = want.isEmpty ? ZipProfile.version20 : ZipProfile.version45;
    final sizes = e.zip64
        ? (ZipProfile.marker32, ZipProfile.marker32)
        : (e.compressedSize, e.size);
    if (h.u16(0) != version ||
        h.u16(2) != version ||
        h.u16(4) != ZipProfile.flags ||
        h.u16(6) != ZipProfile.deflate ||
        h.u16(8) != r.time ||
        h.u16(10) != r.date ||
        h.u32(12) != e.crc32 ||
        h.u32(16) != sizes.$1 ||
        h.u32(20) != sizes.$2 ||
        h.u16(28) != 0 ||
        h.u16(30) != 0 ||
        h.u16(32) != 0 ||
        h.u32(34) != 0 ||
        (offsetField != ZipProfile.marker32 && offsetField != e.offset) ||
        !_same(name, r.name)) {
      throw _mismatch;
    }
    if (want.isEmpty) {
      if (extra.isNotEmpty) throw _mismatch;
      return;
    }
    final x = _View(extra);
    if (extra.length != 4 + 8 * want.length ||
        x.u16(0) != ZipProfile.zip64ExtraId ||
        x.u16(2) != 8 * want.length) {
      throw _mismatch;
    }
    for (final (i, value) in want.indexed) {
      if (x.u64(4 + 8 * i) != value) throw _mismatch;
    }
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The stream, buffered: whole chunks as they come, merged only when a
/// record spans two of them. Every byte is counted and hashed on arrival.
final class _Input {
  _Input(Stream<List<int>> bytes) : _chunks = StreamIterator(bytes);

  final StreamIterator<List<int>> _chunks;
  final _hash = RunningSha256();

  /// The current chunk and the read position in it.
  Uint8List buffer = Uint8List(0);
  int position = 0;

  /// The read position in the zip.
  int offset = 0;

  int get available => buffer.length - position;

  Future<bool> _next() async {
    if (!await _chunks.moveNext()) return false;
    final c = _chunks.current;
    final chunk = c is Uint8List ? c : Uint8List.fromList(c);
    _hash.add(chunk);
    if (available == 0) {
      buffer = chunk;
    } else {
      buffer = Uint8List(available + chunk.length)
        ..setRange(0, available, buffer, position)
        ..setRange(available, available + chunk.length, chunk);
    }
    position = 0;
    return true;
  }

  /// Waits until [n] bytes are buffered; [ZipRefusal.truncated] when the
  /// stream ends first.
  Future<void> need(int n) async {
    while (available < n) {
      if (!await _next()) throw _truncated;
    }
  }

  /// The next [n] bytes, without reading them; [need] them first.
  Uint8List peek(int n) =>
      Uint8List.sublistView(buffer, position, position + n);

  void skip(int n) {
    position += n;
    offset += n;
  }

  Future<Uint8List> bytes(int n) async {
    await need(n);
    final out = peek(n);
    skip(n);
    return out;
  }

  Future<_View> take(int n) async => _View(await bytes(n));

  Future<int> u32() async => (await take(4)).u32(0);

  /// Whether the stream has nothing after the read position.
  Future<bool> atEnd() async {
    while (available == 0) {
      if (!await _next()) return true;
    }
    return false;
  }

  String digest() => _hash.close();

  Future<void> cancel() => _chunks.cancel();
}

/// Little-endian fields of a record.
extension type _View._(ByteData _data) {
  _View(Uint8List bytes) : this._(ByteData.sublistView(bytes));

  int u16(int at) => _data.getUint16(at, Endian.little);
  int u32(int at) => _data.getUint32(at, Endian.little);
  int u64(int at) => _data.getUint64(at, Endian.little);
}

/// A sink that hands each chunk to a callback.
final class _Each implements Sink<List<int>> {
  _Each(this._onChunk);

  final void Function(List<int>) _onChunk;

  @override
  void add(List<int> data) => _onChunk(data);

  @override
  void close() {}
}

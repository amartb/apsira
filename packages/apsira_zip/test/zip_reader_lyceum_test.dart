// From lyceum test/data/files/bundle_zip_reader_test.dart @ 9f4ff27: the
// cases LYCEUM's reader added to RELAY's (zip_reader_test.dart holds the
// shared ones), run through the package's hooks as LYCEUM passes them —
// `nameAllowed: isSafeEntryName`, every media entry hashed and checked
// against its name (`onEntry`), extraction into a folder through
// `FileExtractSink`, a 16 MiB keep limit — and each refusal mapped to the
// import code LYCEUM's reader gave. LYCEUM's foreign zips came from Python's
// zipfile; here `archive` writes them (D-APK-020: no Python in the zip gate).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_zip/apsira_zip.dart';
import 'package:archive/archive.dart';
import 'package:test/test.dart';

import 'support/apps.dart';
import 'support/zips.dart';

final _manifest = utf8.encode('{"format":"lyceum-export-manifest","n":"ñ"}');

/// A bundle's entries: `lyceum.json`, two media files (one empty) at their
/// content-addressed names, and the manifest.
Map<String, Uint8List> _content({int db = 200 * kib}) {
  final m = randomBytes(db ~/ 40, 2);
  final empty = Uint8List(0);
  return {
    lyceumJsonEntry: pages(db, 1),
    mediaEntryName(sha(m)): m,
    mediaEntryName(sha(empty)): empty,
    manifestEntry: Uint8List.fromList(_manifest),
  };
}

List<ZipEntry> _entries(Map<String, Uint8List> content) => [
  for (final MapEntry(:key, :value) in content.entries)
    ZipEntry(
      key,
      key == lyceumJsonEntry ? chunks(value) : chunks(value, 1000),
      size: key == lyceumJsonEntry ? value.length : null,
      sha256: key == lyceumJsonEntry,
    ),
];

/// LYCEUM's reader: its names, its media rule, its keep limit.
Future<Result<ZipContents, ZipRefused>> _verify(
  Uint8List zip, {
  Set<String> sha256Of = const {},
  Set<String> keep = const {},
  int keepLimit = 16 * mib,
  String? expectedSha256,
  File? Function(String name)? extractWhere,
  List<int> cuts = const [64 * kib],
  List<int>? listens,
}) => verifyZip(
  streamOf(zip, cuts: cuts, listens: listens),
  keepLimit: keepLimit,
  keep: keep,
  expectedSha256: expectedSha256,
  nameAllowed: isSafeEntryName,
  sha256Where: lyceumSha256Where(sha256Of),
  onEntry: lyceumMediaHash,
  extractWhere: extractWhere == null ? null : (n) => extractWhere(n) != null,
  extract: extractWhere == null
      ? null
      : FileExtractSink((n) => extractWhere(n)!),
);

/// A scratch tree: `root/a/b/target` is where entries are extracted, so a
/// name climbing three levels would still land under [root], where the
/// test can see it.
final class _Tree {
  _Tree(this.root) : target = Directory('${root.path}/a/b/target') {
    target.createSync(recursive: true);
  }

  final Directory root;
  final Directory target;

  /// Every name placed, in order.
  final asked = <String>[];

  File? place(String name) {
    if (!asked.contains(name)) asked.add(name);
    final file = File('${target.path}/$name');
    file.parent.createSync(recursive: true);
    return file;
  }

  /// The files under [root] that are not under [target].
  List<String> outside() => [
    for (final f in root.listSync(recursive: true).whereType<File>())
      if (!f.path.startsWith('${target.path}/')) f.path,
  ];
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('apsira-zip-lyceum-');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('writer output verifies, entries extracted byte-equal with their '
      'sha256', () async {
    final content = _content();
    final (zip, summary) = await zipOf(_entries(content));
    var round = 0;
    for (final cuts in [
      [zip.length],
      [1],
      [7, 3, 4096, 1, 65536],
      [64 * kib],
    ]) {
      final tree = _Tree(Directory('${temp.path}/${round++}'));
      final listens = <int>[];
      final result = await _verify(
        zip,
        cuts: cuts,
        listens: listens,
        sha256Of: {lyceumJsonEntry, manifestEntry},
        keep: {manifestEntry},
        extractWhere: tree.place,
      );
      final contents = result.valueOrNull!;
      expect(listens, [1], reason: 'one listen, one pass');
      expect(contents.length, zip.length);
      expect(contents.sha256, summary.sha256);
      expect(
        contents.entry(lyceumJsonEntry)!.sha256,
        summary.entries[0].sha256,
      );
      expect(tree.asked, content.keys.toList());
      for (final MapEntry(key: name, value: bytes) in content.entries) {
        final extracted = File('${tree.target.path}/$name').readAsBytesSync();
        expect(extracted, bytes, reason: '$name byte-equal ($cuts)');
        expect(contents.entry(name)!.sha256, sha(extracted), reason: name);
      }
      expect(contents.kept.keys, [manifestEntry]);
      expect(contents.kept[manifestEntry], _manifest);
      expect(tree.outside(), isEmpty);
    }
  });

  test('media entries are hashed without being asked; others only when '
      'asked', () async {
    final content = _content(db: 3 * kib);
    final (zip, _) = await zipOf(_entries(content));
    final contents = (await _verify(zip)).valueOrNull!;
    for (final name in content.keys) {
      final media = storePathOfEntry(name) != null;
      expect(
        contents.entry(name)!.sha256,
        media ? sha(content[name]!) : isNull,
        reason: name,
      );
    }
    expect(contents.kept, isEmpty);
  });

  test('truncated, CRC-damaged, foreign and unsafe-name zips are refused '
      'with nothing extracted outside the target', () async {
    final content = _content(db: 3 * kib);
    final (zip, _) = await zipOf(_entries(content));
    final at = Layout(zip);
    var round = 0;

    Future<(ZipRefusal?, String?, _Tree)> refuse(Uint8List bad) async {
      final tree = _Tree(Directory('${temp.path}/${round++}'));
      final r = await _verify(bad, extractWhere: tree.place);
      expect(tree.outside(), isEmpty, reason: 'nothing outside the target');
      final why = refusalOf(r);
      return (why, why == null ? null : lyceumImportCode(why), tree);
    }

    // Truncated: cut inside an entry, inside the directory, before the end
    // record's last byte.
    for (final n in [40, at.descriptors[1] + 3, at.cdOffset + 10]) {
      final (why, code, _) = await refuse(Uint8List.sublistView(zip, 0, n));
      expect(why, ZipRefusal.truncated, reason: '$n bytes');
      expect(code, importChecksumMismatch, reason: '$n bytes');
    }
    final (cut, _, _) = await refuse(
      Uint8List.sublistView(zip, 0, zip.length - 1),
    );
    expect(cut, ZipRefusal.truncated);

    // CRC-damaged: the descriptor and the directory agree on a CRC the data
    // does not have.
    final crc = Uint8List.fromList(zip);
    put32(crc, at.descriptors[0] + 4, u32(zip, at.descriptors[0] + 4) ^ 1);
    put32(crc, at.central[0] + 16, u32(zip, at.central[0] + 16) ^ 1);
    final (crcWhy, crcCode, _) = await refuse(crc);
    expect(crcWhy, ZipRefusal.crcMismatch);
    expect(crcCode, importChecksumMismatch);

    // Foreign: a well-formed zip of the same names by another writer, and a
    // file that is no zip.
    final foreign = ZipEncoder().encodeBytes(
      Archive()
        ..add(ArchiveFile.bytes(lyceumJsonEntry, utf8.encode('{"f":1}')))
        ..add(ArchiveFile.bytes(manifestEntry, utf8.encode('{"m":1}'))),
    );
    final (why, code, tree) = await refuse(foreign);
    expect(why, ZipRefusal.corrupt);
    expect(code, importNotABundle);
    expect(tree.asked, isEmpty, reason: 'nothing placed');
    final (notZip, notZipCode, _) = await refuse(
      Uint8List.fromList(utf8.encode('not a zip at all')),
    );
    expect(notZip, ZipRefusal.corrupt);
    expect(notZipCode, importNotABundle);

    // Unsafe names, in the local header and the directory alike, each the
    // length of the media entry it replaces; none is placed.
    final mediaName = content.keys.elementAt(1);
    final length = utf8.encode(mediaName).length;
    String pad(String prefix) => prefix + 'a' * (length - prefix.length);
    final hash = mediaName.substring(length - 64);
    final unsafe = <String, List<int>>{
      'climbs': utf8.encode(pad('../../../')),
      'absolute': utf8.encode(pad('/media/')),
      'backslash': utf8.encode(mediaName.replaceAll('/', r'\')),
      'upper-case hash': utf8.encode(mediaName.toUpperCase()),
      'folders not its hash': utf8.encode(
        'media/${hash[0] == '0' ? '1' : '0'}${hash.substring(1, 4)}/$hash'
            .replaceRange(8, 8, '/'),
      ),
      'another shape': utf8.encode(pad('notes/')),
      'NUL': utf8.encode(mediaName)..[length - 1] = 0,
      'not UTF-8': utf8.encode(mediaName)..[length - 1] = 0xFF,
    };
    for (final MapEntry(key: why, value: name) in unsafe.entries) {
      final (refusal, code, tree) = await refuse(at.rename(1, name));
      expect(refusal, ZipRefusal.unsafeName, reason: why);
      expect(code, importNotABundle, reason: why);
      expect(tree.asked, [lyceumJsonEntry], reason: '$why: not placed');
    }
    // A repeated name: the second media entry takes the first one's.
    final (twice, twiceCode, twiceTree) = await refuse(
      at.rename(2, utf8.encode(mediaName)),
    );
    expect(twice, ZipRefusal.unsafeName);
    expect(twiceCode, importNotABundle);
    expect(twiceTree.asked, [lyceumJsonEntry, mediaName]);
  });

  test('a media entry whose content is not its name is rejected, '
      'importChecksumMismatch', () async {
    final content = _content(db: 3 * kib);
    final m = content.values.elementAt(1);
    final other = Uint8List.fromList(m)..[0] ^= 1;
    final (zip, _) = await zipOf([
      ZipEntry(mediaEntryName(sha(m)), Stream.value(other)),
    ]);
    final r = await _verify(zip);
    expect(refusalOf(r), ZipRefusal.rejected);
    expect(r.failureOrNull!.entry, mediaEntryName(sha(m)));
    expect(lyceumImportCode(refusalOf(r)!), importChecksumMismatch);
  });

  test('every flipped byte is refused or reads the same content', () async {
    final content = _content(db: 3 * kib);
    final (zip, summary) = await zipOf(_entries(content));
    final names = content.keys.toSet();
    final want = (await _verify(zip, sha256Of: names)).valueOrNull!.entries;
    final seen = <ZipRefusal>{};
    for (var i = 0; i < zip.length; i++) {
      final bad = Uint8List.fromList(zip)..[i] ^= 0xFF;
      switch (await _verify(bad, sha256Of: names)) {
        case Err(:final failure):
          seen.add(failure.refusal);
        case Ok(:final value):
          expect(
            [for (final e in value.entries) (e.name, e.size, e.sha256)],
            [for (final e in want) (e.name, e.size, e.sha256)],
            reason: 'byte $i: the same content, or a refusal',
          );
      }
    }
    expect(
      seen,
      containsAll([
        ZipRefusal.corrupt,
        ZipRefusal.crcMismatch,
        ZipRefusal.directoryMismatch,
        ZipRefusal.truncated,
        ZipRefusal.unsafeName,
      ]),
    );
    final r = await _verify(zip, expectedSha256: '0' * 64);
    expect(refusalOf(r), ZipRefusal.digestMismatch);
    expect(lyceumImportCode(refusalOf(r)!), importChecksumMismatch);
    expect((await _verify(zip, expectedSha256: summary.sha256)).isOk, isTrue);
  });

  test('a size mismatch and a kept entry over the limit', () async {
    final (zip, _) = await zipOf(_entries(_content(db: 3 * kib)));
    final at = Layout(zip);
    final size = Uint8List.fromList(zip);
    put32(size, at.descriptors[0] + 12, 3 * kib + 1);
    put32(size, at.central[0] + 24, 3 * kib + 1);
    final r = await _verify(size);
    expect(refusalOf(r), ZipRefusal.sizeMismatch);
    expect(lyceumImportCode(refusalOf(r)!), importChecksumMismatch);

    final big = await _verify(zip, keep: {manifestEntry}, keepLimit: 10);
    expect(refusalOf(big), ZipRefusal.entryTooLarge);
    expect(lyceumImportCode(refusalOf(big)!), importNotABundle);
  });

  test('no space left while extracting is importStorageFull', () async {
    final (zip, _) = await zipOf(_entries(_content(db: 3 * kib)));
    final r = await _verify(zip, extractWhere: (_) => File('/dev/full'));
    expect(refusalOf(r), ZipRefusal.storageFull);
    expect(lyceumImportCode(refusalOf(r)!), importStorageFull);
  }, skip: File('/dev/full').existsSync() ? false : 'no /dev/full here');

  test('another failure to extract is rethrown, not a refusal', () async {
    final (zip, _) = await zipOf(_entries(_content(db: 3 * kib)));
    await expectLater(
      _verify(zip, extractWhere: (n) => File('${temp.path}/missing/dir/$n')),
      throwsA(isA<FileSystemException>()),
    );
  });
}

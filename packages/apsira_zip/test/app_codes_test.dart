// AC-15.3 (D-APK-020): every ZipRefusal maps to a code RELAY's reader gave
// (its ZipCode names) and to the import code LYCEUM's reader gave, so no
// app's user-visible refusal changes when it moves onto apsira_zip. Each
// refusal is produced from a real damaged zip, then mapped by the app's
// table (test/support/apps.dart), which the adoption lanes copy.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apsira_zip/apsira_zip.dart';
import 'package:test/test.dart';

import 'support/apps.dart';
import 'support/zips.dart';

/// A zip whose reading ends in each refusal, as (bytes, how to read it).
Future<Map<ZipRefusal, Future<ZipRefusal?> Function()>> _scenarios() async {
  final (zip, _) = await zipOf([
    ZipEntry('a.db', chunks(pages(3 * kib, 1)), sha256: true),
    ZipEntry('abcdef', Stream.value(utf8.encode('{"m":1}'))),
  ]);
  final at = Layout(zip);
  Future<ZipRefusal?> read(
    Uint8List bytes, {
    int keepLimit = 1 << 20,
    String? expectedSha256,
    ZipEntryCheck? onEntry,
    ExtractSink? extract,
  }) async => refusalOf(
    await verifyZip(
      streamOf(bytes),
      keepLimit: keepLimit,
      keep: const {'abcdef'},
      expectedSha256: expectedSha256,
      sha256Where: (_) => true,
      onEntry: onEntry,
      extractWhere: extract == null ? null : (_) => true,
      extract: extract,
    ),
  );
  Uint8List patched(void Function(Uint8List) patch) =>
      Uint8List.fromList(zip)..apply(patch);

  return {
    ZipRefusal.truncated: () => read(Uint8List.sublistView(zip, 0, 100)),
    ZipRefusal.corrupt: () => read(Uint8List.fromList([...zip, 0])),
    ZipRefusal.crcMismatch: () => read(
      patched((b) {
        put32(b, at.descriptors[0] + 4, u32(b, at.descriptors[0] + 4) ^ 1);
        put32(b, at.central[0] + 16, u32(b, at.central[0] + 16) ^ 1);
      }),
    ),
    ZipRefusal.sizeMismatch: () => read(
      patched((b) {
        put32(b, at.descriptors[0] + 12, 3 * kib + 1);
        put32(b, at.central[0] + 24, 3 * kib + 1);
      }),
    ),
    ZipRefusal.directoryMismatch: () =>
        read(patched((b) => put16(b, at.central[1] + 12, 1))),
    ZipRefusal.unsafeName: () => read(at.rename(1, utf8.encode('../abc'))),
    ZipRefusal.entryTooLarge: () => read(zip, keepLimit: 2),
    ZipRefusal.digestMismatch: () => read(zip, expectedSha256: '0' * 64),
    ZipRefusal.storageFull: () => read(
      zip,
      extract: RecordingSink(
        fail: (name, step) {
          if (step == 'add') throw noSpace(name);
        },
      ),
    ),
    ZipRefusal.rejected: () => read(zip, onEntry: (e) => e.name != 'abcdef'),
  };
}

/// The undamaged zip of [_scenarios], read the same way: no refusal.
Future<ZipRefusal?> _control() async {
  final (zip, summary) = await zipOf([
    ZipEntry('a.db', chunks(pages(3 * kib, 1)), sha256: true),
    ZipEntry('abcdef', Stream.value(utf8.encode('{"m":1}'))),
  ]);
  return refusalOf(
    await verifyZip(
      streamOf(zip),
      keepLimit: 1 << 20,
      keep: const {'abcdef'},
      expectedSha256: summary.sha256,
      sha256Where: (_) => true,
      onEntry: (_) => true,
      extractWhere: (_) => true,
      extract: RecordingSink(),
    ),
  );
}

void main() {
  test('every refusal comes from its damage', () async {
    expect(await _control(), isNull, reason: 'undamaged, it reads');
    final scenarios = await _scenarios();
    expect(scenarios.keys.toSet(), ZipRefusal.values.toSet());
    for (final MapEntry(key: want, value: read) in scenarios.entries) {
      expect(await read(), want, reason: want.name);
    }
  });

  test('RELAY: every refusal is the ZipCode RELAY gave, ENOSPC its storage '
      'failure', () async {
    final scenarios = await _scenarios();
    for (final MapEntry(key: refusal, value: read) in scenarios.entries) {
      final code = relayCode((await read())!);
      if (refusal == ZipRefusal.storageFull) {
        // RELAY's reader rethrew the FileSystemException; its restore
        // reported its storage failure.
        expect(code, relayRestoreStorageFull);
      } else {
        expect(relayZipCodes, contains(code), reason: refusal.name);
      }
    }
    // The eight RELAY codes, each from the refusal of the same name.
    expect([
      for (final r in ZipRefusal.values)
        if (r != ZipRefusal.storageFull && r != ZipRefusal.rejected)
          relayCode(r),
    ], relayZipCodes);
  });

  test(
    "LYCEUM: every refusal is the import code LYCEUM's reader gave",
    () async {
      final scenarios = await _scenarios();
      for (final MapEntry(key: refusal, value: read) in scenarios.entries) {
        final lyceumName = refusal == ZipRefusal.rejected
            ? 'mediaHashMismatch'
            : refusal.name;
        final code = lyceumImportCode((await read())!);
        expect(code, lyceumTable[lyceumName], reason: refusal.name);
        expect(importCodes, contains(code), reason: refusal.name);
      }
      expect(
        {for (final r in ZipRefusal.values) lyceumImportCode(r)},
        {importNotABundle, importChecksumMismatch, importStorageFull},
      );
      expect(lyceumTable.length, ZipRefusal.values.length);
    },
  );

  test('/dev/full is storageFull for both apps', () async {
    final (zip, _) = await zipOf([
      ZipEntry('a', Stream.value(const [1])),
    ]);
    final r = refusalOf(
      await verifyZip(
        streamOf(zip),
        keepLimit: 1 << 20,
        extractWhere: (_) => true,
        extract: FileExtractSink((_) => File('/dev/full')),
      ),
    );
    expect(relayCode(r!), relayRestoreStorageFull);
    expect(lyceumImportCode(r), importStorageFull);
  }, skip: File('/dev/full').existsSync() ? false : 'no /dev/full here');
}

extension on Uint8List {
  void apply(void Function(Uint8List) patch) => patch(this);
}

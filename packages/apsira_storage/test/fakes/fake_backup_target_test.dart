// From relay test/fakes/fake_backup_target_test.dart @ 09b28810.
import 'dart:io';

import 'package:apsira_storage/apsira_storage.dart';
import 'package:apsira_storage/testing.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<List<int>> _bytes(List<int> data) => Stream.value(data);

Future<List<int>> _readAll(Stream<List<int>> s) async =>
    (await s.toList()).expand((c) => c).toList();

void main() {
  late Directory dir;
  late FakeBackupTarget target;
  late BackupFolder folder;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fake_backup_target_');
    target = FakeBackupTarget(dir);
    folder = target.folder;
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  final data = List<int>.generate(100, (i) => i);

  group('operations', () {
    test('pickFolder returns the folder, or null when the user cancels', () {
      expect(target.pickFolder(), completion(folder));
      target.userPicks = false;
      expect(target.pickFolder(), completion(isNull));
    });

    test('hasAccess is false for a revoked or foreign folder', () async {
      expect(await target.hasAccess(folder), isTrue);
      const other = BackupFolder(uri: 'content://elsewhere', displayName: 'x');
      expect(await target.hasAccess(other), isFalse);
      target.revokeAccess();
      expect(await target.hasAccess(folder), isFalse);
      expect(
        (await target.list(folder)).failureOrNull,
        BackupTarget.folderUnavailable,
      );
      await target.pickFolder();
      expect(await target.hasAccess(folder), isTrue);
    });

    test('write, list and read a file', () async {
      final written = await target.write(folder, 'a.zip', _bytes(data));
      expect(written.valueOrNull?.name, 'a.zip');
      expect(written.valueOrNull?.sizeBytes, 100);
      final listed = (await target.list(folder)).valueOrNull!;
      expect(listed.map((f) => f.name), ['a.zip']);
      expect(await _readAll(target.read(folder, 'a.zip')), data);
    });

    test('write refuses an existing name and keeps the file', () async {
      await target.write(folder, 'a.zip', _bytes(data));
      final again = await target.write(folder, 'a.zip', _bytes([1, 2, 3]));
      expect(again.failureOrNull, BackupTarget.exists);
      expect(await _readAll(target.read(folder, 'a.zip')), data);
    });

    test('rename moves a file and refuses an existing target', () async {
      await target.write(folder, 'a.part', _bytes(data));
      await target.write(folder, 'b.zip', _bytes([9]));
      expect(
        (await target.rename(folder, 'a.part', 'b.zip')).failureOrNull,
        BackupTarget.exists,
      );
      final moved = await target.rename(folder, 'a.part', 'a.zip');
      expect(moved.valueOrNull?.name, 'a.zip');
      final names = (await target.list(folder)).valueOrNull!.map((f) => f.name);
      expect(names, ['a.zip', 'b.zip']);
      expect(
        (await target.rename(folder, 'gone', 'c.zip')).failureOrNull,
        BackupTarget.missing,
      );
    });

    test('delete removes a file; a missing name is already deleted', () async {
      await target.write(folder, 'a.zip', _bytes(data));
      expect((await target.delete(folder, 'a.zip')).isOk, isTrue);
      expect((await target.delete(folder, 'a.zip')).isOk, isTrue);
      expect((await target.list(folder)).valueOrNull, isEmpty);
    });

    test('reading a missing file errors with missing', () {
      expect(
        target.read(folder, 'gone.zip').toList(),
        throwsA(
          isA<BackupTargetException>().having(
            (e) => e.failure,
            'failure',
            BackupTarget.missing,
          ),
        ),
      );
    });

    test('a name with a path separator is a bug', () {
      expect(
        () => target.write(folder, '../x', _bytes(data)),
        throwsArgumentError,
      );
    });
  });

  group('fault injection', () {
    test(
      'fault: the next write fails with storageFull, then writes work',
      () async {
        target.failNext(FakeBackupOp.write, failure: BackupTarget.storageFull);
        expect(
          (await target.write(folder, 'a.zip', _bytes(data))).failureOrNull,
          BackupTarget.storageFull,
        );
        expect(File('${dir.path}/a.zip').existsSync(), isFalse);
        expect(
          (await target.write(folder, 'a.zip', _bytes(data))).isOk,
          isTrue,
        );
      },
    );

    test('fault: a failed write can leave a partial file', () async {
      target.failNext(
        FakeBackupOp.write,
        failure: BackupTarget.storageFull,
        afterBytes: 10,
      );
      final r = await target.write(folder, 'a.part', _bytes(data));
      expect(r.failureOrNull, BackupTarget.storageFull);
      expect(File('${dir.path}/a.part').lengthSync(), 10);
    });

    test('fault: the next rename, delete and list fail', () async {
      await target.write(folder, 'a.part', _bytes(data));
      target.failNext(FakeBackupOp.rename);
      expect(
        (await target.rename(folder, 'a.part', 'a.zip')).failureOrNull,
        BackupTarget.folderUnavailable,
      );
      expect(File('${dir.path}/a.part').existsSync(), isTrue);
      target.failNext(FakeBackupOp.delete);
      expect((await target.delete(folder, 'a.part')).isErr, isTrue);
      expect(File('${dir.path}/a.part').existsSync(), isTrue);
      target.failNext(FakeBackupOp.list);
      expect((await target.list(folder)).isErr, isTrue);
      expect((await target.list(folder)).isOk, isTrue);
    });

    test('fault: the next read fails with the failure given', () async {
      await target.write(folder, 'a.zip', _bytes(data));
      target.failNext(
        FakeBackupOp.read,
        failure: BackupTarget.folderUnavailable,
      );
      await expectLater(
        target.read(folder, 'a.zip').toList(),
        throwsA(
          isA<BackupTargetException>().having(
            (e) => e.failure,
            'failure',
            BackupTarget.folderUnavailable,
          ),
        ),
      );
      expect(await _readAll(target.read(folder, 'a.zip')), data);
    });

    test(
      'fault: the next read corrupts one byte, the file is intact',
      () async {
        await target.write(folder, 'a.zip', _bytes(data));
        target.corruptNextRead(at: 7);
        final read = await _readAll(target.read(folder, 'a.zip'));
        expect(read.length, 100);
        expect(read[7], isNot(data[7]));
        expect([...read]..[7] = data[7], data);
        expect(await _readAll(target.read(folder, 'a.zip')), data);
      },
    );

    test('fault: the next read fails part-way', () async {
      await target.write(folder, 'a.zip', _bytes(data));
      target.failNext(FakeBackupOp.read, afterBytes: 40);
      final got = <int>[];
      await expectLater(
        target.read(folder, 'a.zip').forEach(got.addAll),
        throwsA(isA<BackupTargetException>()),
      );
      expect(got, data.sublist(0, 40));
    });

    test('fault: the next read corrupts the middle byte by default', () async {
      await target.write(folder, 'a.zip', _bytes(data));
      target.corruptNextRead();
      final read = await _readAll(target.read(folder, 'a.zip'));
      expect(read[50], isNot(data[50]));
    });

    test('fault: the next read is truncated', () async {
      await target.write(folder, 'a.zip', _bytes(data));
      target.truncateNextRead(keep: 30);
      expect(await _readAll(target.read(folder, 'a.zip')), data.sublist(0, 30));
      target.truncateNextRead();
      expect(await _readAll(target.read(folder, 'a.zip')), data.sublist(0, 50));
      expect(await _readAll(target.read(folder, 'a.zip')), data);
    });

    test('fault: deletes are recorded, failed ones included', () async {
      await target.write(folder, 'a.zip', _bytes(data));
      await target.write(folder, 'b.zip', _bytes(data));
      await target.delete(folder, 'a.zip');
      target.failNext(FakeBackupOp.delete);
      await target.delete(folder, 'b.zip');
      expect(target.deletes, ['a.zip', 'b.zip']);
      final names = (await target.list(folder)).valueOrNull!.map((f) => f.name);
      expect(names, ['b.zip']);
    });
  });
}

// The ApsiraBackupTarget fake for app tests (contract app-link.md §5.1;
// K2-01): the real adapter over FakeApsiraLink (a good hello) and
// FakeApsiraBackupLink, so an app's backup code is tested against §5.2's
// rules. Written from the contract; no source app.
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:apsira_storage/apsira_storage.dart';

import '../src/apsira_backup_target.dart';
import '../src/link_failure.dart';
import '../src/link_hello.dart';
import 'fake_apsira_link.dart';
import 'fake_backup_link.dart';

/// An [ApsiraBackupTarget] over [link] (answering a good `hello`) and
/// [backups] (an in-memory APSIRA queue). A test makes APSIRA unavailable
/// through [link] or [backups], ships a backup with [FakeApsiraBackupLink.ship]
/// and reads what was handed over with [FakeApsiraBackupLink.bytesOf].
final class FakeApsiraBackupTarget implements BackupTarget {
  /// [clock] stamps the files written and the backups' `made_utc` (by
  /// default a fixed 2026-01-01T00:00Z).
  factory FakeApsiraBackupTarget({
    String appPackage = 'com.example.app',
    Clock? clock,
  }) {
    final time = clock ?? FakeClock(DateTime.utc(2026));
    final link = FakeApsiraLink(
      hello: const Ok<LinkHello, LinkFailure>(
        LinkHello(
          version: '1.0',
          versions: ['1.0'],
          appVersion: '1.0.0',
          locked: false,
        ),
      ),
    );
    final backups = FakeApsiraBackupLink(clock: time);
    return FakeApsiraBackupTarget._(
      link,
      backups,
      ApsiraBackupTarget(
        link: link,
        backups: backups,
        appPackage: appPackage,
        clock: time,
      ),
    );
  }

  FakeApsiraBackupTarget._(this.link, this.backups, this.target);

  /// APSIRA's `hello`; set [FakeApsiraLink.helloResult] to make it fail.
  final FakeApsiraLink link;

  /// APSIRA's backup queue.
  final FakeApsiraBackupLink backups;

  /// The adapter under test, which every method delegates to.
  final ApsiraBackupTarget target;

  /// APSIRA's virtual folder, `apsira:<appPackage>`.
  BackupFolder get folder => target.folder;

  @override
  Future<BackupFolder?> pickFolder() => target.pickFolder();

  @override
  Future<bool> hasAccess(BackupFolder folder) => target.hasAccess(folder);

  @override
  Future<int?> freeBytes(BackupFolder folder) => target.freeBytes(folder);

  @override
  Future<Result<BackupFile, Failure>> write(
    BackupFolder folder,
    String name,
    Stream<List<int>> bytes,
  ) => target.write(folder, name, bytes);

  @override
  Future<Result<BackupFile, Failure>> rename(
    BackupFolder folder,
    String from,
    String to,
  ) => target.rename(folder, from, to);

  @override
  Future<Result<void, Failure>> delete(BackupFolder folder, String name) =>
      target.delete(folder, name);

  @override
  Future<Result<List<BackupFile>, Failure>> list(BackupFolder folder) =>
      target.list(folder);

  @override
  Stream<List<int>> read(BackupFolder folder, String name) =>
      target.read(folder, name);
}

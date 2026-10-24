// The consumers' Android backup rules against the per-install paths
// (D-APK-022, AC-17.6): VIATICUM's real rules (78d38e0) exclude alarms/ from
// the cloud backup and the device transfer; RELAY's (09b28810) do not yet,
// which its adoption fixes. Both files are copied unchanged as fixtures.
import 'dart:io';

import 'package:apsira_notify/apsira_notify.dart';
import 'package:apsira_notify/testing.dart';
import 'package:flutter_test/flutter_test.dart';

final _viaticum = File(
  'test/alarms/fixtures/viaticum_data_extraction_rules.xml',
);
final _relay = File('test/alarms/fixtures/relay_data_extraction_rules.xml');

void main() {
  test('the paths are the registry\'s and the snooze store\'s', () {
    expect(alarmInstallPaths, [
      AlarmRegistry.defaultPath,
      SnoozeStore.defaultPath,
    ]);
  });

  test('VIATICUM\'s rules exclude both paths from the cloud backup and the '
      'device transfer', () {
    expectExcludedFromDeviceBackup(_viaticum, paths: alarmInstallPaths);
  });

  test('RELAY\'s rules copy both paths in both sections', () {
    expect(
      () => expectExcludedFromDeviceBackup(_relay, paths: alarmInstallPaths),
      throwsA(
        isA<BackupExclusionFailure>().having((f) => f.gaps, 'gaps', [
          'alarms/registry.json: not excluded in <cloud-backup>',
          'alarms/registry.json: not excluded in <device-transfer>',
          'alarms/snoozes.json: not excluded in <cloud-backup>',
          'alarms/snoozes.json: not excluded in <device-transfer>',
        ]),
      ),
    );
  });

  group('the line scan', () {
    const both = '''
<data-extraction-rules>
  <cloud-backup disableIfNoEncryptionCapabilities="false">
    <exclude path="alarms/registry.json" domain="file"/>
    <exclude domain="database" path="alarms/snoozes.json" />
  </cloud-backup>
  <!-- <device-transfer><exclude domain="file" path="alarms/" /></device-transfer> -->
</data-extraction-rules>
''';

    test('reads attributes in any order, only the file domain, never a '
        'comment; a missing section is a gap', () {
      expect(backupExclusionGaps(both, paths: alarmInstallPaths), [
        'alarms/registry.json: no <device-transfer> section',
        'alarms/snoozes.json: not excluded in <cloud-backup>',
        'alarms/snoozes.json: no <device-transfer> section',
      ]);
    });

    test('a folder without its slash covers its files; a prefix that is not '
        'a folder does not', () {
      const rules = '''
<data-extraction-rules>
  <cloud-backup><exclude domain="file" path="alarms" /></cloud-backup>
  <device-transfer><exclude domain="file" path="alarm" /></device-transfer>
</data-extraction-rules>
''';
      expect(backupExclusionGaps(rules, paths: [AlarmRegistry.defaultPath]), [
        'alarms/registry.json: not excluded in <device-transfer>',
      ]);
    });

    test('full_backup_content is checked when given', () {
      final viaticum = _viaticum.readAsStringSync();
      const full = '''
<full-backup-content>
  <exclude domain="file" path="alarms/registry.json" />
</full-backup-content>
''';
      expect(
        backupExclusionGaps(
          viaticum,
          fullBackupContent: full,
          paths: alarmInstallPaths,
        ),
        ['alarms/snoozes.json: not excluded in <full-backup-content>'],
      );
      expect(
        backupExclusionGaps(
          viaticum,
          fullBackupContent: '<full-backup-content/>',
          paths: [AlarmRegistry.defaultPath],
        ),
        ['alarms/registry.json: not excluded in <full-backup-content>'],
      );
    });
  });
}

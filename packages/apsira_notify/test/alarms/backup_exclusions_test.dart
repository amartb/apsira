// The consumers' Android backup rules against the per-install paths
// (D-APK-022, AC-17.6, F1.1): VIATICUM's real rules (78d38e0) exclude alarms/
// from the cloud backup and the device transfer; RELAY's (09b28810) do not
// yet, and neither excludes the notification plugin's scheduled list, which
// their adoptions fix. Both files are copied unchanged as fixtures.
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

  group('every domain (F1.1)', () {
    const prefs = 'scheduled_notifications.xml';
    const migrating = 'app_flutter/lyceum.sqlite.migrating';
    const required = [
      BackupPath.file(AlarmRegistry.defaultPath),
      BackupPath.sharedPref(prefs),
      BackupPath.root(migrating),
    ];

    String rules(String excludes) =>
        '''
<data-extraction-rules>
  <cloud-backup>$excludes</cloud-backup>
  <device-transfer>$excludes</device-transfer>
</data-extraction-rules>
''';

    test('the per-install set names the plugin\'s scheduled list beside the '
        'registry\'s files', () {
      expect(flnScheduledNotifications, const BackupPath.sharedPref(prefs));
      expect(alarmBackupExclusions, [
        for (final p in alarmInstallPaths) BackupPath.file(p),
        flnScheduledNotifications,
      ]);
    });

    test('VIATICUM\'s and RELAY\'s rules copy the scheduled list in both '
        'sections', () {
      for (final file in [_viaticum, _relay]) {
        final gaps = backupExclusionGaps(
          file.readAsStringSync(),
          excluded: [flnScheduledNotifications],
        );
        expect(gaps, [
          'sharedpref:$prefs: not excluded in <cloud-backup>',
          'sharedpref:$prefs: not excluded in <device-transfer>',
        ], reason: file.path);
      }
    });

    test('red with each one missing, green when all are there', () {
      const all = '''
<exclude domain="file" path="alarms/" />
<exclude domain="sharedpref" path="scheduled_notifications.xml" />
<exclude domain="root" path="app_flutter/lyceum.sqlite.migrating" />
''';
      expect(backupExclusionGaps(rules(all), excluded: required), isEmpty);
      for (final missing in required) {
        final without = all
            .split('\n')
            .where((l) => !l.contains('"${missing.path.split('/').first}'))
            .join('\n');
        expect(backupExclusionGaps(rules(without), excluded: required), [
          '$missing: not excluded in <cloud-backup>',
          '$missing: not excluded in <device-transfer>',
        ], reason: '$missing');
      }
    });

    test('an exclusion counts in its own domain only: the marker excluded as '
        'a file, or the list as a database, is a gap', () {
      const wrong = '''
<exclude domain="file" path="app_flutter/lyceum.sqlite.migrating" />
<exclude domain="database" path="scheduled_notifications.xml" />
<exclude domain="sharedpref" path="alarms/" />
''';
      expect(backupExclusionGaps(rules(wrong), excluded: required), [
        for (final p in required) ...[
          '$p: not excluded in <cloud-backup>',
          '$p: not excluded in <device-transfer>',
        ],
      ]);
    });

    test('a root folder covers the domains under it; a list named without '
        '.xml covers its file, as Android reads it', () {
      const root = '''
<exclude domain="root" path="files/alarms" />
<exclude domain="root" path="shared_prefs/" />
<exclude domain="root" path="app_flutter/" />
''';
      expect(backupExclusionGaps(rules(root), excluded: required), isEmpty);
      const bare =
          '<exclude domain="sharedpref" path="scheduled_notifications" />';
      expect(
        backupExclusionGaps(rules(bare), excluded: [flnScheduledNotifications]),
        isEmpty,
      );
    });

    test('full_backup_content is read in every domain too', () {
      const all = '''
<exclude domain="file" path="alarms/" />
<exclude domain="sharedpref" path="scheduled_notifications.xml" />
<exclude domain="root" path="app_flutter/lyceum.sqlite.migrating" />
''';
      const full = '''
<full-backup-content>
  <exclude domain="file" path="alarms/" />
  <exclude domain="root" path="app_flutter/lyceum.sqlite.migrating" />
</full-backup-content>
''';
      expect(
        backupExclusionGaps(
          rules(all),
          fullBackupContent: full,
          excluded: required,
        ),
        ['sharedpref:$prefs: not excluded in <full-backup-content>'],
      );
    });

    test('expectExcludedFromDeviceBackup takes both lists', () {
      expect(
        () => expectExcludedFromDeviceBackup(
          _viaticum,
          paths: alarmInstallPaths,
          excluded: [flnScheduledNotifications],
        ),
        throwsA(
          isA<BackupExclusionFailure>().having((f) => f.gaps, 'gaps', [
            'sharedpref:$prefs: not excluded in <cloud-backup>',
            'sharedpref:$prefs: not excluded in <device-transfer>',
          ]),
        ),
      );
    });
  });
}

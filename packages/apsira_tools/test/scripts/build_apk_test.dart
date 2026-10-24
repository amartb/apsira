// lib/scripts/build_apk.sh: the dev APK, the merged prodRelease manifest
// check and any APK checks, driven by the app's APSIRA_* settings. With
// RELAY's, VIATICUM's and LYCEUM's settings, `--dry-run` prints exactly the
// commands each app's tool/build_apk.sh runs at its pinned commit, and a
// real run against stub tools runs exactly those. It builds no release and
// reads no key, so it runs in a session too: the conductor builds the dev
// APK there. Tests run from the package root.
import 'dart:io';

import 'package:test/test.dart';

import 'app_settings.dart';
import 'sandbox.dart';

void main() {
  for (final app in apps) {
    group(app.name, () {
      test('--dry-run prints its build_apk lines and runs nothing', () {
        final box = Sandbox();
        final result = box.run('build_apk', [
          '--dry-run',
        ], box.env(app.settings));
        expect(result.exitCode, 0, reason: out(result));
        final lines = '${result.stdout}'.trim().split('\n');
        expect(lines.first, startsWith('build_apk: dry run'));
        expect(lines.skip(1).toList(), app.buildApk);
        expect(box.calls, isEmpty);
        expect(Directory('${box.root}/build').existsSync(), isFalse);
      });

      test('a run executes exactly those lines, in order', () {
        final box = Sandbox();
        final result = box.run(
          'build_apk',
          [],
          box.env({...app.settings, 'ANDROID_HOME': box.sdk}),
        );
        expect(result.exitCode, 0, reason: out(result));
        expect(box.calls, app.buildApk);
        final apk =
            '${box.root}/build/app/outputs/flutter-apk/app-dev-debug.apk';
        expect('${result.stdout}', contains('APK: $apk\n'));
        expect('${result.stdout}', matches(RegExp(r'SHA-256: [0-9a-f]{64}\n')));
      });
    });
  }

  test('profile builds the profile APK', () {
    final box = Sandbox();
    final result = box.run('build_apk', [
      '--dry-run',
      'profile',
    ], box.env(lyceum.settings));
    expect(result.exitCode, 0, reason: out(result));
    expect(
      '${result.stdout}',
      contains('flutter build apk --flavor dev --profile\n'),
    );
  });

  test('it runs in a session: the dev APK carries no release key', () {
    final box = Sandbox();
    final result = box.run(
      'build_apk',
      [],
      box.env({'ANDROID_HOME': box.sdk, 'ARMY_TASK': 'T4', 'CLAUDECODE': '1'}),
    );
    expect(result.exitCode, 0, reason: out(result));
    expect(box.calls.first, 'flutter build apk --flavor dev --debug');
  });

  test(
    'the default settings are the dev and prod flavours and the package check',
    () {
      final box = Sandbox();
      final result = box.run('build_apk', ['--dry-run'], box.env());
      expect(result.exitCode, 0, reason: out(result));
      expect(
        '${result.stdout}'.trim().split('\n').skip(1).toList(),
        lyceum.buildApk,
      );
    },
  );

  test('other flavours name the APK and the merged manifest', () {
    final box = Sandbox();
    final result = box.run('build_apk', [
      '--dry-run',
    ], box.env({'APSIRA_FLAVOURS': 'beta store'}));
    expect(result.exitCode, 0, reason: out(result));
    expect('${result.stdout}'.trim().split('\n').skip(1).toList(), [
      'flutter build apk --flavor beta --debug',
      '(cd android && ./gradlew :app:processStoreReleaseManifest)',
      'dart run apsira_tools:manifest_check --manifest build/app/intermediates/merged_manifests/storeRelease',
    ]);
  });

  test('a failing step stops the build and is named', () {
    final box = Sandbox();
    final result = box.run(
      'build_apk',
      [],
      box.env({
        ...viaticum.settings,
        'ANDROID_HOME': box.sdk,
        'STUB_FAIL': 'dart run tool/privacy/manifest_check',
      }),
    );
    expect(result.exitCode, 1, reason: out(result));
    expect('${result.stderr}', contains('build_apk: FAIL (manifest)'));
    expect(box.calls.last, startsWith('dart run tool/privacy/manifest_check'));
    expect('${result.stdout}', isNot(contains('SHA-256')));
  });

  test('without ANDROID_HOME nothing is built (exit 1)', () {
    final box = Sandbox();
    final unset = box.run('build_apk', [], box.env());
    expect(unset.exitCode, 1);
    expect('${unset.stderr}', contains('ANDROID_HOME is not set'));
    final missing = box.run(
      'build_apk',
      [],
      box.env({'ANDROID_HOME': '${box.root}/none'}),
    );
    expect(missing.exitCode, 1);
    expect('${missing.stderr}', contains('is not a folder'));
    expect(box.calls, isEmpty);
  });

  for (final args in [
    ['release'],
    ['debug', 'profile'],
    ['--bogus'],
  ]) {
    test('$args is a usage error (exit 2)', () {
      final box = Sandbox();
      final result = box.run(
        'build_apk',
        args,
        box.env({'ANDROID_HOME': box.sdk}),
      );
      expect(result.exitCode, 2, reason: out(result));
      expect('${result.stderr}', contains('usage: '));
      expect(box.calls, isEmpty);
    });
  }

  test('a bad APSIRA_FLAVOURS is a usage error (exit 2)', () {
    final box = Sandbox();
    final result = box.run('build_apk', [
      '--dry-run',
    ], box.env({'APSIRA_FLAVOURS': 'dev'}));
    expect(result.exitCode, 2, reason: out(result));
    expect('${result.stderr}', contains('APSIRA_FLAVOURS'));
  });

  test('--help prints the settings and runs nothing', () {
    final box = Sandbox();
    final result = box.run('build_apk', ['--help'], box.env());
    expect(result.exitCode, 0, reason: out(result));
    for (final name in [
      'APSIRA_FLAVOURS',
      'APSIRA_MANIFEST_CHECK',
      'APSIRA_APK_CHECKS',
      '--dry-run',
    ]) {
      expect('${result.stdout}', contains(name));
    }
    expect(box.calls, isEmpty);
  });
}

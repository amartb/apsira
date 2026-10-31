// lib/scripts/local_release.sh: the signed prod release on the operator's
// computer, driven by the app's APSIRA_* settings. It refuses in a session
// before anything is read (session_guard.sh, D-APK-011). With RELAY's,
// VIATICUM's (debug key, VIATICUM D-059) and LYCEUM's settings, `--dry-run`
// prints exactly the `flutter build`, manifest, `apksigner` and notes lines
// each app's tool/release/local_release.sh runs at its pinned commit, and a
// real run against stub tools runs exactly those, in that order.
// Tests run from the package root.
import 'dart:io';

import 'package:test/test.dart';

import 'app_settings.dart';
import 'sandbox.dart';

/// Values passed as passwords; no output may contain them.
const _storePassword = 'store-Pa55-not-a-real-secret';
const _keyPassword = 'key-Pa55-not-a-real-secret';

/// The app's signing values, with the keystore outside [box]'s repository.
Map<String, String> _keys(App app) {
  if (app.keyEnv.isEmpty) return const {};
  final dir = Directory.systemTemp.createTempSync('apsira_key_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final keystore = File('${dir.path}/release.jks')..writeAsStringSync('jks');
  final prefix = app.settings['APSIRA_KEY_PREFIX']!;
  return {
    '${prefix}_KEYSTORE_PATH': keystore.path,
    '${prefix}_KEYSTORE_PASSWORD': _storePassword,
    '${prefix}_KEY_ALIAS': prefix.toLowerCase(),
    '${prefix}_KEY_PASSWORD': _keyPassword,
  };
}

/// A sandbox tagged [releaseTag], with VIATICUM's check stub.
Sandbox _tagged() {
  final box = Sandbox()
    ..write(
      'tool/check.sh',
      'echo "bash tool/check.sh" >> "\$LOG"\necho "check: PASS"\n',
    );
  return box..tagged(releaseTag);
}

/// [app]'s environment for a real run in [box].
Map<String, String> _env(
  Sandbox box,
  App app, [
  Map<String, String> extra = const {},
]) => box.env({
  ...app.settings,
  ..._keys(app),
  'ANDROID_HOME': box.sdk,
  'STUB_DIGEST': lyceumDigest,
  ...extra,
});

List<String> _commands(ProcessResult result) => [
  for (final line in '${result.stdout}'.trim().split('\n'))
    if (!line.startsWith('local_release:')) line,
];

void main() {
  for (final app in apps) {
    group(app.name, () {
      test('--dry-run prints its release lines and reads nothing', () {
        final box = Sandbox();
        final result = box.run('local_release', [
          '--dry-run',
          releaseTag,
        ], box.env(app.settings));
        expect(result.exitCode, 0, reason: out(result));
        expect('${result.stdout}', startsWith('local_release: dry run'));
        expect(_commands(result), app.release);
        expect(box.calls, isEmpty);
        expect(Directory('${box.root}/build').existsSync(), isFalse);
      });

      test('a release runs exactly those lines and leaves the files', () {
        final box = _tagged();
        final result = box.run('local_release', [releaseTag], _env(box, app));
        expect(result.exitCode, 0, reason: out(result));
        final code = app == relay ? '1' : stubVersionCode;
        expect(box.calls, [
          for (final line in app.release)
            line
                .replaceAll('<versionCode>', code)
                .replaceAll('<ANDROID_HOME>', box.sdk)
                .replaceAll('<newest>', newestBuildTools),
        ]);
        for (final name in app.keyEnv) {
          expect(box.flutterEnv, contains(name), reason: 'Gradle reads $name');
        }
        final id = app.settings['APSIRA_APP_ID']!;
        final dist = '${box.root}/build/release/$releaseTag';
        expect(File('$dist/$id-2.0.2.apk').existsSync(), isTrue);
        expect(
          File('$dist/$id-2.0.2.apk.sha256').readAsStringSync(),
          matches(RegExp('^[0-9a-f]{64}  $id-2\\.0\\.2\\.apk\n\$')),
        );
        final notes = app == lyceum ? 'notes-2.0.2.md' : 'CHANGELOG-2.0.2.md';
        expect(File('$dist/$notes').existsSync(), isTrue);
        final stdout = '${result.stdout}';
        expect(
          stdout,
          contains(
            'gh release create $releaseTag --verify-tag --title "${app.settings['APSIRA_APP']} 2.0.2" --notes-file build/release/$releaseTag/$notes',
          ),
        );
        expect(
          stdout,
          contains('gh repo view --json visibility --jq .visibility'),
        );
        expect(out(result), isNot(contains(_storePassword)));
        expect(out(result), isNot(contains(_keyPassword)));
      });
    });
  }

  test("the README's wrappers carry these settings", () {
    final readme = File('README.md').readAsStringSync();
    for (final app in apps) {
      for (final MapEntry(:key, :value) in app.settings.entries) {
        final quoted = RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(value)
            ? value
            : "'$value'";
        expect(readme, contains('$key=$quoted'), reason: app.name);
      }
    }
  });

  group('refused in a session (exit 3) before anything is read', () {
    for (final marker in [
      'CLAUDECODE',
      'CLAUDE_CODE_SSE_PORT',
      'AI_AGENT',
      'CODESPACES',
      'CLOUD_SHELL',
      'ARMY_TREE',
      'ARMY_TASK',
    ]) {
      test(marker, () {
        final box = Sandbox();
        for (final args in [
          [releaseTag],
          ['--dry-run', releaseTag],
          ['--help'],
          ['--bogus'],
        ]) {
          final result = box.run('local_release', args, {
            ..._env(box, lyceum),
            marker: '1',
          });
          expect(result.exitCode, 3, reason: '$args: ${out(result)}');
          expect('${result.stderr}', contains('$marker set'));
          expect('${result.stderr}', contains('(D-APK-011, D-004)'));
          expect('${result.stdout}', isEmpty);
          expect(out(result), isNot(contains(_storePassword)));
        }
        expect(box.calls, isEmpty);
        expect(Directory('${box.root}/build').existsSync(), isFalse);
      });
    }

    test('HOME=/home/user', () {
      final box = Sandbox();
      final result = box.run(
        'local_release',
        [releaseTag],
        {..._env(box, viaticum), 'HOME': '/home/user'},
      );
      expect(result.exitCode, 3, reason: out(result));
      expect('${result.stderr}', contains('HOME is /home/user'));
      expect(box.calls, isEmpty);
    });

    test('without session_guard.sh beside it', () {
      final box = Sandbox();
      box.write(
        'alone/local_release.sh',
        File('$scriptsDir/local_release.sh').readAsStringSync(),
      );
      final result = Process.runSync(
        'bash',
        ['${box.root}/alone/local_release.sh', '--help'],
        environment: box.env(),
        includeParentEnvironment: false,
        workingDirectory: box.root,
      );
      expect(result.exitCode, 3, reason: out(result));
      expect('${result.stderr}', contains('session_guard.sh'));
    });
  });

  test('--help names the settings and runs nothing', () {
    final box = Sandbox();
    final result = box.run('local_release', ['--help'], box.env());
    expect(result.exitCode, 0, reason: out(result));
    for (final name in [
      'APSIRA_APP',
      'APSIRA_APP_ID',
      'APSIRA_SIGNING',
      'APSIRA_KEY_PREFIX',
      'APSIRA_KEY_FINGERPRINT',
      'APSIRA_FINGERPRINT_CHECK',
      'APSIRA_VERSION_CODE',
      'APSIRA_NOTES',
      '--dry-run',
    ]) {
      expect('${result.stdout}', contains(name));
    }
    expect(box.calls, isEmpty);
  });

  // What LYCEUM's own --help named (lyceum tool/release/local_release.sh @
  // 9f4ff27), from each app's settings: its signing values, its steps and
  // the publish command.
  final helpNames = {
    relay: [
      'RELAY_KEYSTORE_PATH',
      'RELAY_KEYSTORE_PASSWORD',
      'RELAY_KEY_ALIAS',
      'RELAY_KEY_PASSWORD',
      'dart run tool/release/verify_fingerprint.dart',
      'git rev-list --count HEAD',
      'gh release create',
    ],
    viaticum: [
      'the SDK debug key',
      'bash tool/check.sh',
      'dart run tool/release/version.dart',
      'gh release create',
    ],
    lyceum: [
      'LYCEUM_KEYSTORE_PATH',
      'LYCEUM_KEYSTORE_PASSWORD',
      'LYCEUM_KEY_ALIAS',
      'LYCEUM_KEY_PASSWORD',
      'tool/release/version.dart',
      '--dart-define=LYCEUM_VERSION=<x.y.z>',
      'apksigner verify --print-certs',
      lyceumDigest,
      'tool/release/changelog.dart',
      'gh release create',
      '--notes-file',
    ],
  };
  for (final MapEntry(key: app, value: names) in helpNames.entries) {
    test("--help names ${app.name}'s values and steps from its settings", () {
      final box = Sandbox();
      final result = box.run('local_release', [
        '--help',
      ], box.env(app.settings));
      expect(result.exitCode, 0, reason: out(result));
      for (final name in names) {
        expect('${result.stdout}', contains(name));
      }
      expect('${result.stderr}', isEmpty);
      expect(box.calls, isEmpty);
    });
  }

  test('--help with settings it would refuse still exits 0', () {
    final box = Sandbox();
    final result = box.run('local_release', [
      '--help',
    ], box.env({'APSIRA_APP': 'X', 'APSIRA_SIGNING': 'none'}));
    expect(result.exitCode, 0, reason: out(result));
  });

  group('usage and settings errors (exit 2)', () {
    final cases = <String, (List<String>, Map<String, String>)>{
      'no tag': ([], lyceum.settings),
      'a tag that is not v<x.y.z>': (['2.0.2'], lyceum.settings),
      'a leading zero': (['v2.01.0'], lyceum.settings),
      'two tags': ([releaseTag, 'v2.0.3'], lyceum.settings),
      'an unknown option': (['--bogus', releaseTag], lyceum.settings),
      'APSIRA_APP unset': (
        [releaseTag],
        {...lyceum.settings}..remove('APSIRA_APP'),
      ),
      'APSIRA_APP_ID unset': (
        [releaseTag],
        {...lyceum.settings}..remove('APSIRA_APP_ID'),
      ),
      'an unknown APSIRA_SIGNING': (
        [releaseTag],
        {...lyceum.settings, 'APSIRA_SIGNING': 'none'},
      ),
      'a release key without its prefix': (
        [releaseTag],
        {...lyceum.settings}..remove('APSIRA_KEY_PREFIX'),
      ),
      'a release key without a certificate check': (
        [releaseTag],
        {...lyceum.settings}..remove('APSIRA_KEY_FINGERPRINT'),
      ),
      'two certificate checks': (
        [releaseTag],
        {
          ...lyceum.settings,
          ...{'APSIRA_FINGERPRINT_CHECK': 'dart run x.dart'},
        },
      ),
      'an unknown APSIRA_VERSION_CODE': (
        [releaseTag],
        {...lyceum.settings, 'APSIRA_VERSION_CODE': 'date'},
      ),
      'an unknown APSIRA_NOTES': (
        [releaseTag],
        {...lyceum.settings, 'APSIRA_NOTES': 'none'},
      ),
      '--build-number without commit-count': (
        ['--build-number', '7', releaseTag],
        lyceum.settings,
      ),
      '--build-number that is not a number': (
        ['--build-number', 'x', releaseTag],
        relay.settings,
      ),
      '--issues with changelog notes': (
        ['--issues', 'f.json', releaseTag],
        lyceum.settings,
      ),
    };
    for (final MapEntry(key: name, value: (args, settings)) in cases.entries) {
      test(name, () {
        final box = Sandbox();
        final result = box.run('local_release', [
          '--dry-run',
          ...args,
        ], box.env(settings));
        expect(result.exitCode, 2, reason: out(result));
        expect(box.calls, isEmpty);
      });
    }
  });

  group('inputs and the checkout (exit 1, nothing built)', () {
    test('a missing signing value is named, never shown', () {
      final box = _tagged();
      final env = _env(box, lyceum)
        ..remove('LYCEUM_KEY_ALIAS')
        ..remove('LYCEUM_KEY_PASSWORD');
      final result = box.run('local_release', [releaseTag], env);
      expect(result.exitCode, 1, reason: out(result));
      expect(
        '${result.stderr}',
        contains('LYCEUM_KEY_ALIAS LYCEUM_KEY_PASSWORD'),
      );
      expect(out(result), isNot(contains(_storePassword)));
      expect(box.calls, isEmpty);
    });

    test('the debug key needs no signing value', () {
      final box = _tagged();
      final result = box.run('local_release', [
        releaseTag,
      ], _env(box, viaticum));
      expect(result.exitCode, 0, reason: out(result));
      expect(
        '${result.stdout}',
        contains("signed with this computer's SDK debug key"),
      );
      expect(box.calls.where((call) => call.contains('apksigner')), isEmpty);
    });

    test('ANDROID_HOME unset', () {
      final box = _tagged();
      final result = box.run('local_release', [
        releaseTag,
      ], _env(box, relay)..remove('ANDROID_HOME'));
      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('ANDROID_HOME is not set'));
      expect(box.calls, isEmpty);
    });

    test('a keystore inside the repository', () {
      final box = _tagged();
      box.write('keys/release.jks', 'jks');
      final result = box.run(
        'local_release',
        [releaseTag],
        _env(box, lyceum, {
          'LYCEUM_KEYSTORE_PATH': '${box.root}/keys/release.jks',
        }),
      );
      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('outside the repository'));
      expect(box.calls, isEmpty);
    });

    test('no such tag', () {
      final box = _tagged();
      final result = box.run('local_release', ['v2.0.3'], _env(box, relay));
      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('no tag v2.0.3'));
      expect(box.calls, isEmpty);
    });

    test('HEAD is not the tag', () {
      final box = _tagged();
      box
        ..write('later.txt', 'x')
        ..git(['add', 'later.txt'])
        ..git(['commit', '-q', '-m', 'later']);
      final result = box.run('local_release', [releaseTag], _env(box, relay));
      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('HEAD is not $releaseTag'));
    });

    test('tracked files changed', () {
      final box = _tagged();
      box.write('tool/check.sh', 'changed');
      final result = box.run('local_release', [
        releaseTag,
      ], _env(box, viaticum));
      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('tracked files have changes'));
    });

    test('signing material tracked', () {
      final box = Sandbox()..write('android/key.properties', 'storeFile=x');
      box.tagged(releaseTag);
      final result = box.run('local_release', [releaseTag], _env(box, lyceum));
      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('signing material is tracked'));
      expect(box.calls, isEmpty);
    });
  });

  group('the steps', () {
    test("RELAY's --build-number and --issues", () {
      final box = _tagged()..write('issues.json', '[]');
      final result = box.run('local_release', [
        '--build-number',
        '812',
        '--issues',
        'issues.json',
        releaseTag,
      ], _env(box, relay));
      expect(result.exitCode, 0, reason: out(result));
      expect(
        box.calls,
        contains(
          'flutter build apk --flavor prod --release --build-name 2.0.2 --build-number 812',
        ),
      );
      expect(
        box.calls,
        contains(
          'dart run tool/release/changelog.dart --tag $releaseTag --issues issues.json',
        ),
      );
      expect(box.calls.where((call) => call.startsWith('gh ')), isEmpty);
    });

    test('a release check without check: PASS stops before the build', () {
      final box = Sandbox()
        ..write('tool/check.sh', 'echo "check: FAIL (tests)"\n');
      box.tagged(releaseTag);
      final result = box.run('local_release', [
        releaseTag,
      ], _env(box, viaticum));
      expect(result.exitCode, 1, reason: out(result));
      expect('${result.stderr}', contains('check: PASS'));
      expect(box.calls.where((call) => call.startsWith('flutter')), isEmpty);
    });

    test('no CHANGELOG notes, no build, no release folder', () {
      final box = _tagged();
      final result = box.run(
        'local_release',
        [releaseTag],
        _env(box, lyceum, {
          'STUB_FAIL': 'dart run tool/release/changelog.dart',
        }),
      );
      expect(result.exitCode, 1, reason: out(result));
      expect('${result.stderr}', contains('no notes for 2.0.2'));
      expect(box.calls.where((call) => call.startsWith('flutter')), isEmpty);
      expect(
        Directory('${box.root}/build/release/$releaseTag').existsSync(),
        isFalse,
      );
    });

    test('notes keep their title on, without dart run lines', () {
      final box = _tagged();
      final result = box.run('local_release', [releaseTag], _env(box, lyceum));
      expect(result.exitCode, 0, reason: out(result));
      final notes = File('${box.root}/build/release/$releaseTag/notes-2.0.2.md')
          .readAsStringSync();
      expect(notes, startsWith('# LYCEUM 2.0.2\n'));
    });

    test('another certificate is refused', () {
      final box = _tagged();
      final result = box.run('local_release', [
        releaseTag,
      ], _env(box, lyceum, {'STUB_DIGEST': 'ab' * 32}));
      expect(result.exitCode, 1, reason: out(result));
      expect('${result.stderr}', contains("not LYCEUM's release certificate"));
      expect(
        File('${box.root}/build/release/$releaseTag/lyceum-2.0.2.apk')
            .existsSync(),
        isFalse,
      );
    });

    test('a failing manifest check stops the release', () {
      final box = _tagged();
      final result = box.run(
        'local_release',
        [releaseTag],
        _env(box, relay, {'STUB_FAIL': 'dart run tool/privacy/manifest_check'}),
      );
      expect(result.exitCode, 1, reason: out(result));
      expect(
        box.calls.last,
        startsWith('dart run tool/privacy/manifest_check'),
      );
    });
  });

  // --candidate (APSIRA D-035, apsira-side ruling R-4): release mode's steps
  // 1–11 under an -rc.<n> tag, the notes from CHANGELOG.md's Unreleased
  // section as a .notes.md sidecar, and never published.
  group('a candidate', () {
    for (final app in apps) {
      final id = app.settings['APSIRA_APP_ID']!;
      final name = '$id-$_candidateVersion.apk';
      final dist = 'build/release/$_candidate';

      test('${app.name}: --dry-run prints the steps and the sidecar', () {
        final box = Sandbox();
        final result = box.run('local_release', [
          '--dry-run',
          '--candidate',
          _candidate,
        ], _env(box, app));
        expect(result.exitCode, 0, reason: out(result));
        expect(
          '${result.stdout}',
          startsWith('local_release: dry run of the candidate $_candidate'),
        );
        expect(_commands(result), _candidateLines(app));
        expect('${result.stdout}', contains('$dist/$name.notes.md'));
        expect('${result.stdout}', contains('not published'));
        _neverPublished(result);
        _neverShown(result);
        expect(box.calls, isEmpty);
        expect(Directory('${box.root}/build').existsSync(), isFalse);
      });

      test(
        '${app.name}: a candidate runs those steps and leaves the files',
        () {
          final box = _candidateBox();
          final result = box.run('local_release', [
            '--candidate',
            _candidate,
          ], _env(box, app));
          expect(result.exitCode, 0, reason: out(result));
          final code = app == relay ? '1' : stubVersionCode;
          expect(box.calls, [
            for (final line in _candidateLines(app))
              line
                  .replaceAll('<versionCode>', code)
                  .replaceAll('<ANDROID_HOME>', box.sdk)
                  .replaceAll('<newest>', newestBuildTools),
          ]);
          for (final key in app.keyEnv) {
            expect(box.flutterEnv, contains(key), reason: 'Gradle reads $key');
          }
          final files = '${box.root}/$dist';
          expect(File('$files/$name').existsSync(), isTrue);
          expect(
            File('$files/$name.sha256').readAsStringSync(),
            matches(RegExp('^[0-9a-f]{64}  ${RegExp.escape(name)}\n\$')),
          );
          expect(
            File('$files/$name.notes.md').readAsStringSync(),
            startsWith('# ${app.settings['APSIRA_APP']} $_candidateVersion\n'),
          );
          expect('${result.stdout}', contains('$files:'));
          expect('${result.stdout}', contains('not published'));
          expect(
            [
              for (final file in Directory(files).listSync())
                if (!file.path.endsWith('/check.log'))
                  file.path.split('/').last,
            ]..sort(),
            [name, '$name.notes.md', '$name.sha256'],
          );
          _neverPublished(result);
          _neverShown(result);
        },
      );
    }

    final refused = <String, List<String>>{
      '-rc.0': ['--candidate', 'v1.2.3-rc.0'],
      'a missing -rc': ['--candidate', 'v1.2.3'],
      'a leading zero in -rc': ['--candidate', 'v1.2.3-rc.01'],
      '--candidate without its tag': ['--candidate'],
      '--candidate and a release tag': ['--candidate', _candidate, releaseTag],
      'a release tag with -rc': ['v1.2.3-rc.1'],
      '--issues with a candidate': [
        '--issues',
        'f.json',
        '--candidate',
        _candidate,
      ],
    };
    for (final MapEntry(key: what, value: args) in refused.entries) {
      test('$what is refused (exit 2)', () {
        final box = Sandbox();
        for (final dry in [true, false]) {
          final result = box.run('local_release', [
            if (dry) '--dry-run',
            ...args,
          ], _env(box, relay));
          expect(result.exitCode, 2, reason: '$dry: ${out(result)}');
          _neverShown(result);
        }
        expect(box.calls, isEmpty);
      });
    }

    test('HEAD is not the candidate tag (exit 1, nothing built)', () {
      final box = _candidateBox();
      box
        ..write('later.txt', 'x')
        ..git(['add', 'later.txt'])
        ..git(['commit', '-q', '-m', 'later']);
      final result = box.run('local_release', [
        '--candidate',
        _candidate,
      ], _env(box, lyceum));
      expect(result.exitCode, 1, reason: out(result));
      expect('${result.stderr}', contains('HEAD is not $_candidate'));
      expect(box.calls, isEmpty);
      _neverShown(result);
    });

    for (final (what, extra) in [
      (
        'no Unreleased section (exit 1)',
        {'STUB_FAIL': 'dart run tool/release/changelog.dart --unreleased'},
      ),
      ('a changelog.dart without --unreleased', {'STUB_NOTES_EXIT': '64'}),
    ]) {
      test('$what: no sidecar, the build goes on', () {
        final box = _candidateBox();
        final result = box.run('local_release', [
          '--candidate',
          _candidate,
        ], _env(box, lyceum, extra));
        expect(result.exitCode, 0, reason: out(result));
        expect('${result.stdout}', contains('no notes'));
        final files = '${box.root}/build/release/$_candidate';
        expect(
          File('$files/lyceum-$_candidateVersion.apk').existsSync(),
          isTrue,
        );
        expect(
          File('$files/lyceum-$_candidateVersion.apk.notes.md').existsSync(),
          isFalse,
        );
        expect('${result.stdout}', isNot(contains('.notes.md')));
        _neverShown(result);
      });
    }

    test('a missing signing value is named, never shown', () {
      final box = _candidateBox();
      final env = _env(box, lyceum)..remove('LYCEUM_KEY_ALIAS');
      final result = box.run('local_release', ['--candidate', _candidate], env);
      expect(result.exitCode, 1, reason: out(result));
      expect('${result.stderr}', contains('LYCEUM_KEY_ALIAS'));
      expect(box.calls, isEmpty);
      _neverShown(result);
    });

    test('--help names candidate mode', () {
      final box = Sandbox();
      final result = box.run('local_release', ['--help'], box.env());
      expect(result.exitCode, 0, reason: out(result));
      expect(
        '${result.stdout}',
        contains('--candidate v<major>.<minor>.<patch>-rc.<n>'),
      );
    });
  });
}

const _candidate = 'v1.2.3-rc.1';
const _candidateVersion = '1.2.3-rc.1';

/// A sandbox tagged [_candidate], with VIATICUM's check stub.
Sandbox _candidateBox() {
  final box = Sandbox()
    ..write(
      'tool/check.sh',
      'echo "bash tool/check.sh" >> "\$LOG"\necho "check: PASS"\n',
    );
  return box..tagged(_candidate);
}

/// [app]'s release lines as a candidate, derived from release mode's: the
/// same steps in the same order with the candidate's names, step 8's notes
/// from the Unreleased section (after step 7's versionCode), and nothing of
/// step 12 (the notes from the closed issues).
List<String> _candidateLines(App app) {
  final lines = [
    for (final line in app.release)
      if (!line.startsWith('gh api') && !line.contains('changelog.dart'))
        line
            .replaceAll(releaseTag, _candidate)
            .replaceAll('2.0.2', _candidateVersion),
  ];
  final notesAt = lines.indexWhere(
    (line) => !line.contains('tool/release/version.dart'),
  );
  return lines..insert(
    notesAt,
    'dart run tool/release/changelog.dart --unreleased $_candidate',
  );
}

/// No publish command, not even printed.
void _neverPublished(ProcessResult result) {
  for (final publish in ['gh release', 'gh api', 'git push', 'gh repo']) {
    expect(out(result), isNot(contains(publish)));
  }
}

/// No signing value in the output.
void _neverShown(ProcessResult result) {
  expect(out(result), isNot(contains(_storePassword)));
  expect(out(result), isNot(contains(_keyPassword)));
}

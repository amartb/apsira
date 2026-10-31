// The scratch tree the script tests run in, on LYCEUM's pattern
// (lyceum test/tool/build_scripts_test.dart @ 9f4ff27): an app root with
// stub `flutter`, `dart`, `gh`, `gradlew` and `apksigner`, each logging its
// call to calls.log, and a clean environment, so no session marker leaks in
// from the gate or lane that runs the tests. The stub `changelog.dart
// --unreleased` exits STUB_NOTES_EXIT when it is set. Tests run from the
// package root.
import 'dart:io';

import 'package:test/test.dart';

/// The package's scripts, from the package root.
const scriptsDir = 'lib/scripts';

/// The newest build-tools the stub SDK holds (an older one is beside it).
const newestBuildTools = '34.0.0';

/// The versionCode the stub `version.dart` prints for every tag.
const stubVersionCode = '10001';

/// A scratch app root with stub tools.
class Sandbox {
  Sandbox() {
    root = Directory.systemTemp
        .createTempSync('apsira_scripts_')
        .resolveSymbolicLinksSync();
    addTearDown(() => Directory(root).deleteSync(recursive: true));
    stub('bin/flutter', r'''
log "flutter $*"
env | cut -d = -f 1 | sort > "$(dirname "$LOG")/flutter.env"
mode=""; flavor=""
while [ $# -gt 0 ]; do
  case "$1" in
    --debug) mode=debug ;; --profile) mode=profile ;; --release) mode=release ;;
    --flavor) flavor="$2"; shift ;;
  esac
  shift
done
[ -n "$flavor" ] || exit 0
mkdir -p build/app/outputs/flutter-apk
printf 'apk %s %s' "$flavor" "$mode" > "build/app/outputs/flutter-apk/app-$flavor-$mode.apk"
''');
    stub('bin/dart', '''
log "dart \$*"
case "\$*" in
  *tool/release/version.dart*) echo "Resolving dependencies..."; echo $stubVersionCode ;;
  *changelog.dart\\ --tag*) echo "# notes from the issues" ;;
  *changelog.dart\\ --unreleased*)
    [ -z "\${STUB_NOTES_EXIT:-}" ] || exit "\$STUB_NOTES_EXIT"
    echo "Resolving dependencies..."; printf '# %s %s\\n\\n- unreleased\\n' "\${APSIRA_APP:-App}" "\${4#v}" ;;
  *changelog.dart*) echo "Resolving dependencies..."; printf '# %s %s\\n\\n- notes\\n' "\${APSIRA_APP:-App}" "\${3#v}" ;;
esac
''');
    stub('bin/gh', r'''
log "gh $*"
echo '[]'
''');
    stub('android/gradlew', r'''
log "(cd android && ./gradlew $*)"
mkdir -p ../build/app/intermediates/merged_manifests/prodRelease
''');
    stub('sdk/build-tools/$newestBuildTools/apksigner', r'''
log "$0 $*"
echo "Signer #1 certificate DN: CN=App"
echo "Signer #1 certificate SHA-256 digest: ${STUB_DIGEST:-}"
''');
    stub('sdk/build-tools/9.0.0/apksigner', r'log "old apksigner $*"');
  }

  late final String root;

  String get sdk => '$root/sdk';
  String get bin => '$root/bin';
  String get logFile => '$root/calls.log';

  /// The names of the variables `flutter` saw in its environment.
  List<String> get flutterEnv => File('$root/flutter.env').existsSync()
      ? File('$root/flutter.env').readAsLinesSync()
      : const <String>[];

  /// The commands the stubs saw, in order.
  List<String> get calls => File(logFile).existsSync()
      ? File(logFile).readAsLinesSync()
      : const <String>[];

  void write(String path, String content) => File('$root/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  /// A stub at [path] that logs through `log` and may fail: it exits 1
  /// when its logged line starts with STUB_FAIL.
  void stub(String path, String body) {
    write(path, '''
#!/usr/bin/env bash
log() {
  echo "\$1" >> "\$LOG"
  if [ -n "\${STUB_FAIL:-}" ] && [[ "\$1" == "\$STUB_FAIL"* ]]; then exit 1; fi
}
$body
''');
    Process.runSync('chmod', ['+x', '$root/$path']);
  }

  /// A clean environment: no parent variables, so no session marker leaks
  /// in unless a test adds one.
  Map<String, String> env([Map<String, String> extra = const {}]) => {
    'PATH': '$bin:/usr/bin:/bin',
    'HOME': root,
    'LOG': logFile,
    ...extra,
  };

  /// Runs `bash lib/scripts/<name>.sh <args>` from the sandbox root.
  ProcessResult run(String name, List<String> args, Map<String, String> env) {
    final script = File('$scriptsDir/$name.sh').absolute.path;
    return Process.runSync(
      'bash',
      [script, ...args],
      environment: env,
      includeParentEnvironment: false,
      workingDirectory: root,
    );
  }

  /// git in the sandbox, with a throwaway identity.
  void git(List<String> args) {
    final result = Process.runSync(
      'git',
      [
        '-c',
        'user.name=test',
        '-c',
        'user.email=test@example.invalid',
        '-c',
        'commit.gpgsign=false',
        '-c',
        'tag.gpgsign=false',
        ...args,
      ],
      workingDirectory: root,
      environment: {'HOME': root, 'PATH': '/usr/bin:/bin'},
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  /// Makes the root a git checkout whose HEAD is tagged [tag].
  void tagged(String tag) {
    write('.gitignore', 'build/\ncalls.log\nflutter.env\nbin/\nsdk/\n');
    git(['init', '-q', '-b', 'main']);
    git(['add', '-A']);
    git(['commit', '-q', '-m', 'release']);
    git(['tag', tag]);
  }
}

/// stdout and stderr, for failure messages.
String out(ProcessResult result) => '${result.stdout}${result.stderr}';

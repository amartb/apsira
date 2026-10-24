// Each app's APSIRA_* settings, as its wrappers set them (the README's
// "Scripts" section), and the lines its own scripts run at the pinned
// commits: RELAY 09b28810, VIATICUM 78d38e0, LYCEUM 9f4ff27 (D-APK-011).
// The build_apk and local_release tests assert the package's scripts print
// and run exactly these lines with these settings.

/// LYCEUM's release certificate SHA-256 (lyceum
/// tool/release/local_release.sh @ 9f4ff27), as apksigner prints it.
const lyceumDigest =
    '5782212c870dd120e1b480f434a39c06ec9b69171f6dbe920ba29afe5540fc6a';

/// One app: its settings and the commands its scripts run.
class App {
  const App({
    required this.name,
    required this.settings,
    required this.keyEnv,
    required this.buildApk,
    required this.release,
  });

  final String name;

  /// The wrapper's exports.
  final Map<String, String> settings;

  /// The signing values the operator sets (none for the debug key).
  final List<String> keyEnv;

  /// build_apk.sh's commands for a debug build, in order.
  final List<String> buildApk;

  /// local_release.sh's commands for [releaseTag], in order; `<versionCode>`,
  /// `<ANDROID_HOME>` and `<newest>` are what the dry run cannot know.
  final List<String> release;
}

const releaseTag = 'v2.0.2';
const _merged = 'build/app/intermediates/merged_manifests/prodRelease';
const _gradle = '(cd android && ./gradlew :app:processProdReleaseManifest)';
const _apk = 'build/app/outputs/flutter-apk/app-prod-release.apk';
const _apksigner = '<ANDROID_HOME>/build-tools/<newest>/apksigner';
const _issues =
    'gh api --paginate --slurp repos/{owner}/{repo}/issues?state=closed&per_page=100';

/// relay tool/build_apk.sh and tool/release/local_release.sh @ 09b28810.
const relay = App(
  name: 'RELAY',
  settings: {
    'APSIRA_APP': 'Relay',
    'APSIRA_APP_ID': 'relay',
    'APSIRA_GUARD_RECORD': 'D-090',
    'APSIRA_KEY_PREFIX': 'RELAY',
    'APSIRA_FINGERPRINT_CHECK': 'dart run tool/release/verify_fingerprint.dart',
    'APSIRA_MANIFEST_CHECK':
        'dart run tool/privacy/manifest_check.dart --manifest',
    'APSIRA_VERSION_CODE': 'commit-count',
    'APSIRA_NOTES': 'issues',
  },
  keyEnv: [
    'RELAY_KEYSTORE_PATH',
    'RELAY_KEYSTORE_PASSWORD',
    'RELAY_KEY_ALIAS',
    'RELAY_KEY_PASSWORD',
  ],
  buildApk: [
    'flutter build apk --flavor dev --debug',
    _gradle,
    'dart run tool/privacy/manifest_check.dart --manifest $_merged',
  ],
  release: [
    'flutter build apk --flavor prod --release --build-name 2.0.2 --build-number <versionCode>',
    'dart run tool/privacy/manifest_check.dart --manifest $_merged',
    'dart run tool/release/verify_fingerprint.dart $_apk --apksigner $_apksigner',
    _issues,
    'dart run tool/release/changelog.dart --tag $releaseTag --issues build/release/$releaseTag/closed-issues.json',
  ],
);

/// viaticum tool/build_apk.sh and tool/release/local_release.sh @ 78d38e0.
/// No release key: Gradle signs with the SDK's debug key (VIATICUM D-059).
const viaticum = App(
  name: 'VIATICUM',
  settings: {
    'APSIRA_APP': 'Viaticum',
    'APSIRA_APP_ID': 'viaticum',
    'APSIRA_GUARD_RECORD': 'docs/building.md §3',
    'APSIRA_SIGNING': 'debug-key',
    'APSIRA_SIGNING_DOC': 'docs/building.md §3',
    'APSIRA_MANIFEST_CHECK': 'dart run tool/privacy/manifest_check.dart',
    'APSIRA_APK_CHECKS': 'dart run tool/privacy/apk_plugins_check.dart',
    'APSIRA_VERSION_CODE': 'version-dart',
    'APSIRA_RELEASE_CHECK': 'bash tool/check.sh',
    'APSIRA_NOTES': 'issues',
  },
  keyEnv: [],
  buildApk: [
    'flutter build apk --flavor dev --debug',
    _gradle,
    'dart run tool/privacy/manifest_check.dart $_merged',
    'dart run tool/privacy/apk_plugins_check.dart build/app/outputs/flutter-apk/app-dev-debug.apk',
  ],
  release: [
    'dart run tool/release/version.dart $releaseTag',
    'bash tool/check.sh',
    'flutter build apk --flavor prod --release --build-name 2.0.2 --build-number <versionCode>',
    'dart run tool/privacy/manifest_check.dart $_merged',
    _issues,
    'dart run tool/release/changelog.dart --tag $releaseTag --issues build/release/$releaseTag/closed-issues.json',
  ],
);

/// lyceum tool/build_apk.sh and tool/release/local_release.sh @ 9f4ff27.
const lyceum = App(
  name: 'LYCEUM',
  settings: {
    'APSIRA_APP': 'LYCEUM',
    'APSIRA_APP_ID': 'lyceum',
    'APSIRA_GUARD_RECORD': 'D-004',
    'APSIRA_KEY_PREFIX': 'LYCEUM',
    'APSIRA_KEY_FINGERPRINT': lyceumDigest,
    'APSIRA_VERSION_CODE': 'version-dart',
    'APSIRA_VERSION_DEFINE': 'LYCEUM_VERSION',
    'APSIRA_NOTES': 'changelog',
  },
  keyEnv: [
    'LYCEUM_KEYSTORE_PATH',
    'LYCEUM_KEYSTORE_PASSWORD',
    'LYCEUM_KEY_ALIAS',
    'LYCEUM_KEY_PASSWORD',
  ],
  buildApk: [
    'flutter build apk --flavor dev --debug',
    _gradle,
    'dart run apsira_tools:manifest_check --manifest $_merged',
  ],
  release: [
    'dart run tool/release/version.dart $releaseTag',
    'dart run tool/release/changelog.dart $releaseTag',
    'flutter build apk --flavor prod --release --build-name 2.0.2 --build-number <versionCode> --dart-define=LYCEUM_VERSION=2.0.2',
    'dart run apsira_tools:manifest_check --manifest $_merged',
    '$_apksigner verify --print-certs $_apk',
  ],
);

const apps = [relay, viaticum, lyceum];

// The network-holding knob of manifest_check (v0.6, D-APK-024):
// `privacy.holds_network: true` admits INTERNET only when the declared list
// holds it with a reason; declared without one is `declared without a
// reason`, undeclared stays forbidden with a finding naming the knob. Without
// the key (the default, `false`) every existing finding is unchanged: the
// RELAY and VIATICUM rows below pin the exact text, so a default of `true`
// turns them red. `requestedPermissions` is the source-manifest view: the
// `uses-permission` elements a manifest asks for, not the ones it removes.
// Tests run from the package root.
import 'dart:io';

import 'package:apsira_tools/manifest_check.dart';
import 'package:test/test.dart';

const _internet = 'android.permission.INTERNET';
const _admitted =
    'forbidden permission: $_internet (holds_network admits it only when '
    'declared with its reason, D-APK-024)';

const _manifest =
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
    '<uses-permission android:name="android.permission.INTERNET"/>'
    '<uses-permission android:name="android.permission.CAMERA"/>'
    '</manifest>';

Future<(int, String)> _check(List<String> args) async {
  final out = StringBuffer();
  final code = await runManifestCheck(args, out: out);
  return (code, out.toString());
}

void main() {
  group('holds_network: true', () {
    test('INTERNET declared with a reason passes', () {
      final report = checkManifest(_manifest, {
        _internet: 'the hub client, to the paired hub only',
        'android.permission.CAMERA': 'pairing',
      }, holdsNetwork: true);
      expect(report.isClean, isTrue, reason: '$report');
      expect(report.forbidden, isEmpty);
    });

    test('INTERNET declared without a reason fails', () {
      final report = checkManifest(_manifest, {
        _internet: '',
        'android.permission.CAMERA': 'pairing',
      }, holdsNetwork: true);
      expect(report.findings, ['declared without a reason: $_internet']);
      expect(report.forbidden, isEmpty);
    });

    test('INTERNET undeclared stays forbidden, naming the knob', () {
      final report = checkManifest(_manifest, {
        'android.permission.CAMERA': 'pairing',
      }, holdsNetwork: true);
      expect(report.findings, [_admitted]);
      expect(report.forbidden, [_internet]);
    });

    test('a declared reason does not admit INTERNET without the knob', () {
      final report = checkManifest(_manifest, {
        _internet: 'the hub client',
        'android.permission.CAMERA': 'pairing',
      });
      expect(report.findings, ['forbidden permission: $_internet (D-041)']);
    });

    group('manifest_check reads the key', () {
      late Directory dir;
      setUp(() => dir = Directory.systemTemp.createTempSync('holds_network_'));
      tearDown(() => dir.deleteSync(recursive: true));

      String write(String name, String text) =>
          (File('${dir.path}/$name')..writeAsStringSync(text)).path;

      Future<(int, String)> run(String declared) => _check([
        '--config',
        write(
          'tools.yaml',
          'privacy:\n'
              '  holds_network: true\n'
              '  declared_permissions: ${write('declared.txt', declared)}\n'
              '  manifest: ${write('AndroidManifest.xml', _manifest)}\n',
        ),
      ]);

      test('declared with a reason: exit 0', () async {
        final (code, out) = await run(
          '$_internet: the hub client\nandroid.permission.CAMERA: pairing\n',
        );
        expect(code, 0, reason: out);
        expect(out, contains('INTERNET only as declared (holds_network)'));
      });

      test('declared without a reason: exit 1', () async {
        final (code, out) = await run(
          '$_internet\nandroid.permission.CAMERA: pairing\n',
        );
        expect(code, 1, reason: out);
        expect(
          out,
          contains('manifest: declared without a reason: $_internet'),
        );
      });

      test('undeclared: exit 1', () async {
        final (code, out) = await run('android.permission.CAMERA: pairing\n');
        expect(code, 1, reason: out);
        expect(out, contains('manifest: $_admitted\n'));
      });
    });
  });

  group('without the key, every existing finding is unchanged', () {
    test(
      'RELAY: INTERNET in the merged manifest is forbidden (D-041)',
      () async {
        final (code, out) = await _check([
          '--manifest',
          'test/fixtures/privacy/manifest_with_internet.xml',
        ]);
        expect(code, 1);
        expect(out.split('\n').where((l) => l.contains(_internet)).toList(), [
          'manifest: forbidden permission: $_internet (D-041)',
        ]);
      },
    );

    test('RELAY: the declared set is clean, with no INTERNET', () async {
      final (code, out) = await _check([
        '--manifest',
        'test/fixtures/privacy/manifest_declared.xml',
      ]);
      expect(code, 0, reason: out);
      expect(out, contains('declared, no $_internet)'));
    });

    test(
      'VIATICUM: the approved manifest is clean, with no INTERNET',
      () async {
        final (code, out) = await _check([
          '--config',
          'test/fixtures/viaticum/apsira_tools.yaml',
        ]);
        expect(code, 0, reason: out);
        expect(out, contains('declared, no $_internet); each in'));
      },
    );
  });

  group('requestedPermissions', () {
    test('excludes an element that removes its permission', () {
      const manifest =
          '<manifest xmlns:tools="http://schemas.android.com/tools">'
          '<uses-permission android:name="a.B"/>'
          '<uses-permission-sdk-23 android:name="a.D"/>'
          '<uses-permission android:name="a.C" tools:node="remove"/>'
          "<uses-permission tools:node='remove' android:name='a.E'/>"
          '<!-- <uses-permission android:name="a.F"/> -->'
          '</manifest>';
      expect(requestedPermissions(manifest), {'a.B', 'a.D'});
      expect(usesPermissions(manifest), {'a.B', 'a.C', 'a.D', 'a.E'});
    });

    test('a name both requested and removed stays requested', () {
      const manifest =
          '<manifest xmlns:tools="http://schemas.android.com/tools">'
          '<uses-permission android:name="a.B"/>'
          '<uses-permission android:name="a.B" tools:node="remove"/>'
          '</manifest>';
      expect(requestedPermissions(manifest), {'a.B'});
      expect(removedPermissions(manifest), {'a.B'});
    });
  });
}

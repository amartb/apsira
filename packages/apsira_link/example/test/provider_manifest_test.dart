import 'dart:io';

import 'package:apsira_link/requests.dart';
import 'package:flutter_test/flutter_test.dart';

// The example declares AppLinkProvider as every adopting app does (contract
// app-link.md §2, doc/provider.md): exported, authority
// `${applicationId}.apsira`, no permission attributes,
// grantUriPermissions="false"; no BACKUP_JOB, so the example is on its own
// schedule (§5.3).
final _manifest = File('android/app/src/main/AndroidManifest.xml')
    .readAsStringSync()
    .replaceAll(RegExp('<!--.*?-->', dotAll: true), '');

final _providers = RegExp(
  r'<provider\b[^>]*>',
  dotAll: true,
).allMatches(_manifest).map((m) => m.group(0)!).toList();

String? _attribute(String element, String name) =>
    RegExp('android:$name="([^"]*)"').firstMatch(element)?.group(1);

void main() {
  test('one provider, AppLinkProvider', () {
    expect(_providers, hasLength(1));
    expect(_attribute(_providers.single, 'name'), AppLinkNames.providerClass);
  });

  test(r'its authority is ${applicationId}.apsira', () {
    expect(
      _attribute(_providers.single, 'authorities'),
      '\${applicationId}${AppLinkNames.authoritySuffix}',
    );
  });

  test('exported, no URI grants', () {
    expect(_attribute(_providers.single, 'exported'), 'true');
    expect(_attribute(_providers.single, 'grantUriPermissions'), 'false');
  });

  test('no permission attributes: trust is the check on every call', () {
    for (final name in ['permission', 'readPermission', 'writePermission']) {
      expect(_attribute(_providers.single, name), isNull, reason: name);
    }
  });

  test('no BACKUP_JOB: the example backs up on its own schedule', () {
    expect(_manifest.contains(AppLinkNames.backupJobMetaData), isFalse);
  });
}

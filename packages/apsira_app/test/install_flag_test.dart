// From viaticum test/app/services/first_open_service_test.dart @ 78d38e0
// (the file cases), generalised to any per-install flag (D-APK-010 C1).
import 'dart:io';

import 'package:apsira_app/apsira_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory app;
  late InstallFlag flag;
  const path = 'first_open/done.json';

  setUp(() {
    app = Directory.systemTemp.createTempSync('apsira_install_flag_');
    flag = InstallFlag(directory: () async => app, path: path);
  });
  tearDown(() => app.deleteSync(recursive: true));

  File file() => File('${app.path}/$path');

  test('a fresh install has no flag', () async {
    expect(await flag.isSet(), isFalse);
    expect(file().existsSync(), isFalse);
  });

  test('set writes {"done":true} through a .tmp renamed into place', () async {
    await flag.set();

    expect(file().readAsStringSync(), '{"done":true}');
    expect(File('${file().path}.tmp').existsSync(), isFalse);
    expect(await flag.isSet(), isTrue);
    expect(
      await InstallFlag(directory: () async => app, path: path).isSet(),
      isTrue,
      reason: 'a later launch reads the same file',
    );
  });

  test('an existing flag is kept byte-for-byte', () async {
    file()
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"done":true,"at":"an older shape"}');
    final bytes = file().readAsBytesSync();
    final modified = file().lastModifiedSync();

    await flag.set();

    expect(file().readAsBytesSync(), bytes);
    expect(file().lastModifiedSync(), modified);
    expect(File('${file().path}.tmp').existsSync(), isFalse);
  });

  test('a leftover .tmp without the flag reads as unset, and set replaces '
      'it', () async {
    File('${file().path}.tmp')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"do');

    expect(await flag.isSet(), isFalse);

    await flag.set();
    expect(file().readAsStringSync(), '{"done":true}');
    expect(File('${file().path}.tmp').existsSync(), isFalse);
  });

  test('the path is used verbatim: VIATICUM\'s first_open/done.json is '
      'honoured', () async {
    // An install whose first open ran under VIATICUM's FirstOpenService.
    File('${app.path}/first_open/done.json')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"done":true}');

    expect(await flag.isSet(), isTrue);
    expect(flag.path, 'first_open/done.json');
    final other = InstallFlag(directory: () async => app, path: 'tours.json');
    expect(await other.isSet(), isFalse);
    await other.set();
    expect(File('${app.path}/tours.json').existsSync(), isTrue);
  });

  test('a reinstall (app storage cleared) reads as unset', () async {
    await flag.set();
    app.deleteSync(recursive: true);
    app.createSync();

    expect(await flag.isSet(), isFalse);
  });
}

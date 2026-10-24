// AC-12.3: tips and tours seen are per-install InstallFlag files (D-APK-010
// C1, D-APK-017): a stray .tmp reads unseen, markSeen writes a .tmp and
// renames it, and an app's own layout (pathOf) is honoured.
import 'dart:io';

import 'package:apsira_onboarding/apsira_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory app;

  setUp(() => app = Directory.systemTemp.createTempSync('apsira_seen_'));
  tearDown(() => app.deleteSync(recursive: true));

  File at(String path) => File('${app.path}/$path');

  test('nothing is seen on a fresh install', () async {
    final seen = SeenFlags(app);
    expect(await seen.isSeen('quick_add'), isFalse);
    expect(at('seen').existsSync(), isFalse);
  });

  test('markSeen writes seen/<id>.json; it reads seen from then on', () async {
    await SeenFlags(app).markSeen('quick_add');

    expect(at('seen/quick_add.json').readAsStringSync(), '{"done":true}');
    expect(await SeenFlags(app).isSeen('quick_add'), isTrue);
    expect(await SeenFlags(app).isSeen('task_note'), isFalse);
  });

  test('a stray .tmp (a crash mid-write) reads unseen', () async {
    Directory('${app.path}/seen').createSync();
    at('seen/quick_add.json.tmp').writeAsStringSync('{"do');

    expect(await SeenFlags(app).isSeen('quick_add'), isFalse);
  });

  test('markSeen writes a .tmp and renames it into place', () async {
    final files = <String>[];
    await IOOverrides.runZoned(
      () async {
        await SeenFlags(app).markSeen('tour_basic');
      },
      createFile: (path) {
        files.add(path);
        return _realFile(path);
      },
    );

    final target = at('seen/tour_basic.json').path;
    expect(files, contains('$target.tmp'), reason: 'written to a .tmp first');
    expect(File('$target.tmp').existsSync(), isFalse, reason: 'renamed');
    expect(File(target).readAsStringSync(), '{"done":true}');
  });

  test('markSeen over a stray .tmp leaves a whole flag', () async {
    Directory('${app.path}/seen').createSync();
    at('seen/quick_add.json.tmp').writeAsStringSync('{"do');

    await SeenFlags(app).markSeen('quick_add');

    expect(at('seen/quick_add.json').readAsStringSync(), '{"done":true}');
    expect(at('seen/quick_add.json.tmp').existsSync(), isFalse);
  });

  test("a custom pathOf is honoured (the app's own layout)", () async {
    final seen = SeenFlags(app, pathOf: (id) => 'tips/$id.flag');

    await seen.markSeen('quick_add');

    expect(at('tips/quick_add.flag').existsSync(), isTrue);
    expect(at('seen').existsSync(), isFalse);
    expect(await seen.isSeen('quick_add'), isTrue);
    expect(await SeenFlags(app).isSeen('quick_add'), isFalse);
  });

  test('an id that is not a plain name is refused, never a path', () {
    final seen = SeenFlags(app);
    for (final id in ['', '../x', 'a/b', 'a b', '.']) {
      expect(() => seen.isSeen(id), throwsArgumentError, reason: id);
      expect(() => seen.markSeen(id), throwsArgumentError, reason: id);
    }
  });
}

/// A real file, made outside the [IOOverrides] zone's `createFile` (which
/// would otherwise call itself).
File _realFile(String path) =>
    IOOverrides.runWithIOOverrides(() => File(path), _Plain());

final class _Plain extends IOOverrides {}

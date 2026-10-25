// The per-install snooze store (D-APK-022, ruling R-4 Q2-b-install): one
// file beside the registry, written whole; active, clear and retain.
import 'dart:io';

import 'package:apsira_notify/apsira_notify.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime.utc(2026, 10, 24, 7);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('snooze_store_'));
  tearDown(() => dir.deleteSync(recursive: true));

  SnoozeStore store() => SnoozeStore(() async => dir);

  test('lives beside the registry, in the folder the backup rules exclude', () {
    expect(SnoozeStore.defaultPath, 'alarms/snoozes.json');
  });

  test('a snooze replaces the one before for its alarm and survives a new '
      'object; active is what is ahead', () async {
    await store().snooze('a', t0.add(const Duration(minutes: 10)));
    await store().snooze('a', t0.add(const Duration(minutes: 20)));
    await store().snooze(
      'b',
      t0.subtract(const Duration(minutes: 1)),
      content: const {'title': 'Again'},
    );
    final all = await store().all();
    expect(all.map((s) => s.alarmId), ['a', 'b']);
    expect(all.first.untilUtc, t0.add(const Duration(minutes: 20)));
    expect(all.last.content, {'title': 'Again'});
    expect((await store().active(t0)).map((s) => s.alarmId), ['a']);
  });

  test('clear drops one snooze; retain keeps the wanted ones ahead and '
      'writes only when one goes', () async {
    await store().snooze('a', t0.add(const Duration(minutes: 10)));
    await store().snooze('b', t0.add(const Duration(minutes: 10)));
    await store().snooze('c', t0.add(const Duration(minutes: 10)));
    await store().clear('b');
    await store().clear('zz');
    expect((await store().all()).map((s) => s.alarmId), ['a', 'c']);
    final steps = <String>[];
    final s = store()..afterStep = steps.add;
    expect((await s.retain({'a', 'c'}, now: t0)).map((x) => x.alarmId), [
      'a',
      'c',
    ]);
    expect(steps, isEmpty);
    expect((await s.retain({'a'}, now: t0)).map((x) => x.alarmId), ['a']);
    expect(steps, ['tmpWritten', 'renamed']);
    expect(
      await s.retain({'a'}, now: t0.add(const Duration(minutes: 10))),
      isEmpty,
    );
  });

  test('a local instant is refused before anything is written', () async {
    await expectLater(
      store().snooze('a', DateTime(2026, 10, 24, 9)),
      throwsArgumentError,
    );
    expect(File('${dir.path}/alarms/snoozes.json').existsSync(), isFalse);
  });
}

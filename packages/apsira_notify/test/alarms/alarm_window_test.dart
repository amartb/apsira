// From relay test/domain/reminders/window_test.dart @ 09b28810: the nearest
// 100 wanted alarms, ties by alarm id; the plan keeps the registry's entries
// in the window under their platform ids and cancels the rest. RELAY's FNV
// request codes are gone (the registry's ids), and every alarm in the window
// is armed again (D-APK-022).
import 'package:apsira_notify/apsira_notify.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int minute) => DateTime.utc(2026, 4, 1, 9, minute);

ScheduledAlarm _alarm(String id, int minute) =>
    ScheduledAlarm(alarmId: id, atUtc: _at(minute));

RegisteredAlarm _entry(String id, int minute, int platformId) =>
    RegisteredAlarm(alarmId: id, platformId: platformId, atUtc: _at(minute));

void main() {
  group('window', () {
    test('the nearest 100 by fire time, ties by alarm id', () {
      final wanted = [for (var i = 0; i < 130; i++) _alarm('r$i', i % 60)];
      final window = nearestFires(wanted);
      expect(window, hasLength(reminderWindowSize));
      expect(reminderWindowSize, 100);
      final sorted = [...wanted]
        ..sort((a, b) {
          final c = a.atUtc.compareTo(b.atUtc);
          return c != 0 ? c : a.alarmId.compareTo(b.alarmId);
        });
      expect(window, sorted.take(100).toList());
    });

    test('a past fire is the nearest of all', () {
      final window = nearestFires([
        _alarm('later', 30),
        ScheduledAlarm(
          alarmId: 'past',
          atUtc: _at(0).subtract(const Duration(hours: 1)),
        ),
      ], size: 1);
      expect(window.single.alarmId, 'past');
    });
  });

  group('plan', () {
    test('keeps what is registered in the window (moved ones too, under their '
        'id), cancels what left, arms the whole window', () {
      final plan = planAlarms(
        wanted: [_alarm('keep', 1), _alarm('moved', 5), _alarm('new', 3)],
        registered: [
          _entry('keep', 1, 1),
          _entry('moved', 2, 2),
          _entry('gone', 4, 3),
        ],
      );
      expect(plan.cancel.map((e) => e.alarmId), ['gone']);
      expect(plan.arm.map((a) => a.alarmId), ['keep', 'new', 'moved']);
    });

    test('a second plan over its own result cancels nothing and arms the '
        'same window again', () {
      final wanted = [for (var i = 0; i < 5; i++) _alarm('r$i', i)];
      final first = planAlarms(wanted: wanted, registered: const []);
      final registered = [
        for (final (i, a) in first.arm.indexed) _entry(a.alarmId, i, i + 1),
      ];
      final second = planAlarms(wanted: wanted, registered: registered);
      expect(second.cancel, isEmpty);
      expect(second.arm, first.arm);
    });

    test('an entry pushed out of the window is cancelled', () {
      final plan = planAlarms(
        wanted: [_alarm('near', 1), _alarm('far', 50)],
        registered: [_entry('far', 50, 1)],
        size: 1,
      );
      expect(plan.cancel.single.alarmId, 'far');
      expect(plan.arm.single.alarmId, 'near');
    });
  });
}

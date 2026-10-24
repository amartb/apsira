// From relay lib/core/ports/background_jobs.dart @ 09b28810: JobConstraints'
// fields, defaults and value semantics.
import 'package:apsira_jobs/apsira_jobs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the defaults require nothing (RELAY)', () {
    const c = JobConstraints();
    expect(c.batteryNotLow, isFalse);
    expect(c.storageNotLow, isFalse);
    expect(c.deviceIdle, isFalse);
  });

  test('is a value: equal fields, equal constraints and hash', () {
    const a = JobConstraints(batteryNotLow: true, deviceIdle: true);
    const b = JobConstraints(batteryNotLow: true, deviceIdle: true);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const JobConstraints(batteryNotLow: true)));
    expect(
      const JobConstraints(storageNotLow: true),
      isNot(const JobConstraints()),
    );
  });

  test('names every field in toString', () {
    expect(
      const JobConstraints(storageNotLow: true).toString(),
      'JobConstraints(batteryNotLow: false, storageNotLow: true, '
      'deviceIdle: false)',
    );
  });
}

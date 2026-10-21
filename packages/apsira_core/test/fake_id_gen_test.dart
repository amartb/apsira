import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/testing.dart';
import 'package:test/test.dart';

// The fake's UUIDs are deterministic so golden and service tests can name
// them: the n-th is `00000000-0000-7000-8000-<n in 12 hex digits>`.
void main() {
  test('the n-th uuid counts from 1', () {
    final IdGen ids = FakeIdGen();
    expect(ids.uuid(), '00000000-0000-7000-8000-000000000001');
    expect(ids.uuid(), '00000000-0000-7000-8000-000000000002');
  });

  test('counts in hex, one counter per fake', () {
    final ids = FakeIdGen();
    for (var i = 0; i < 9; i++) {
      ids.uuid();
    }
    expect(ids.uuid(), '00000000-0000-7000-8000-00000000000a');
    expect(FakeIdGen().uuid(), '00000000-0000-7000-8000-000000000001');
  });
}

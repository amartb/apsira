/// Test fakes for the `apsira_core` ports: a [FakeClock] that moves only
/// when told and a [FakeIdGen] with deterministic identifiers. For tests
/// only; app code takes the real implementations.
library;

export 'testing/fake_clock.dart';
export 'testing/fake_id_gen.dart';

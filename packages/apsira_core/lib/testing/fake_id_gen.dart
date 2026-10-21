// From relay test/fakes/fake_id_gen.dart @ 5f606e9
import '../src/id_gen.dart';

/// Deterministic identifiers for golden and service tests (architecture
/// §3.1): the n-th UUID is `00000000-0000-7000-8000-<n in 12 hex digits>`,
/// counting from 1.
final class FakeIdGen implements IdGen {
  int _uuids = 0;

  @override
  String uuid() {
    _uuids++;
    return '00000000-0000-7000-8000-${_uuids.toRadixString(16).padLeft(12, '0')}';
  }
}

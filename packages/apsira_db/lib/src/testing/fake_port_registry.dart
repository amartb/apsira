// From relay test/data/db/fake_port_registry.dart @ 09b28810.
import 'dart:isolate';

import '../server.dart';

/// The host's stand-in for `IsolateNameServer`, with its rules: a name holds
/// one port, and registering a taken name fails until the mapping is
/// removed. A test that crosses isolates passes the mappings it needs to the
/// other side ([FakePortRegistry.new]).
final class FakePortRegistry implements PortRegistry {
  FakePortRegistry([Map<String, SendPort>? mappings])
    : mappings = {...?mappings};

  final Map<String, SendPort> mappings;

  @override
  SendPort? lookup(String name) => mappings[name];

  @override
  bool register(SendPort port, String name) {
    if (mappings.containsKey(name)) return false;
    mappings[name] = port;
    return true;
  }

  @override
  bool remove(String name) => mappings.remove(name) != null;
}

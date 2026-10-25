// The libraries a plain Dart program reaches from one library: its imports
// and exports followed through every package library, each printed as
// `reaches <uri>`, for envelope_library_test.dart. A `dart:` library is
// listed but not followed: the SDK's own libraries reach one another inside
// the VM (dart:math → dart:_internal → dart:async → dart:developer →
// dart:io), which no package imports. Mirrors run in the VM's JIT, which
// `dart` starts for a program given as source.
// A program's output, kept free of dart:io: print is dart:core's.
// ignore_for_file: avoid_print

import 'dart:mirrors';

void printReach(String library) {
  final root = currentMirrorSystem().libraries[Uri.parse(library)]!;
  final seen = <Uri>{};
  final pending = [root];
  while (pending.isNotEmpty) {
    final next = pending.removeLast();
    if (!seen.add(next.uri) || next.uri.isScheme('dart')) continue;
    for (final dependency in next.libraryDependencies) {
      final target = dependency.targetLibrary;
      if (target != null) pending.add(target);
    }
  }
  for (final uri in seen.map((u) => '$u').toList()..sort()) {
    print('reaches $uri');
  }
}

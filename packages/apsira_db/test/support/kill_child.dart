// The hard-kill child (crash-matrix families "hard kill", KP-R11 and KP-S4):
// a plain Dart process that runs a restore swap or a snapshot over the
// files in a directory and, after the step it is given, writes
// `at <step>` to its stdout, synchronously, so the parent can SIGKILL it
// there. Nothing it held in memory survives: the parent's next open sees
// only the files. It imports no Flutter library (AC-13.5).
//
//   dart run test/support/kill_child.dart swap <dir> <step>
//   dart run test/support/kill_child.dart snapshot <dir> <target> <step>
//
// `swap` stops at its step and waits to be killed; `snapshot` signals and
// goes on, so the kill lands inside the `VACUUM INTO` that follows.
import 'dart:io';

import 'package:apsira_db/src/layout.dart';
import 'package:apsira_db/src/snapshot.dart';
import 'package:apsira_db/src/swap.dart';
import 'package:drift/native.dart';

import 'fixture_database.dart';

Future<void> main(List<String> args) async {
  switch (args) {
    case ['swap', final dir, final step]:
      final files = DatabaseFiles(Directory(dir), name: 'fixture');
      void at(Object s) {
        if ((s as Enum).name != step) return;
        _signal(step);
        // Killed here.
        sleep(const Duration(minutes: 5));
      }

      beginRestore(files, onStep: at);
      await writeSafetyCopy(files, onStep: at);
      armRestore(files, onStep: at);
      await swapIn(files, onStep: at);
      finishRestore(files, onStep: at);
    case ['snapshot', final dir, final target, final step]:
      final db = FixtureDatabase(NativeDatabase(File('$dir/fixture.db')));
      await snapshot(
        db,
        target,
        onStep: (s) {
          if ((s as Enum).name == step) _signal(step);
        },
      );
      await db.close();
    default:
      stderr.writeln('usage: kill_child.dart swap|snapshot …');
      exitCode = 64;
  }
}

/// `at <step>` on stdout, written by a `write(2)` before the call returns:
/// Dart's `stdout` is flushed by the event loop, which a running
/// `VACUUM INTO` blocks. (No fsync: a pipe has none.)
void _signal(String step) =>
    File('/proc/self/fd/1').writeAsStringSync('at $step\n');

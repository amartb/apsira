// The crash matrices' hard kill (task-specs T13, "How a kill is simulated"):
// a plain Dart child SIGKILLed at a named step. New in D-APK-018.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'checks.dart';

/// Runs `dart run <script> <args>` and SIGKILLs it as soon as it writes the
/// line `at <step>` to its stdout, then waits for it to exit: whatever it
/// held in memory is gone, and only its files remain for the next open.
///
/// The child must write that line synchronously (an `IOSink` is flushed by
/// the event loop, which a long SQLite call blocks) and must import no
/// Flutter library. [dartExecutable] defaults to the Flutter SDK's `dart`
/// (`$FLUTTER_ROOT/bin/dart`, which `flutter test` sets), else `dart` on the
/// path. With [killWhen], the kill waits after the line until it holds
/// (polled every millisecond): a file the next step creates, say, so the
/// kill lands inside that step. Throws [DatabaseCheckFailed] when the child
/// exits, or [timeout] passes, before it reaches [step].
Future<void> hardKill(
  String step, {
  required String script,
  List<String> args = const [],
  String? workingDirectory,
  String? dartExecutable,
  bool Function()? killWhen,
  Duration timeout = const Duration(minutes: 2),
}) async {
  final child = await Process.start(dartExecutable ?? _dart(), [
    'run',
    script,
    ...args,
  ], workingDirectory: workingDirectory);
  final errors = StringBuffer();
  var reached = false;
  var killed = false;
  Timer? poll;
  void kill() {
    killed = child.kill(ProcessSignal.sigkill);
  }

  final err = child.stderr.transform(utf8.decoder).listen(errors.write);
  final out = child.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (line != 'at $step' || reached) return;
        reached = true;
        if (killWhen == null) return kill();
        poll = Timer.periodic(const Duration(milliseconds: 1), (timer) {
          if (!killWhen()) return;
          timer.cancel();
          kill();
        });
      });
  final code = await child.exitCode.timeout(
    timeout,
    onTimeout: () {
      child.kill(ProcessSignal.sigkill);
      return child.exitCode;
    },
  );
  poll?.cancel();
  await out.cancel();
  await err.cancel();
  if (!reached) {
    throw DatabaseCheckFailed(
      'the child never reached $step (exit $code): $errors',
    );
  }
  if (!killed) {
    throw DatabaseCheckFailed(
      'the child ended before the kill (exit $code): $errors',
    );
  }
}

String _dart() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && File('$root/bin/dart').existsSync()) {
    return '$root/bin/dart';
  }
  final self = Platform.resolvedExecutable;
  return self.endsWith('/dart') ? self : 'dart';
}

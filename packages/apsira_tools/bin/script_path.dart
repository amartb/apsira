// `dart run apsira_tools:script_path <name>`: the absolute path of
// lib/scripts/<name>.sh in the apsira_tools package the app resolved, so an
// app's wrapper runs the package's script (`exec bash "$path" "$@"`) from
// the git dependency in its lock. Exit 0 with the path on stdout; 2 for no
// name, more than one, or a name that is not one of the package's scripts
// (a name starting with `_` is a sourced helper, never run).
// test/scripts/script_path_test.dart pins this.
import 'dart:io';
import 'dart:isolate';

const _usage =
    'usage: dart run apsira_tools:script_path <name>\n'
    'Prints the absolute path of lib/scripts/<name>.sh in apsira_tools.';

Future<void> main(List<String> args) async {
  exitCode = await _scriptPath(args);
}

Future<int> _scriptPath(List<String> args) async {
  final scripts = await Isolate.resolvePackageUri(
    Uri.parse('package:apsira_tools/scripts/'),
  );
  final names = scripts == null
      ? <String>[]
      : _names(Directory.fromUri(scripts));
  if (args.length != 1 || !names.contains(args.single)) {
    final known = names.isEmpty ? 'none found' : names.join(', ');
    stderr.writeln('$_usage\nScripts: $known.');
    if (args.length == 1) stderr.writeln('Unknown script: ${args.single}');
    return 2;
  }
  stdout.writeln(File.fromUri(scripts!.resolve('${args.single}.sh')).path);
  return 0;
}

/// The scripts in [dir], by name: `<name>.sh` files whose name is lower-case
/// words joined by `_` and does not start with `_`.
List<String> _names(Directory dir) {
  if (!dir.existsSync()) return const [];
  final name = RegExp(r'^([a-z][a-z0-9_]*)\.sh$');
  return [
    for (final entity in dir.listSync())
      if (entity is File)
        ?name.firstMatch(entity.uri.pathSegments.last)?.group(1),
  ]..sort();
}

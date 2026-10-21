// Time and IDs taken directly instead of from Clock and IdGen. Uuid is not
// imported: the import alone would break domain-imports.
import 'dart:math';

// DateTime.now() in a comment is not a call.
const label = 'Random() in a string is not a call';

String newId() {
  final now = DateTime.now();
  final salt = Random().nextInt(1 << 16);
  final id = Uuid().v7();
  return '$now $salt $id '
      '${DateTime.now().millisecondsSinceEpoch}';
}

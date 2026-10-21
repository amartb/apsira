// A fixture for the l10n source scan (07 P0-07): `hardCoded` passes a string
// literal to `Text(`, which the scan must report, once. The comment,
// `localised` and `number` must not be reported.
import 'package:flutter/widgets.dart';

class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.count});

  final int count;

  // Text('in a comment')
  Widget localised(String title) => Text(title);
  Widget number() => Text('$count');
  Widget hardCoded() => const Text('Untitled note');

  @override
  Widget build(BuildContext context) => hardCoded();
}

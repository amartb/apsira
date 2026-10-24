// text_calls: a literal to each of the three calls.
Widget card() => Column(
  children: [
    Text('Plain'),
    SelectableText('Trip'),
    Text.rich(TextSpan(text: 'Day', style: bold)),
  ],
);

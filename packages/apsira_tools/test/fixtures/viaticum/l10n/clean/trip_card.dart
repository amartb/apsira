// text_calls: every scanned call is given a localised string.
Widget card(AppLocalizations l10n) => Column(
  children: [
    Text(l10n.tripTitle),
    SelectableText(l10n.tripTitle),
    Text.rich(TextSpan(text: l10n.tripTitle)),
  ],
);

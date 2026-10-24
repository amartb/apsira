// From relay lib/app/theme/discovery.dart @ 09b28810, with ChoicePill
// (lib/app/theme/condition_sheet.dart @ 09b28810) as the chips' own pill
// and Got it from apsira_l10n (D-APK-017).

/// Discoverability's shared pieces: what lets a power syntax or a quick
/// add show itself, and the one-time tips.
///
/// - [HintRotation]: an empty field's hint steps through its examples every
///   [hintRotationPeriod] (Search, the view builder, quick add), still
///   while the field holds text or the screen is covered.
/// - [SuggestionChipRow] and [insertToken]: chips that put a token at the
///   caret, spaced from the words around it; a key (`type:`) or a mark
///   (`@`, `#`) keeps the caret on it so its values follow.
/// - [OneTimeTipCard]: a bordered card (D-066) with one line and its Got it
///   button, read by TalkBack, wrapping whole at large text.
///
/// Plain values only: the app words the hints, the chips and the tips in
/// the UI language and decides when a tip shows ([SeenFlags]).
library;

import 'dart:async';

import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

import 'seen_flags.dart' show SeenFlags;

/// How long each of an empty field's hints shows.
const hintRotationPeriod = Duration(seconds: 4);

/// Builds with one of [hints] at a time, the next every
/// [hintRotationPeriod] while [active] (the field is empty) and the screen
/// is shown; the first one first.
class HintRotation extends StatefulWidget {
  const HintRotation({
    super.key,
    required this.hints,
    required this.active,
    required this.builder,
  });

  final List<String> hints;
  final bool active;

  /// The field, with the hint to show (null when there is none).
  final Widget Function(BuildContext context, String? hint) builder;

  @override
  State<HintRotation> createState() => _HintRotationState();
}

class _HintRotationState extends State<HintRotation> {
  Timer? _timer;
  var _index = 0;
  var _shown = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(HintRotation old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    if (widget.active && _shown && widget.hints.length > 1) {
      _timer ??= Timer.periodic(hintRotationPeriod, (_) {
        if (mounted) setState(() => _index++);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hints = widget.hints;
    return widget.builder(
      context,
      hints.isEmpty ? null : hints[_index % hints.length],
    );
  }
}

/// Puts [token] at [controller]'s caret (in place of a selection; at the
/// end when there is no caret), with a space before it after a word, and a
/// space after it unless it waits for its value: a key (`type:`) or a mark
/// (`@`, `#`). The caret goes after what was put in.
void insertToken(TextEditingController controller, String token) {
  final text = controller.text;
  final selection = controller.selection;
  final start = selection.isValid
      ? selection.start.clamp(0, text.length)
      : text.length;
  final end = selection.isValid
      ? selection.end.clamp(start, text.length)
      : text.length;
  final before = text.substring(0, start);
  var after = text.substring(end);
  final lead = before.isEmpty || before.endsWith(' ') ? '' : ' ';
  final waits = token.endsWith(':') || token == '@' || token == '#';
  final put = [lead, token, if (!waits) ' '].join();
  if (!waits && after.startsWith(' ')) after = after.substring(1);
  controller.value = TextEditingValue(
    text: [before, put, after].join(),
    selection: TextSelection.collapsed(offset: start + put.length),
  );
}

/// A suggestion chip: what it shows and the token it puts in.
@immutable
class SuggestionChip {
  const SuggestionChip({required this.label, required this.token});

  final String label;
  final String token;
}

/// A row of [chips] that wraps; a tap hands the chip's token to
/// [onChosen]. TalkBack reads [label] for the row, then each chip as a
/// button. A tap on a chip is not a tap outside the field it serves.
class SuggestionChipRow extends StatelessWidget {
  const SuggestionChipRow({
    super.key,
    required this.label,
    required this.chips,
    required this.onChosen,
  });

  final String label;
  final List<SuggestionChip> chips;
  final ValueChanged<String> onChosen;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: label,
    child: TextFieldTapRegion(
      child: Wrap(
        spacing: ApsiraSpacing.betweenPills,
        children: [
          for (final chip in chips)
            IntrinsicWidth(
              child: _ChipPill(
                label: chip.label,
                onTap: () => onChosen(chip.token),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A one-time tip: [text] beside a bulb ([icon]), and [dismissLabel] (Got
/// it, `tipGotIt` by default), which calls [onDismiss]. Keyed by [id]
/// ([keyOf], [dismissKeyOf]). At large text the button goes under the line.
class OneTimeTipCard extends StatelessWidget {
  const OneTimeTipCard({
    super.key,
    required this.id,
    required this.text,
    required this.onDismiss,
    this.dismissLabel,
    this.icon = Icons.lightbulb_outline,
  });

  static Key keyOf(String id) => Key('tip/$id');
  static Key dismissKeyOf(String id) => Key('tip/$id/dismiss');

  /// The text scale from which the button goes under the line.
  static const stackScale = 1.5;

  final String id;
  final String text;
  final VoidCallback onDismiss;

  /// The button's word; `tipGotIt` when null.
  final String? dismissLabel;

  /// The tip's glyph (RELAY passes its Lucide bulb).
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(10) / 10 >= stackScale;
    final line = Text(
      text,
      style: ApsiraTypography.snippet.copyWith(color: t.ink2),
    );
    final button = TextButton(
      key: dismissKeyOf(id),
      onPressed: onDismiss,
      child: Text(
        dismissLabel ?? ApsiraL10n.of(context).tipGotIt,
        style: ApsiraTypography.pill.copyWith(color: t.accentText),
      ),
    );
    return KeyedSubtree(
      key: keyOf(id),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.tint,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(ApsiraRadii.insetBlock),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ApsiraSpacing.grid * 3,
              ApsiraSpacing.grid,
              ApsiraSpacing.grid,
              ApsiraSpacing.grid,
            ),
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(icon, size: 18, color: t.ink2)),
                const SizedBox(width: ApsiraSpacing.grid * 2),
                Expanded(
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: ApsiraSpacing.grid),
                            line,
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: button,
                            ),
                          ],
                        )
                      : line,
                ),
                if (!stacked) button,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A suggestion chip's pill (RELAY's `ChoicePill`, never selected): a
/// `surface` stadium with its `border`, at least 48 dp tall to the touch,
/// read as a button.
class _ChipPill extends StatelessWidget {
  const _ChipPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        height: kMinInteractiveDimension,
        child: Center(
          child: Material(
            color: t.surface,
            shape: StadiumBorder(side: BorderSide(color: t.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: kMinInteractiveDimension,
                  minHeight: ApsiraSizes.pillMaxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ApsiraSpacing.grid * 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: ApsiraTypography.pill.copyWith(color: t.ink2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

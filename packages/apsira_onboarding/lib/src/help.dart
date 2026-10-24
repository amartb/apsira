// From relay lib/features/help/ui/help_screen.dart, how_to_page.dart and
// tour_screen.dart @ 09b28810, with viaticum
// lib/features/help/ui/help_screen.dart @ 78d38e0's one-button rows and
// tour_screen.dart's empty tour (D-APK-017). The tours, the how-tos and
// their words stay in each app.

/// The Help shell: the page of groups of rows, a tour on its own screen and
/// a how-to page of numbered steps and worked examples. Help holds no data
/// and writes nothing; the app's router opens a tour (`/help/tour/<id>`,
/// [helpTourPath]) or a how-to (`/help/howto/<id>`, [helpHowToPath]).
library;

import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

import 'tour_player.dart';
import 'tour_step.dart';

/// The route of tour [id].
String helpTourPath(String id) => '/help/tour/$id';

/// The route of how-to [id].
String helpHowToPath(String id) => '/help/howto/$id';

/// The keys of Help's rows.
abstract final class HelpKeys {
  /// The row that opens tour [id].
  static Key tour(String id) => Key('help/tour/$id');

  /// The row that opens how-to [id].
  static Key howTo(String id) => Key('help/howto/$id');
}

/// Help: its [groups] of rows, one under the other, under [title] (`Help`
/// by default).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.groups, this.title});

  final List<HelpGroup> groups;

  /// The app bar's title; `helpTitle` when null.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return Scaffold(
      backgroundColor: t.ground,
      appBar: helpAppBar(context, title ?? ApsiraL10n.of(context).helpTitle),
      body: ListView(
        padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
        children: [
          for (final (i, group) in groups.indexed) ...[
            if (i > 0) const SizedBox(height: ApsiraSpacing.betweenSections),
            group,
          ],
        ],
      ),
    );
  }
}

/// Help's app bar: [title] on the ground, as Settings draws its own; none
/// where the page heads itself (a how-to).
PreferredSizeWidget helpAppBar(BuildContext context, String? title) {
  final t = ApsiraTheme.of(context);
  return AppBar(
    backgroundColor: t.ground,
    foregroundColor: t.ink,
    surfaceTintColor: t.ground,
    scrolledUnderElevation: 0,
    title: title == null
        ? null
        : Text(title, style: ApsiraTypography.h2.copyWith(color: t.ink)),
  );
}

/// A group: an optional [title] (a header) above a bordered card of
/// [children] on `surface`, divided by `border` lines.
class HelpGroup extends StatelessWidget {
  const HelpGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final shape = ApsiraShapes.rounded(ApsiraRadii.groupCard)
        .copyWith(side: BorderSide(color: t.border));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ApsiraSpacing.cardSide,
              0,
              ApsiraSpacing.cardSide,
              ApsiraSpacing.grid * 2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: ApsiraTypography.meta.copyWith(color: t.ink2),
              ),
            ),
          ),
        DecoratedBox(
          decoration: ShapeDecoration(shape: shape, shadows: t.shadow),
          child: Material(
            color: t.surface,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: ApsiraSpacing.cardSide,
                      endIndent: ApsiraSpacing.cardSide,
                      color: t.border,
                    ),
                  child,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A row: a neutral icon tile, [label] and [subline], and a chevron, read
/// by TalkBack as one sentence, a button; a tap opens it.
class HelpRow extends StatelessWidget {
  const HelpRow({
    super.key,
    required this.icon,
    required this.label,
    required this.subline,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final neutral = t.families[ApsiraFamily.neutral]!;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: ApsiraSpacing.taskRow,
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: neutral.container,
                      shape: ApsiraShapes.rounded(ApsiraRadii.iconTile(36))
                          .copyWith(side: BorderSide(color: t.border)),
                    ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Icon(icon, size: 18, color: neutral.onContainer),
                    ),
                  ),
                  const SizedBox(width: ApsiraSpacing.grid * 3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: ApsiraTypography.rowTitle.copyWith(
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: ApsiraSpacing.grid / 2),
                        Text(
                          subline,
                          style: ApsiraTypography.meta.copyWith(color: t.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ApsiraSpacing.grid * 2),
                  Icon(ApsiraIcons.chevron, color: t.ink3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tour played from Help: its [title] in the app bar above
/// [TourPlayer]; Done or Skip calls [onClose], which the router wires to go
/// back to Help. A tour with no steps yet is the bar alone, with its way
/// back. It writes nothing.
class HelpTourScreen extends StatelessWidget {
  const HelpTourScreen({
    super.key,
    required this.title,
    required this.steps,
    required this.onClose,
    this.initialStep = 0,
    this.tapPathLabel,
  });

  final String title;
  final List<TourStepData> steps;

  /// Done or Skip.
  final VoidCallback onClose;

  /// The step shown first.
  final int initialStep;

  /// [TourPlayer.tapPathLabel].
  final String Function(List<String> path)? tapPathLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ApsiraTheme.of(context).ground,
    appBar: helpAppBar(context, title),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ApsiraSpacing.screenGutter,
          0,
          ApsiraSpacing.screenGutter,
          ApsiraSpacing.screenGutter,
        ),
        child: steps.isEmpty
            ? const SizedBox.shrink()
            : TourPlayer(
                steps: steps,
                initialStep: initialStep,
                onDone: onClose,
                onSkip: onClose,
                tapPathLabel: tapPathLabel,
              ),
      ),
    ),
  );
}

/// A worked example of a how-to: [how] it is typed or done, the [input]
/// (text to type when [typed], shown in the monospace face; taps or a
/// screen otherwise) and the [result] you get, all in the UI language.
@immutable
class HowToExample {
  const HowToExample({
    required this.how,
    required this.input,
    required this.result,
    this.typed = false,
    this.breakable = false,
  });

  final String how;
  final String input;
  final String result;

  /// Text to type: the monospace face the query field uses.
  final bool typed;

  /// A condition that may wrap after its key or before a comparison
  /// ([breakableSyntax]).
  final bool breakable;
}

/// A how-to: its [title] (heading the page, wrapping at large text) and its
/// numbered [steps] on a bordered card, each read by TalkBack as
/// [stepLabel] ("Step n: …"), then its worked [examples] on a second card
/// under [examplesHeader]. Every line wraps, so nothing scrolls sideways at
/// large text. Back returns to Help.
class HowToPage extends StatelessWidget {
  const HowToPage({
    super.key,
    required this.title,
    required this.steps,
    required this.stepLabel,
    this.examples = const [],
    this.examplesHeader,
    this.exampleResultLabel,
    this.exampleLabel,
  }) : assert(
         examples.length == 0 ||
             (examplesHeader != null &&
                 exampleResultLabel != null &&
                 exampleLabel != null),
         'examples have a header, a result label and a TalkBack sentence',
       );

  final String title;
  final List<String> steps;

  /// TalkBack's sentence for step [n] (from 1).
  final String Function(int n, String step) stepLabel;

  final List<HowToExample> examples;
  final String? examplesHeader;

  /// The words above an example's result ("You get").
  final String? exampleResultLabel;

  /// TalkBack's one sentence for an example.
  final String Function(HowToExample example)? exampleLabel;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return Scaffold(
      backgroundColor: t.ground,
      // The title heads the page rather than the app bar, whose title never
      // wraps: a long one stays whole at large text.
      appBar: helpAppBar(context, null),
      body: ListView(
        padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ApsiraSpacing.cardSide,
              0,
              ApsiraSpacing.cardSide,
              ApsiraSpacing.betweenSections,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: ApsiraTypography.h2.copyWith(color: t.ink),
              ),
            ),
          ),
          HelpGroup(
            children: [
              for (final (i, step) in steps.indexed)
                Semantics(
                  container: true,
                  label: stepLabel(i + 1, step),
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: ApsiraSpacing.taskRow,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: ApsiraSizes.checkboxInTaskSheet,
                              minHeight: ApsiraSizes.checkboxInTaskSheet,
                            ),
                            padding: const EdgeInsets.all(ApsiraSpacing.grid),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: t.accentText,
                                width: ApsiraSizes.checkboxRing,
                              ),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: ApsiraTypography.pill.copyWith(
                                color: t.accentText,
                              ),
                            ),
                          ),
                          const SizedBox(width: ApsiraSpacing.grid * 3),
                          Expanded(
                            child: Text(
                              step,
                              style: ApsiraTypography.body.copyWith(
                                color: t.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: ApsiraSpacing.betweenSections),
            HelpGroup(
              title: examplesHeader,
              children: [
                for (final (i, example) in examples.indexed)
                  HowToExampleRow(
                    key: ValueKey('help/example/${i + 1}'),
                    example: example,
                    resultLabel: exampleResultLabel!,
                    semanticsLabel: exampleLabel!(example),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One worked example: where it is typed or done, [example]'s input on a
/// bordered inset (monospace when typed), then [resultLabel] ("You get")
/// and its result. TalkBack reads it as one sentence, [semanticsLabel].
class HowToExampleRow extends StatelessWidget {
  const HowToExampleRow({
    super.key,
    required this.example,
    required this.resultLabel,
    required this.semanticsLabel,
  });

  final HowToExample example;
  final String resultLabel;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final meta = ApsiraTypography.meta.copyWith(color: t.ink2);
    const gap = SizedBox(height: ApsiraSpacing.grid * 2);
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: ApsiraSpacing.taskRow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(example.how, style: meta),
              gap,
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.ground,
                  shape: ApsiraShapes.rounded(ApsiraRadii.insetBlock)
                      .copyWith(side: BorderSide(color: t.border)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ApsiraSpacing.grid * 4,
                    vertical: ApsiraSpacing.grid * 3,
                  ),
                  child: Text(
                    example.breakable
                        ? breakableSyntax(example.input)
                        : example.input,
                    key: const ValueKey('help/example/input'),
                    style: ApsiraTypography.body.copyWith(
                      color: t.ink,
                      // The bare name: the style's package qualifies it.
                      fontFamily: example.typed ? ApsiraFonts.mono : null,
                    ),
                  ),
                ),
              ),
              gap,
              Text(resultLabel, style: meta),
              const SizedBox(height: ApsiraSpacing.grid),
              Text(
                example.result,
                style: ApsiraTypography.body.copyWith(color: t.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [text] with a zero-width break opportunity after each `:` and before a
/// comparison (`<`, `>`), so a long condition (`prioridad:urgente)`) wraps
/// at large text between its key and its value rather than being cut; the
/// break is invisible and TalkBack reads the text as typed.
String breakableSyntax(String text) => text.replaceAllMapped(
  RegExp(r':|(?<![<>])(?=[<>])'),
  (m) => m[0] == ':' ? ':​' : '​',
);

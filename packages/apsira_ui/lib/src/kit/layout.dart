// From lyceum lib/app/theme/kit/layout/lyceum_card.dart (CardPart,
// CardSlice, GroupHeader, GroupCard) and lib/app/theme/kit/layout/
// section_header.dart (PageTitle, SectionHeader, OverlineLabel) @ 9f4ff27,
// themselves RELAY's lib/features/notes_list/ui/list_widgets.dart; LYCEUM's
// spacing names as their Apsira grid values (D-APK-014).
import 'package:flutter/material.dart';

import '../shape.dart';
import '../theme.dart';
import '../typography.dart';

/// Where a slice sits in its group card.
enum CardPart {
  first,
  middle,
  last,
  only;

  /// The part of the slice at [index] in a card of [count] slices.
  static CardPart at(int index, int count) => switch ((index, count)) {
    (0, 1) => only,
    (0, _) => first,
    (final i, final n) when i == n - 1 => last,
    _ => middle,
  };
}

/// One slice of a group card: the card's `surface` and 1 px `border`, its
/// rounded top on the first slice and its rounded bottom on the last, so
/// the rows of a long list are built lazily and still read as one card. A
/// slice after the first opens with an inset divider at the text column
/// ([dividerIndent], `ApsiraSpacing.dividerAfterIconTile` after an icon
/// tile). The last slice keeps `ApsiraSpacing.betweenCards` below it.
class CardSlice extends StatelessWidget {
  const CardSlice({
    super.key,
    required this.part,
    required this.child,
    this.divider = false,
    this.dividerIndent = ApsiraSpacing.dividerAfterIconTile,
  });

  final CardPart part;
  final Widget child;

  /// Whether an inset divider opens the slice.
  final bool divider;

  /// Where the divider starts: the text column of the rows.
  final double dividerIndent;

  static const double _overlap = ApsiraRadii.groupCard * 2;

  /// The card's border width: the rows sit inside it.
  static const double _border = 1;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final top = part == CardPart.first || part == CardPart.only;
    final bottom = part == CardPart.last || part == CardPart.only;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom ? ApsiraSpacing.betweenCards : 0),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: top ? 0 : -_overlap,
              bottom: bottom ? 0 : -_overlap,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.surface,
                  shape: ApsiraShapes.rounded(ApsiraRadii.groupCard)
                      .copyWith(side: BorderSide(color: t.border)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: top ? ApsiraSpacing.grid : 0,
                bottom: bottom ? ApsiraSpacing.grid : 0,
                left: _border,
                right: _border,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (divider)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: t.line,
                      indent: dividerIndent,
                      endIndent: ApsiraSpacing.cardSide,
                    ),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A group card's header: `cardTitle` in `ink` inside the card, announced
/// as a header.
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return Padding(
      padding: ApsiraSpacing.cardHeader,
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: ApsiraTypography.cardTitle.copyWith(color: t.ink),
        ),
      ),
    );
  }
}

/// A whole group card: an optional [GroupHeader] and [children] (rows) in
/// one card, inset dividers between the rows. Built from [CardSlice]s, so
/// it draws exactly as a lazily built list of slices does; place it at the
/// screen gutter.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    this.header,
    required this.children,
    this.dividerIndent = ApsiraSpacing.dividerAfterIconTile,
  });

  final String? header;
  final List<Widget> children;

  /// Where the dividers start: the text column of the rows.
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    final count = children.isEmpty ? 1 : children.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++)
          CardSlice(
            part: CardPart.at(i, count),
            divider: i > 0,
            dividerIndent: dividerIndent,
            child: i == 0 && header != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GroupHeader(header),
                      if (children.isNotEmpty) children.first,
                    ],
                  )
                : children.isEmpty
                ? const SizedBox.shrink()
                : children[i],
          ),
      ],
    );
  }
}

/// A page's large title, in the body under a bar that shows none:
/// `listTitle` in `ink`, or [display] for a date. It wraps at any text scale
/// and never cuts, and is announced as a header. [leading] (an icon tile)
/// and [trailing] (an action) sit beside it.
class PageTitle extends StatelessWidget {
  const PageTitle(
    this.text, {
    super.key,
    this.leading,
    this.trailing,
    this.display = false,
    this.padding = defaultPadding,
  });

  /// RELAY's large-title insets measured from the screen's edge: the
  /// large-title gutter at the start, the screen gutter at the end, 8 above
  /// and 16 below.
  static const defaultPadding = EdgeInsets.fromLTRB(
    ApsiraSpacing.largeTitleGutter,
    ApsiraSpacing.grid * 2,
    ApsiraSpacing.screenGutter,
    ApsiraSpacing.grid * 4,
  );

  final String text;
  final Widget? leading;
  final Widget? trailing;

  /// The `display` style instead of `listTitle` (a date).
  final bool display;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = display
        ? ApsiraTypography.display
        : ApsiraTypography.listTitle;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading case final leading?) ...[
            leading,
            const SizedBox(width: ApsiraSpacing.grid * 3),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: style.copyWith(color: ApsiraTheme.of(context).ink),
              ),
            ),
          ),
          if (trailing case final trailing?) ...[
            const SizedBox(width: ApsiraSpacing.grid * 2),
            trailing,
          ],
        ],
      ),
    );
  }
}

/// A group's label above its card, in sentence case: `meta` in `ink2`,
/// with an optional count in `ink3` and a trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      ApsiraSpacing.cardSide,
      ApsiraSpacing.grid * 5,
      ApsiraSpacing.cardSide,
      ApsiraSpacing.grid * 2,
    ),
  });

  final String title;

  /// Optional item count rendered after the title in `ink3`.
  final int? count;

  /// Optional action (usually a `TextButton`).
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: ApsiraTypography.meta.copyWith(color: t.ink2),
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: ApsiraSpacing.grid * 2),
            Text(
              '$count',
              style: ApsiraTypography.meta.copyWith(color: t.ink3),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// A small upper-case label that groups rows (a drawer's sections): `meta`
/// in `ink3`, as RELAY's drawer sections. Elsewhere a group's label is a
/// [SectionHeader], in sentence case.
class OverlineLabel extends StatelessWidget {
  const OverlineLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      ApsiraSpacing.screenGutter,
      ApsiraSpacing.grid * 5,
      ApsiraSpacing.screenGutter,
      ApsiraSpacing.grid * 2,
    ),
    this.color,
  });

  final String text;
  final EdgeInsetsGeometry padding;

  /// Override colour (a family's `onContainer`); `ink3` by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: ApsiraTypography.meta.copyWith(
            color: color ?? ApsiraTheme.of(context).ink3,
          ),
        ),
      ),
    );
  }
}

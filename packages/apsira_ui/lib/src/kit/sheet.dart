// From lyceum lib/app/theme/kit/overlay/lyceum_sheet.dart @ 9f4ff27
// (showLyceumSheet, LyceumSheet, SheetHandle), the surface drawn from the
// tokens rather than from `buildFull`'s bottomSheetTheme (D-APK-014).
import 'package:flutter/material.dart';

import '../shape.dart';
import '../theme.dart';

/// The sheet's insets around its body: 24 at the sides and the bottom.
const _sheetPadding = EdgeInsets.fromLTRB(
  ApsiraSpacing.grid * 6,
  0,
  ApsiraSpacing.grid * 6,
  ApsiraSpacing.grid * 6,
);

/// Shows the one bottom sheet: drag handle, optional title row with
/// trailing [actions], keyboard-aware padding, safe area. Its surface
/// (`surface`, the `ApsiraRadii.sheet` top with its 1 px `border`, over the
/// `scrim`) comes from the tokens, the same under `build` and `buildFull`.
/// It opens on the root navigator, so it covers a shell's bar and FAB.
///
/// For filters, quick-add forms, pickers and configuration, never for
/// full-page content.
Future<T?> showApsiraSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  List<Widget> actions = const [],
  bool scrollable = false,
  bool isDismissible = true,
  bool useRootNavigator = true,
  EdgeInsetsGeometry padding = _sheetPadding,
}) {
  final t = ApsiraTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useRootNavigator: useRootNavigator,
    backgroundColor: t.surface,
    barrierColor: t.scrim,
    clipBehavior: Clip.antiAlias,
    shape: ApsiraShapes.sheetTop.copyWith(side: BorderSide(color: t.border)),
    // Material 3's sheet takes no surface tint (D-066).
    builder: (ctx) => ApsiraSheet(
      title: title,
      actions: actions,
      scrollable: scrollable,
      padding: padding,
      child: Builder(builder: builder),
    ),
  );
}

/// The sheet body [showApsiraSheet] shows. Exposed for sheets that manage
/// their own `DraggableScrollableSheet`.
class ApsiraSheet extends StatelessWidget {
  const ApsiraSheet({
    super.key,
    required this.child,
    this.title,
    this.actions = const [],
    this.scrollable = false,
    this.padding = _sheetPadding,
  });

  final Widget child;
  final String? title;
  final List<Widget> actions;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final body = Padding(padding: padding, child: child);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            if (title != null || actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ApsiraSpacing.grid * 6,
                  ApsiraSpacing.grid,
                  ApsiraSpacing.grid * 4,
                  ApsiraSpacing.grid * 3,
                ),
                child: Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    ...actions,
                  ],
                ),
              ),
            if (scrollable)
              Flexible(child: SingleChildScrollView(child: body))
            else
              body,
          ],
        ),
      ),
    );
  }
}

/// The drag handle at the top of every sheet, in the control-edge `ring`.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(
          top: ApsiraSpacing.grid * 3,
          bottom: ApsiraSpacing.grid * 2,
        ),
        width: ApsiraSpacing.grid * 8,
        height: ApsiraSpacing.grid,
        decoration: BoxDecoration(
          color: ApsiraTheme.of(context).ring,
          borderRadius: BorderRadius.circular(ApsiraSpacing.grid / 2),
        ),
      ),
    );
  }
}

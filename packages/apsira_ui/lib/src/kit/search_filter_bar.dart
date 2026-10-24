// From lyceum lib/app/theme/kit/list/search_filter_bar.dart @ 9f4ff27
// (RELAY's search pill, relay lib/features/search/ui/search_screen.dart and
// lib/app/theme/query_field.dart), the labels from ApsiraL10n (D-APK-014).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:flutter/material.dart';

import '../shape.dart';
import '../theme.dart';
import 'kit_icons.dart';
import 'pills.dart';

/// The search-and-filter row at the top of a list page: RELAY's search
/// pill, a 52 px field filled with `surface`, outlined in `border` and in
/// `accentText` while focused, the search glyph in `ink3` and the clear
/// button's ✕ in `ink2`; the filter button beside it.
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.onChanged,
    this.controller,
    this.hintText,
    this.activeFilterCount = 0,
    this.onFilter,
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  /// Translated hint; `commonSearch` by default.
  final String? hintText;
  final int activeFilterCount;

  /// Opens the filter sheet; the filter button is hidden when null.
  final VoidCallback? onFilter;

  /// Focuses the field when the bar is first shown (a search screen's).
  final bool autofocus;

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  /// RELAY's search field height; the outline is a pill of half of it.
  static const double _fieldHeight = 52;

  /// The glyphs' size.
  static const double _icon = 20;

  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ApsiraL10n.of(context);
    final t = ApsiraTheme.of(context);
    OutlineInputBorder outline(Color colour) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(_fieldHeight / 2),
      borderSide: BorderSide(color: colour),
    );
    return Padding(
      // The pill, or the filter button after it, ends at the screen gutter,
      // as the cards under it do.
      padding: const EdgeInsets.symmetric(
        horizontal: ApsiraSpacing.screenGutter,
        vertical: ApsiraSpacing.grid * 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _fieldHeight),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _ctrl,
                builder: (context, value, _) => TextField(
                  controller: _ctrl,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? l10n.commonSearch,
                    filled: true,
                    fillColor: t.surface,
                    border: outline(t.border),
                    enabledBorder: outline(t.border),
                    focusedBorder: outline(t.accentText),
                    prefixIcon: Icon(
                      KitIcons.search,
                      size: _icon,
                      color: t.ink3,
                    ),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              KitIcons.close,
                              size: _icon,
                              color: t.ink2,
                            ),
                            tooltip: l10n.commonClear,
                            onPressed: () {
                              _ctrl.clear();
                              widget.onChanged('');
                            },
                          ),
                    isDense: true,
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          ),
          if (widget.onFilter != null) ...[
            const SizedBox(width: ApsiraSpacing.grid),
            IconButton(
              tooltip: l10n.commonFilter,
              isSelected: widget.activeFilterCount > 0,
              onPressed: widget.onFilter,
              icon: Badge(
                isLabelVisible: widget.activeFilterCount > 0,
                label: Text('${widget.activeFilterCount}'),
                child: const Icon(KitIcons.tune),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A removable [TagPill] per active filter (its tooltip `commonClear`),
/// with `commonClearAll` when there is more than one.
class ActiveFilterPills extends StatelessWidget {
  const ActiveFilterPills({super.key, required this.filters, this.onClearAll});

  /// (translated label, remove callback) per active filter.
  final List<(String, VoidCallback)> filters;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();
    final l10n = ApsiraL10n.of(context);
    final onClearAll = this.onClearAll;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ApsiraSpacing.screenGutter,
        0,
        ApsiraSpacing.screenGutter,
        ApsiraSpacing.grid * 2,
      ),
      child: Wrap(
        spacing: ApsiraSpacing.grid * 2,
        runSpacing: ApsiraSpacing.grid * 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (label, onRemove) in filters)
            TagPill(
              label: label,
              onDeleted: onRemove,
              deleteTooltip: l10n.commonClear,
            ),
          if (filters.length > 1 && onClearAll != null)
            TextButton(onPressed: onClearAll, child: Text(l10n.commonClearAll)),
        ],
      ),
    );
  }
}

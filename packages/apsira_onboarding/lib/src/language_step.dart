// From relay lib/features/first_open/ui/first_open_screen.dart @ 09b28810
// (_LanguageStep, FirstOpenLanguageOption) and
// lib/features/first_open/state/first_open_flow.dart @ 09b28810 (the
// preselection), in viaticum's StepFrame
// (lib/features/first_open/ui/first_open_steps.dart @ 78d38e0; D-APK-017).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

import 'step_frame.dart';

/// "Choose your language / Elige tu idioma": the [options] (English and
/// Español; Follow phone is a Settings choice), the [selected] one marked;
/// Continue goes on in it. Keyed `firstOpen/language/<option>` and
/// `firstOpen/language/continue`.
class LanguageStep extends StatelessWidget {
  const LanguageStep({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onContinue,
    this.options = const [AppLanguage.english, AppLanguage.spanish],
  });

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;
  final VoidCallback onContinue;
  final List<AppLanguage> options;

  /// The language the step preselects: [stored] when it names one (a choice
  /// stored before), and otherwise the [phone]'s: Spanish for any `es`
  /// locale, English for every other.
  static AppLanguage preselect({
    required AppLanguage stored,
    required Locale phone,
  }) => switch (stored) {
    AppLanguage.english || AppLanguage.spanish => stored,
    AppLanguage.followPhone =>
      phone.languageCode == 'es' ? AppLanguage.spanish : AppLanguage.english,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = ApsiraL10n.of(context);
    final tokens = ApsiraTheme.of(context);
    return StepFrame(
      keyPrefix: 'firstOpen/language',
      onPrimary: onContinue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            l10n.firstOpenLanguageTitle,
            textAlign: TextAlign.center,
            style: ApsiraTypography.h2.copyWith(color: tokens.ink),
          ),
          const SizedBox(height: ApsiraSpacing.largeTitleGutter),
          for (final (i, language) in options.indexed) ...[
            if (i > 0) const SizedBox(height: ApsiraSpacing.betweenCards),
            LanguageOption(
              key: Key('firstOpen/language/${language.name}'),
              label: language.label(l10n),
              selected: language == selected,
              onTap: () => onSelected(language),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

/// One large language option: a bordered card, filled with the
/// selected-item accent and checked only when [selected], read as one of a
/// group.
class LanguageOption extends StatelessWidget {
  const LanguageOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ApsiraTheme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ApsiraRadii.captureTile),
      side: BorderSide(color: selected ? tokens.accentText : tokens.border),
    );
    return Semantics(
      container: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? tokens.accC : tokens.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: ApsiraSpacing.noteRow,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: ApsiraTypography.rowTitle.copyWith(
                      color: selected ? tokens.onAccC : tokens.ink,
                    ),
                  ),
                ),
                if (selected)
                  Icon(ApsiraIcons.verified, color: tokens.onAccC)
                else
                  const SizedBox.square(dimension: ApsiraSizes.checkbox),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

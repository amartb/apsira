// From relay lib/features/lock/ui/lock_cover.dart @ 09b28810, unchanged but
// for names: the tokens are apsira_ui's, the strings ApsiraL10n's and the
// wordmark the app's title ([LockCover.appTitle]).
import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

/// The branded cover shown while the app is locked: a blank branded screen,
/// so no content flashes before the prompt.
///
/// The `ground` screen with one bordered `surface` card: a lock icon, the
/// app's [appTitle] as the wordmark and a line, in tokens only. [onUnlock]
/// adds the Unlock button (a primary action, the one accent fill);
/// [showRetry] says the last attempt did not unlock. It shows no content,
/// ever.
class LockCover extends StatelessWidget {
  const LockCover({
    super.key,
    required this.appTitle,
    this.onUnlock,
    this.showRetry = false,
  });

  /// The app's name, as its wordmark.
  final String appTitle;

  /// Starts the prompt; `null` hides the button (launch, background, or
  /// while the prompt is up).
  final VoidCallback? onUnlock;

  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = ApsiraL10n.of(context);
    final tokens = ApsiraTheme.of(context);
    final unlock = onUnlock;
    return Material(
      key: const Key('lock/cover'),
      color: tokens.ground,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ApsiraSpacing.screenGutter),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(ApsiraRadii.groupCard),
                boxShadow: tokens.shadow,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ApsiraSpacing.cardSide,
                  vertical: ApsiraSpacing.largeTitleGutter,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: ApsiraSizes.checkboxInTaskSheet,
                      color: tokens.accentText,
                    ),
                    const SizedBox(height: ApsiraSpacing.betweenCards),
                    Text(
                      appTitle,
                      textAlign: TextAlign.center,
                      style: ApsiraTypography.wordmark.copyWith(
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: ApsiraSpacing.titleToMetaPills),
                    Text(
                      l10n.lockCoverMessage,
                      textAlign: TextAlign.center,
                      style: ApsiraTypography.body.copyWith(color: tokens.ink2),
                    ),
                    if (showRetry) ...[
                      const SizedBox(height: ApsiraSpacing.titleToMetaPills),
                      Text(
                        l10n.lockRetryMessage,
                        key: const Key('lock/retry'),
                        textAlign: TextAlign.center,
                        style: ApsiraTypography.meta.copyWith(
                          color: tokens.ink3,
                        ),
                      ),
                    ],
                    if (unlock != null) ...[
                      const SizedBox(height: ApsiraSpacing.betweenSections),
                      FilledButton(
                        key: const Key('lock/unlock'),
                        onPressed: unlock,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.accentFill,
                          foregroundColor: tokens.onAccent,
                          shape: ApsiraShapes.pill,
                          textStyle: ApsiraTypography.pill,
                        ),
                        child: Text(l10n.lockUnlockButton),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

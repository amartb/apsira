// From relay lib/features/lock/ui/lock_settings_section.dart @ 09b28810,
// on apsira_ui's settings rows (D-APK-016): RELAY's `_LockRow` and
// `_LockDivider` are `SettingsRow` and `SettingsDivider`, the timeout row a
// `SettingsChoiceRow`; each change is one write through lockSettingsProvider
// (the app's store) in place of RELAY's `updateLockSettings`. RELAY's KAIROS
// note under the rows (relay lib/app/router.dart's
// `_LockRowsWithCalendarNote`) is [LockSettingsSection.note]. The mandatory
// policy's rows are the package's own (D-APK-026).
import 'dart:async';

import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lock_policy.dart';
import 'lock_settings.dart';

/// The lock rows of Settings → Privacy & security: **App lock** with its
/// sub-line, **Lock after** (shown while the lock is on) and **Hide in
/// recent apps**, then the app's optional [note].
///
/// The lock controller and hide in recents follow the settings, so turning
/// the lock on locks at the next launch or timeout, and turning it off
/// brings the cover down.
///
/// The section is rows only, with no card: the app places it inside its
/// Settings screen's card (a `SettingsGroup`'s children, or its own). The
/// switches take an `accentFill` track when on and a `ring` outline when
/// off.
///
/// Under [LockPolicy.mandatory] the App lock row has no switch (the lock is
/// always on) and **Lock after** is always shown with the policy's
/// `timeoutOptions`.
class LockSettingsSection extends ConsumerWidget {
  const LockSettingsSection({super.key, this.note});

  /// A line under the rows, aligned with their text (RELAY: what its
  /// calendar shows while locked).
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ApsiraL10n.of(context);
    final policy = ref.watch(lockPolicyProvider);
    final settings = ref.watch(lockSettingsProvider);
    final lock = settings.value ?? policy.defaults;
    final mandatory = policy.isMandatory;
    final ready = settings.hasValue;

    void change(LockSettings Function(LockSettings) edit) =>
        unawaited(ref.read(lockSettingsProvider.notifier).change(edit));

    String timeoutLabel(int minutes) =>
        minutes == 0 ? l.lockImmediately : l.lockAfterMinutes(minutes);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: SettingsRow(
            icon: Icons.lock_outline,
            label: l.lockSettingsTitle,
            subline: l.lockSettingsSubline,
            trailing: mandatory
                ? null
                : _LockSwitch(
                    key: const ValueKey('lock/settings/enabled'),
                    value: lock.enabled,
                    onChanged: ready
                        ? (on) => change((s) => s.copyWith(enabled: on))
                        : null,
                  ),
          ),
        ),
        if (mandatory || lock.enabled) ...[
          const SettingsDivider(),
          SettingsChoiceRow<int>(
            key: const ValueKey('lock/settings/timeout'),
            icon: Icons.timer_outlined,
            label: l.lockAfter,
            options: [
              for (final minutes in {
                ...policy.timeoutOptions,
                lock.timeoutMinutes,
              }.toList()..sort())
                SettingsOption(minutes, timeoutLabel(minutes)),
            ],
            selected: lock.timeoutMinutes,
            onSelected: (minutes) =>
                change((s) => s.copyWith(timeoutMinutes: minutes)),
          ),
        ],
        const SettingsDivider(),
        MergeSemantics(
          child: SettingsRow(
            icon: Icons.visibility_off_outlined,
            label: l.lockHideInRecents,
            subline: l.lockHideInRecentsSubline,
            trailing: _LockSwitch(
              key: const ValueKey('lock/settings/hideInRecents'),
              value: lock.hideInRecents,
              onChanged: ready
                  ? (on) => change((s) => s.copyWith(hideInRecents: on))
                  : null,
            ),
          ),
        ),
        if (note case final note?)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ApsiraSpacing.cardSide +
                  settingsIconTile +
                  ApsiraSpacing.grid * 3,
              0,
              ApsiraSpacing.cardSide,
              ApsiraSpacing.taskRowVertical,
            ),
            child: Text(
              note,
              key: const ValueKey('lock/settings/note'),
              style: ApsiraTypography.meta.copyWith(
                color: ApsiraTheme.of(context).ink2,
              ),
            ),
          ),
      ],
    );
  }
}

/// The Settings switch: an `accentFill` track when on, a `ring` outline and
/// thumb when off.
class _LockSwitch extends StatelessWidget {
  const _LockSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: t.accentFill,
      activeThumbColor: t.onAccent,
      inactiveTrackColor: t.surface,
      inactiveThumbColor: t.ring,
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? t.accentFill : t.ring,
      ),
    );
  }
}

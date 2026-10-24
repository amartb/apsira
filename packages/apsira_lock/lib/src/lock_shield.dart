// From relay lib/features/lock/ui/lock_gate.dart @ 09b28810 (`LockGate`),
// unchanged but for names and without go_router (D-APK-016): the app passes
// its exemption ([LockShield.isExempt], [LockShield.exemptChanges],
// [LockShield.promptHeld]) where RELAY's `LockGate.routed` read its router;
// RELAY's LockCrossing, CrossingRouter and LockExemptRoute stay in RELAY.
import 'dart:async';

import 'package:apsira_l10n/apsira_l10n.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide LockState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'authenticator.dart';
import 'lock_controller.dart';
import 'lock_cover.dart';

/// The app's shield: [child] (the router's content) behind the [LockCover]
/// while the lock is covered.
///
/// It sits in `MaterialApp.builder`, above the router, so the cover is
/// drawn from the first frame and on the first frame back from the
/// background, before any content. While covered the content stays built,
/// so navigation and editors keep their state, but it is not in the
/// semantics tree, not hit-tested, its tickers are paused, and the back
/// button does not reach it; once locked it is not painted either.
///
/// With [isExempt] (RELAY's KAIROS space): while it answers true there is
/// no cover and no prompt, on launch or on a return, though the lock's state
/// and timeout run as ever; once it answers false while the lock is covered,
/// the cover is back and the prompt is due. Without it, every screen is
/// guarded.
class LockShield extends ConsumerStatefulWidget {
  const LockShield({
    super.key,
    required this.child,
    required this.appTitle,
    required this.promptReason,
    this.isExempt,
    this.exemptChanges,
    this.promptHeld,
  });

  final Widget child;

  /// The app's name: the cover's wordmark and the prompt's title.
  final String appTitle;

  /// The prompt's description, in the app's own words and language at
  /// [BuildContext] (RELAY: "Unlock Relay to see your notes and tasks.").
  final String Function(BuildContext context) promptReason;

  /// Whether what is shown now is exempt from the lock; null: never.
  final bool Function()? isExempt;

  /// Told of every change of what [isExempt] or [promptHeld] answer.
  final Listenable? exemptChanges;

  /// Whether the prompt must wait, the cover staying up; null: never.
  final bool Function()? promptHeld;

  @override
  ConsumerState<LockShield> createState() => _LockShieldState();
}

class _LockShieldState extends ConsumerState<LockShield>
    with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;
  bool _promptScheduled = false;

  LockController get _controller => ref.read(lockControllerProvider.notifier);

  bool get _exempt => widget.isExempt?.call() ?? false;

  bool get _held => widget.promptHeld?.call() ?? false;

  /// Whether the cover is up: the lock's, but never over an exempt screen.
  bool _covered(LockState lock) => lock.covered && !_exempt;

  @override
  void initState() {
    super.initState();
    widget.exemptChanges?.addListener(_exemptChanged);
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onPause: () => _controller.backgrounded(),
      // From paused, the first step back: earlier than `resumed`, so the
      // decision is made before the first frame back is drawn.
      onRestart: () => _controller.foregrounded(),
      onResume: _promptIfDue,
    );
    ref.listenManual(
      lockControllerProvider,
      (_, _) => _promptIfDue(),
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(LockShield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exemptChanges != widget.exemptChanges) {
      oldWidget.exemptChanges?.removeListener(_exemptChanged);
      widget.exemptChanges?.addListener(_exemptChanged);
    }
  }

  /// What is shown (or the launch's hold) changed: the cover follows, a due
  /// prompt starts on a guarded screen, and a guarded screen reached gets
  /// hide in recents back.
  void _exemptChanged() {
    if (!mounted) return;
    // A router parses its first route while it builds, below this shield:
    // follow it after that frame (the shield built it as not exempt, so a
    // covered lock stayed covered meanwhile).
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _exemptChanged());
      return;
    }
    setState(() {});
    if (!_exempt) unawaited(_controller.recents.leaveExempt());
    _promptIfDue();
  }

  @override
  void dispose() {
    widget.exemptChanges?.removeListener(_exemptChanged);
    _lifecycle.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Starts the prompt after the cover's frame, once the app is in the
  /// foreground (the system prompt needs a resumed activity).
  void _promptIfDue() {
    if (_promptScheduled ||
        !ref.read(lockControllerProvider).promptDue ||
        _exempt ||
        _held) {
      return;
    }
    final lifecycle = SchedulerBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _promptScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _promptScheduled = false;
        if (mounted &&
            ref.read(lockControllerProvider).promptDue &&
            !_exempt &&
            !_held) {
          _unlock();
        }
      })
      ..scheduleFrame();
  }

  void _unlock() => _controller.unlock(
    AuthPrompt.of(
      ApsiraL10n.of(context),
      appName: widget.appTitle,
      reason: widget.promptReason(context),
    ),
  );

  /// While covered, back leaves the app instead of popping a page nobody
  /// can see.
  @override
  Future<bool> didPopRoute() async {
    if (!_covered(ref.read(lockControllerProvider))) return false;
    await SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockControllerProvider);
    final covered = _covered(lock);
    return Stack(
      fit: StackFit.expand,
      children: [
        // While the settings are read at launch (milliseconds) the content
        // is laid out under the opaque cover, so the first route builds
        // as it does unlocked; once locked it is not painted at all.
        Offstage(
          offstage: covered && lock.phase != LockPhase.starting,
          child: ExcludeSemantics(
            excluding: covered,
            child: IgnorePointer(
              ignoring: covered,
              child: TickerMode(enabled: !covered, child: widget.child),
            ),
          ),
        ),
        if (covered)
          LockCover(
            appTitle: widget.appTitle,
            onUnlock: lock.canUnlock ? _unlock : null,
            showRetry: lock.showRetry,
          ),
      ],
    );
  }
}

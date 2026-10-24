// From lyceum lib/app/restartable_root.dart @ 9f4ff27
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Restarts the [RestartableRoot] it is given to.
///
/// A restore replaces the database file under the app, so the subtree that
/// holds everything built on the old connection (the provider scope) is
/// disposed first, and the app is then started again through its one open
/// path, never by re-pointing what it holds at a new connection.
final class RestartController {
  _RestartableRootState? _root;

  /// Disposes the root's child (the provider scope and every provider in
  /// it), waits for the frame that removes it, runs [whileStopped], then
  /// mounts what [open] returns as a new child. [open] runs even when
  /// [whileStopped] throws, whose error is then rethrown: the app is never
  /// left without a root. Throws [StateError] when no root is mounted or a
  /// restart is already under way.
  ///
  /// The frames wait for the app to be visible: a restart begun as the user
  /// leaves the app finishes when they come back.
  Future<void> restart({
    required Future<Widget> Function() open,
    Future<void> Function()? whileStopped,
  }) {
    final root = _root;
    if (root == null || !root.mounted) {
      throw StateError('no RestartableRoot is mounted');
    }
    if (root._restarting) throw StateError('a restart is already under way');
    return root._restart(open, whileStopped);
  }
}

/// Shows [child] until a [RestartController.restart] replaces it.
class RestartableRoot extends StatefulWidget {
  const RestartableRoot({
    super.key,
    required this.controller,
    required this.child,
  });

  final RestartController controller;

  /// The first app: the bootstrap's provider scope (or its fatal screen).
  final Widget child;

  @override
  State<RestartableRoot> createState() => _RestartableRootState();
}

class _RestartableRootState extends State<RestartableRoot> {
  /// The child shown; null while stopped.
  Widget? _child;

  /// Bumped at every restart, so the new child is a new element (a new
  /// provider scope), never an update of the old one.
  var _generation = 0;
  var _restarting = false;

  @override
  void initState() {
    super.initState();
    _child = widget.child;
    widget.controller._root = this;
  }

  @override
  void didUpdateWidget(RestartableRoot old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller._root == this) old.controller._root = null;
      widget.controller._root = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._root == this) widget.controller._root = null;
    super.dispose();
  }

  Future<void> _restart(
    Future<Widget> Function() open,
    Future<void> Function()? whileStopped,
  ) async {
    _restarting = true;
    try {
      setState(() => _child = null);
      await SchedulerBinding.instance.endOfFrame;
      try {
        await whileStopped?.call();
      } finally {
        final next = await open();
        if (mounted) {
          setState(() {
            _generation++;
            _child = next;
          });
        }
      }
    } finally {
      _restarting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    if (child == null) return const SizedBox.shrink();
    return KeyedSubtree(key: ValueKey(_generation), child: child);
  }
}

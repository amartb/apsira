// From relay lib/app/router.dart `_redirect` @ 09b28810 and lyceum
// lib/app/router.dart `startRedirect` @ 9f4ff27, with the targets the app's.

/// Which screens the app may show while it starts.
///
/// [pending] while the start gate waits for its answer (the database, the
/// lock's settings); [firstOpen] until first open (onboarding) has run once;
/// [locked] while the app lock is engaged; [safeMode] while the database is
/// in safe mode; [ready] otherwise.
enum StartPhase { pending, firstOpen, locked, safeMode, ready }

/// The app's route for each start phase. A phase without a route never
/// redirects: RELAY gives [pending] none, so nothing moves while its gate
/// waits; LYCEUM has no [safeMode].
final class StartRoutes {
  const StartRoutes({
    required this.home,
    this.pending,
    this.firstOpen,
    this.locked,
    this.safeMode,
  });

  /// Where a start screen leads once the app is [StartPhase.ready].
  final String home;

  final String? pending;
  final String? firstOpen;

  /// The unlock screen; its sub-paths (`<locked>/…`) count as it.
  final String? locked;

  final String? safeMode;
}

/// Where the start gate sends [location] (a path) in [phase]; `null` lets
/// it through. Until the app is ready, every path leads to the phase's own
/// screen; once ready, the start screens lead to [StartRoutes.home]. A lock
/// forgets the location: unlocking opens home.
///
/// A pure function with no router dependency: a `go_router` redirect calls
/// it with `state.uri.path`.
String? startRedirect(
  StartPhase phase,
  String location, {
  required StartRoutes routes,
}) {
  bool under(String root) => location == root || location.startsWith('$root/');
  String? to(String? target, {bool subPaths = false}) {
    if (target == null) return null;
    final at = subPaths ? under(target) : location == target;
    return at ? null : target;
  }

  return switch (phase) {
    StartPhase.pending => to(routes.pending),
    StartPhase.firstOpen => to(routes.firstOpen),
    StartPhase.locked => to(routes.locked, subPaths: true),
    StartPhase.safeMode => to(routes.safeMode),
    StartPhase.ready =>
      location == routes.pending ||
              location == routes.firstOpen ||
              location == routes.safeMode ||
              (routes.locked != null && under(routes.locked!))
          ? routes.home
          : null,
  };
}
